#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# Required in the powerJobs Settings Dialog to determine the entity type for lifecycle state change triggers
# JobEntityType = FILE

#region Settings
# To lock the file and all file references in ACC after transfer set Yes, otherwise No
$lockAccFiles = $true
# The location of Folder in ACC where files will be uploaded that are not in the Vault base folder. Needs to start with "Project Files" and can be nested with '/'
$externalFilesFolder = "Project Files/Content Center"
#endregion

#region Debugging
if (-not $IAmRunningInJobProcessor) {
    Import-Module powerJobs
    Open-VaultConnection -Server "localhost" -Vault "Vault" -User "Administrator" -Password ""
    $file = Get-VaultFile -Properties @{"Name" = "Assembly.iam" }
}
#endregion

Write-Host "Starting job '$($job.Name)'..."
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Import-Module powerAPS
foreach ($module in Get-ChildItem "C:\ProgramData\coolOrange\powerAPS" -Name -Filter "*.psm1") {
    Import-Module "C:\ProgramData\coolOrange\powerAPS\$module" -Force
}

Write-Host "Processing file $($file._FullPath)..."

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

#region ACC Project and ProjectFiles Folder
$projectFolder = GetVaultAccProjectFolder $file._FolderPath
if ($projectFolder -is [powerAPS.Error]) {
    throw $projectFolder.Message
}
$projectProperties = GetVaultAccProjectProperties $file._FolderPath
if ($projectProperties -is [powerAPS.Error]) {
    throw $projectProperties.Message
}
$hub = Get-ApsHub $projectProperties["Hub"]
if (-not $hub) {
    throw "ACC Hub '$($projectProperties["Hub"])' not found!"
}
$project = Get-ApsProject -hub $hub -projectName $projectProperties["Project"]
if (-not $project) {
    throw "ACC Project '$($projectProperties["Project"])' not found!"
}
$relativeAccFolder = $projectProperties["Folder"]
$projectFilesFolder = Get-ApsProjectFilesFolder $hub $project
if (-not $projectFilesFolder) {
    throw "ACC Project Files folder not found!"
}
#endregion

# Get the attribute mapping for the file properties
$propertyMapping = GetVaultAccAttributeMapping $file._FolderPath
$customAttributes = Get-ApsAccCustomAttributeDefinitions $project $projectFilesFolder

# Dictionary to link Vault files with ACC item version IDs
$filesAndVersionsDictionary = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'

function ProcessFile($file, $fullFilePath, $childFiles, $filesAndVersionsDictionary) {  
    Write-Host "Uploading $($file._Name)..."

    #region Folder Structure
    if ($file._FolderPath.StartsWith($projectFolder.FullName)) {
        $folderPath = $file._FolderPath.Substring($projectFolder.FullName.Length).TrimStart('/')
        $folderPath = $relativeAccFolder + "/" + $folderPath
    }
    else {
        $folderPath = $externalFilesFolder
        Write-Host "File '$($file._Name)' is not in the Vault base folder '$($projectFolder.FullName)'. Use '$externalFilesFolder' instead"
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
    $uploadObject = Add-ApsBucketFile $project $currentParentFolder $fullFilePath

    # Get the file references
    if ($file._Extension -eq "rvt") {
        $nestedType = "overlay"
    }
    else {
        $nestedType = $null
    }
    $refs = Get-ApsVersionRefs $childFiles $filesAndVersionsDictionary $nestedType

    # Get existing item from folder contents
    $item = $contents | Where-Object { $_.type -eq "items" -and $_.attributes.displayName -eq $([System.IO.Path]::GetFileName($fullFilePath)) }
    if (-not $item) {
        # Create first version if item does not exist
        $version = Add-ApsFirstVersion $project $currentParentFolder $fullFilePath $uploadObject $refs
    }
    else {
        # Create next version if item already exists
        $version = Add-ApsNextVersion $project $item $fullFilePath $uploadObject $refs
    }
    Write-Host "Version $($version.attributes.versionNumber)"
    #endregion

    #region ACC Custom Attributes
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

    # Remember the ACC item version ID for the Vault file
    $filesAndVersionsDictionary.Add($file._FullPath, $version.id)
}

function ProcessStructure($file, $filesAndVersionsDictionary) {
    Write-Host "$($file._FolderPath)"

    if ($file._CategoryName -eq "Substitute" -or $file._Extension -eq "ipt") {
        # Ignore Substitutes and Inventor Part files
        $childFiles = @()
    }
    else {
        $childFiles = Get-VaultFileAssociations -File $file._FullPath -Dependencies
        foreach ($childFile in $childFiles) {
            ProcessStructure $childFile $filesAndVersionsDictionary
        }
    }

    if (-not $filesAndVersionsDictionary.ContainsKey($file._FullPath)) {
        Write-Host "Downloading $($file._Name) from Vault..."
        $file = (Save-VaultFile -File $file._FullPath -DownloadDirectory $workingDirectory -ExcludeChildren:$true -ExcludeLibraryContents:$true)[0]
        ProcessFile $file $file.LocalPath $childFiles $filesAndVersionsDictionary
    }
}

ProcessStructure $file $filesAndVersionsDictionary

$stopwatch.Stop()
Write-Host "Completed job '$($job.Name)' in $([int]$stopwatch.Elapsed.TotalSeconds) Seconds"
