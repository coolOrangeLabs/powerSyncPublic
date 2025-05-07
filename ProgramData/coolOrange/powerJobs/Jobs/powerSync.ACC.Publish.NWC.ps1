#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

#==============================================================================#
# Please note that this job requires Autodesk Navisworks Manage to be          #
# installed on the Job Processor machine!                                      #
#==============================================================================#

# Required in the powerJobs Settings Dialog to determine the entity type for lifecycle state change triggers
# JobEntityType = FILE

#region Settings
# To include the Revision of the main file in the NWC name set Yes, otherwise No
$nwcFileNameWithRevision = $false

# The character used to separate file name and Revision label in the NWC name such as hyphen (-) or underscore (_)
$nwcFileNameRevisionSeparator = "_"

# To include the file extension of the main file in the NWC name set Yes, otherwise No
$nwcFileNameWithExtension = $true

# Navisworks Manage installation path
$navisworksManagePath = "C:\Program Files\Autodesk\Navisworks Manage 2024"

# To lock the NWC file in ACC after transfer set Yes, otherwise No
$lockAccFiles = $false
#endregion

#region Debugging
if (-not $IAmRunningInJobProcessor) {
    Import-Module powerJobs
    Open-VaultConnection -Server "localhost" -Vault "Vault" -User "Administrator" -Password ""
    $file = Get-VaultFile -Properties @{"Name" = "Assembly.iam"}
}
#endregion

Write-Host "Starting job '$($job.Name)'..."
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Import-Module powerAPS
foreach ($module in Get-ChildItem "C:\ProgramData\coolOrange\powerAPS" -Name -Filter "*.psm1") {
    Import-Module "C:\ProgramData\coolOrange\powerAPS\$module" -Force
}

Write-Host "Processing file $($file._FullPath)..."

if (@("iam", "ipt", "dwg", "sldasm", "sldprt") -notcontains $file._Extension) {
    Write-Host("File extension $($file._Extension) is not supported for DWF export!")
    $stopwatch.Stop()
    Write-Host "Completed job '$($job.Name)' in $([int]$stopwatch.Elapsed.TotalSeconds) Seconds"
    return
}

#region Navisworks Manage installation
@("Autodesk.Navisworks.Api.dll", "Autodesk.Navisworks.Automation.dll", "Autodesk.Navisworks.Controls.dll", "Autodesk.Navisworks.Resolver.dll") | ForEach-Object {
    $dll = [System.IO.Path]::Combine($navisworksManagePath, $_)
    if (Test-Path $dll -PathType Leaf) {
        Import-Module $dll
    } else {
        throw("Navisworks Manage is not installed or the specified path '$navisworksManagePath' is incorrect!")
    }
}
#endregion

$file = (Save-VaultFile -File $file._FullPath -DownloadDirectory $workingDirectory)[0]

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($file._Name)
if ($nwcFileNameWithRevision) {
    $fileName += $nwcFileNameRevisionSeparator + $file._Revision
}
if ($nwcFileNameWithExtension) {
    $fileName += "." + $file._Extension
}

#region NWC Export with Navisworks Manage
$localNwdFullFileName = "$workingDirectory\$fileName.nwd"
$localNwcFullFileName = "$workingDirectory\$fileName.nwc"

try {
    $navisworks = [Autodesk.Navisworks.Api.Automation.NavisworksApplication]::TryGetRunningInstance()
    if (-not $navisworks) {
        $navisworks = [Autodesk.Navisworks.Api.Automation.NavisworksApplication]::new()
    }
    
    $navisworks.DisableProgress()
    $navisworks.OpenFile($file.LocalPath)
    $navisworks.SaveFile($localNwdFullFileName)
    $navisworks.EnableProgress()
    
    [Autodesk.Navisworks.Api.Controls.ApplicationControl]::Terminate()
    $navisworks.Dispose()
    $navisworks = $null

    $exportNwcLocation = [System.IO.Path]::ChangeExtension($file.LocalPath, ".nwc")
    Copy-Item -Path $exportNwcLocation -Destination $localNwcFullFileName
    
    $exportResult = $true
}
catch {
    $exportResult = $false
    $exportResult | Add-Member -NotePropertyName Error -NotePropertyValue $_.Exception
}

if (-not $exportResult) {
    throw("Failed to export document $($file.LocalPath) to $localNwdFullFileName! Reason: $($exportResult.Error.Message)")
}

if (-not [System.IO.File]::Exists($localNwcFullFileName)) {
    throw("NWC file '$localNwcFullFileName' cannot be found!")
}
#endregion

#region APS Authentication
Write-Host "APS Authentication..."
$settings = GetVaultApsAuthenticationSettings
if ($settings -is [powerAPS.Error]) {
    throw $settings.Message
}

$accountId = $job.AccountId
if (-not $accountId) {
    # Use the Job Processor users's account ID if the job is not submitted an uers's account ID
    $vaultLogin = [Autodesk.Connectivity.WebServicesTools.AutodeskAccount]::Login([IntPtr]::Zero)
    $accountId = $vaultLogin.AccountId
}
if (-not $accountId) {
    throw "Autodesk Single Sign-on (SSO) is not enabled! Please enable Autodesk Single Sign-on (SSO) on the Vault Job Processor"
}

# Two-legged OAuth with Client ID + Secret + Autodesk Account ID from Vault
Open-APSConnection -ClientId $settings.ClientId -ClientSecret $settings.ClientSecret -AccountId $accountId
if (-not $ApsConnection) {
    throw "Cannot establish connection to Autodesk Construction Cloud (ACC)!"
}
#endregion

#region ACC Project and Folder Structure
$projectFolder = GetVaultAccProjectFolder $file._FolderPath
if (-not $projectFolder) {
    throw "ACC Project folder not specified in Vault!"
}
$folderProperties = GetVaultAccProjectProperties $file._FolderPath
$hub = Get-ApsAccHub $folderProperties["Hub"]
if (-not $hub) {
    throw "ACC Hub '$($folderProperties["Hub"])' not found!"
}
$project = Get-ApsProject -hub $hub -projectName $folderProperties["Project"]
if (-not $project) {
    throw "ACC Project '$($folderProperties["Project"])' not found!"
}
$relativeAccFolder = $folderProperties["Folder"]
$projectFilesFolder = Get-ApsProjectFilesFolder $hub $project
if (-not $projectFilesFolder) {
    throw "ACC Project Files folder not found!"
}

if ($file._FolderPath.StartsWith($projectFolder.FullName)) {
    $folderPath = $file._FolderPath.Substring($projectFolder.FullName.Length).TrimStart('/')
    $folderPath = $relativeAccFolder + "/" + $folderPath
}
else {
    throw "File '$($file._Name)' is not in the Vault base folder '$($projectFolder.FullName)'"
}

# Create ACC folder structure, based on Vault folder path
$contents = Get-ApsTopFolders $hub $project
$folderLevels = $folderPath.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
$currentParentFolder = $projectFilesFolder
foreach ($folderLevel in $folderLevels) {
    $currentFolder = $contents | Where-Object { $_.type -eq "folders" -and $_.attributes.displayName -eq $folderLevel }
    if (-not $currentFolder) {
        $currentFolder = Add-ApsFolder $project $currentParentFolder $folderLevel
    }
    $contents = Get-ApsFolderContents $project $currentFolder
    $currentParentFolder = $currentFolder
}
#endregion

#region ACC Upload and Versioning
# Upload binary content
$uploadObject = Add-ApsBucketFile $project $currentParentFolder $localNwcFullFileName

# Get existing item from folder contents
$item = $contents | Where-Object { $_.type -eq "items" -and $_.attributes.displayName -eq $([System.IO.Path]::GetFileName($localNwcFullFileName)) }
if (-not $item) {
    # Create first version if item does not exist
    $version = Add-ApsFirstVersion $project $currentParentFolder $localNwcFullFileName $uploadObject
}
else {
    # Create next version if item already exists
    $version = Add-ApsNextVersion $project $item $localNwcFullFileName $uploadObject
}
Write-Host "Version $($version.attributes.versionNumber)"
#endregion

#region ACC Custom Attributes
$customAttributes = Get-ApsAccCustomAttributeDefinitions $project $projectFilesFolder
$propertyMapping = GetVaultAccAttributeMapping $file._FolderPath
if ($customAttributes.Count -gt 0 -and $propertyMapping.Count -gt 0) {
    $attributes = @{}
    foreach ($mapping in $propertyMapping.GetEnumerator()) {
        $attributeName = $mapping.Name
        $vaultPropertyName = $mapping.Value

        $customAttribute = $customAttributes | Where-Object { $_.name -eq $attributeName }
        $id = $customAttribute.id
        $value = $file.$vaultPropertyName

        if ($customAttribute) {
            $attributes.Add($id, $value)
        }
    }
    if ($attributes.Count -gt 0) {
        Update-ApsAccCustomAttributes $project $version $attributes
    }
}
#endregion

#region ACC Item Lock
if ($lockAccFiles) {
    Update-ApsItemLocked $project $version $true
}
#endregion

$stopwatch.Stop()
Write-Host "Completed job '$($job.Name)' in $([int]$stopwatch.Elapsed.TotalSeconds) Seconds"
