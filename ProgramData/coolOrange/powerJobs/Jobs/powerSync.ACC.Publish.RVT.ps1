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
# To include the Revision of the main file in the RVT name set Yes, otherwise No
$rvtFileNameWithRevision = $false

# The character used to separate file name and Revision label in the RVT name such as hyphen (-) or underscore (_)
$rvtFileNameRevisionSeparator = "_"

# Preset File
$presetFile = "C:\PDMC-Sample\Templates\Inventor\Presets\SimplifyCmd.preset"

# Preset Name
$presetName = "AllOptionsEnabled"
#endregion

#region Debugging
if (-not $IAmRunningInJobProcessor) {
    Import-Module powerJobs
    Open-VaultConnection -Server "localhost" -Vault "Vault" -User "Administrator" -Password ""
    $file = Get-VaultFile -Properties @{"Name" = "packing machine.iam" }
}
#endregion

Write-Host "Starting job '$($job.Name)'..."
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Import-Module powerAPS
foreach ($module in Get-ChildItem "C:\ProgramData\coolOrange\powerAPS" -Name -Filter "*.psm1") {
    Import-Module "C:\ProgramData\coolOrange\powerAPS\$module" -Force
}

Write-Host "Processing file $($file._FullPath)..."

if (@("iam") -notcontains $file._Extension) {
    Write-Host("File extension $($file._Extension) is not supported for RVT export!")
    $stopwatch.Stop()
    Write-Host "Completed job '$($job.Name)' in $([int]$stopwatch.Elapsed.TotalSeconds) Seconds"
    return
}

#region Functions
function GetPresetsFromFile($presetFile, $presetName) {
    $settings = New-Object 'System.Collections.Generic.Dictionary[System.String, System.String]'
    if (Test-Path $presetFile) {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.Load($presetFile)
        $rvtNodes = $xmlDoc.DocumentElement.SelectNodes("//OUTPUT_TYPE_SELECTOR[@Value='OUTPUT_TYPE_RVT']")
        $rvtNode = $rvtNodes | Where-Object { $_.ParentNode.Name -eq $presetName }
        if ($rvtNode) {
            
            $presetNode = $rvtNode.ParentNode
            foreach ($node in $presetNode.ChildNodes) {
                $settings.Add($node.Name, $node.Attributes.ItemOf("Value").Value)
            }
        }
    }
    return $settings
}
function GetPresetMap() {
    $map = New-Object 'System.Collections.Generic.Dictionary[[string],[object]]'

    # Replace with envelopes
    $map.Add("ENVELOPE_REPLACE_NONE_ITEM", [Inventor.EnvelopesReplaceStyleEnum]::kNoneReplaceStyle) # 118785 No enveloping
    $map.Add("ENVELOPE_REPLACE_TOP_ASSEMBLY_ITEM", [Inventor.EnvelopesReplaceStyleEnum]::kAllInOneEnvelopeReplaceStyle) # 118786 Replace entire assembly with an envelope
    $map.Add("ENVELOPE_REPLACE_ALL_PARTS_ITEM", [Inventor.EnvelopesReplaceStyleEnum]::kEachPartReplaceStyle) # 118788 Replace each part with an envelope
    $map.Add("ENVELOPE_REPLACE_TOP_COMPONENTS_ITEM", [Inventor.EnvelopesReplaceStyleEnum]::kEachTopLevelComponentReplaceStyle) # 118787 Replace each top-level component with an envelope

    # Simplification
    $map.Add("REMOVE_HOLE_ALL_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll) # 118786 Remove all
    $map.Add("REMOVE_HOLE_RANGE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange) # 118787 Remove in range
    $map.Add("REMOVE_HOLE_NONE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveNone) # 118785 Do not remove any
    $map.Add("REMOVE_FILLET_ALL_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll) # 118786 Remove all
    $map.Add("REMOVE_FILLET_RANGE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange) # 118787 Remove in range
    $map.Add("REMOVE_FILLET_NONE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveNone) # 118785 Do not remove any
    $map.Add("REMOVE_CHAMFER_ALL_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll) # 118786 Remove all
    $map.Add("REMOVE_CHAMFER_RANGE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange) # 118787 Remove in range
    $map.Add("REMOVE_CHAMFER_NONE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveNone) # 118785 Do not remove any
    $map.Add("REMOVE_POCKET_ALL_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll) # 118786 Remove all
    $map.Add("REMOVE_POCKET_RANGE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange) # 118787 Remove in range
    $map.Add("REMOVE_POCKET_NONE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveNone) # 118785 Do not remove any
    $map.Add("REMOVE_EMBOSS_ALL_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll) # 118786 Remove all
    $map.Add("REMOVE_EMBOSS_RANGE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange) # 118787 Remove in range
    $map.Add("REMOVE_EMBOSS_NONE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveNone) # 118785 Do not remove any
    $map.Add("REMOVE_TUNNEL_ALL_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll) # 118786 Remove all
    $map.Add("REMOVE_TUNNEL_RANGE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange) # 118787 Remove in range
    $map.Add("REMOVE_TUNNEL_NONE_ITEM", [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveNone) # 118785 Do not remove any

    # Revit structure
    $map.Add("RVT_ALL_IN_ONE", [Inventor.RevitExportStructureTypeEnum]::kAllInOneElementStructure) # 119041 Everything structured as a single Revit element
    $map.Add("RVT_TOPLEVEL_COMPONENTS", [Inventor.RevitExportStructureTypeEnum]::kEachTopLevelComponentStructure) # 119042 Top-level components as Revit elements

    return $map
}
#endregion

#region RVT Export
Write-Host "Generating RVT file..."

$files = (Save-VaultFile -File $file._FullPath -DownloadDirectory $workingDirectory)
foreach ($file in $files) {
    Set-ItemProperty -Path $file.LocalPath -Name IsReadOnly -Value $false
}
$file = $files[0]

$rvtFileName = [System.IO.Path]::GetFileNameWithoutExtension($file._Name)
if ($rvtFileNameWithRevision) {
    $rvtFileName += $rvtFileNameRevisionSeparator + $file._Revision
}

$rvtFileName += ".rvt"
$localFullFileName = "$([System.IO.Path]::GetDirectoryName($file.LocalPath))\$rvtFileName"

if (@("iam") -contains $file._Extension) {
    Write-Host "Inventor file translation..."

    $openResult = Open-Document -LocalFile $file.LocalPath -Options @{ FastOpen = $fastOpen }
    if (-not $openResult) {
        throw("Failed to open document $($file.LocalPath)! Reason: $($openResult.Error.Message)")
    }

    $document = $openResult.Document.Instance
    if ($document.DocumentType -ne [Inventor.DocumentTypeEnum]::kAssemblyDocumentObject) {
        throw "Document must be an Inventor Assembly!"
    }

    if ($document.ComponentDefinition.ModelStates.ActiveModelState.ModelStateType -eq [Inventor.ModelStateTypeEnum]::kSubstituteModelStateType) {
        $document.ComponentDefinition.ModelStates.Item(1).Activate()
    }

    $rvtExportDefinition = $document.ComponentDefinition.RevitExports.CreateDefinition()
    # $location = [System.IO.Path]::GetDirectoryName($localFullFileName)
    # $rvtExportDefinition.Location = $location
    $rvtExportDefinition.FileName = $rvtFileName

    $map = GetPresetMap
    $presets = GetPresetsFromFile $presetFile $presetName
    if ($null -ne $presets) {
        foreach ($preset in $presets.GetEnumerator()) {
            switch ($preset.Key) {
                # Envelopes
                "ENVELOPE_SELECTOR" {
                    $rvtExportDefinition.EnvelopesReplaceStyle = $map[$preset.Value]
                    break
                }
                # Parts by size
                "REMOVE_PART_BY_SIZE_TOGGLE" {
                    $rvtExportDefinition.RemovePartsBySize = [bool]::Parse($preset.Value)
                    break
                }
                "MAXIMUM_DIAGONAL_RVEC" {
                    $rvtExportDefinition.RemovePartsSize = [double]::Parse(($preset.Value -split " " | Select-Object -First 1)) # Assuming matching units
                    break
                }
                # Holes
                "REMOVE_HOLE_SELECTOR" {
                    $rvtExportDefinition.RemoveHolesStyle = $map[$preset.Value]
                    break
                }
                "MAX_DIAMETER_RVEC" {
                    $rvtExportDefinition.RemoveHolesDiameterRange = [double]::Parse(($preset.Value -split " " | Select-Object -First 1)) # Assuming matching units
                    break
                }
                # Fillets
                "REMOVE_FILLET_SELECTOR" {
                    $rvtExportDefinition.RemoveFilletsStyle = $map[$preset.Value]
                    break
                }
                "MAX_RADIUS_RVEC" {
                    $rvtExportDefinition.RemoveFilletsRadiusRange = [double]::Parse(($preset.Value -split " " | Select-Object -First 1)) # Assuming matching units
                    break
                }
                # Chamfers
                "REMOVE_CHAMFER_SELECTOR" {
                    $rvtExportDefinition.RemoveChamfersStyle = $map[$preset.Value]
                    break
                }
                "MAX_DISTANCE_RVEC" {
                    $rvtExportDefinition.RemoveChamfersDistanceRange = [double]::Parse(($preset.Value -split " " | Select-Object -First 1)) # Assuming matching units
                    break
                }
                # Pockets
                "REMOVE_POCKET_SELECTOR" {
                    $rvtExportDefinition.RemovePocketsStyle = $map[$preset.Value]
                    break
                }
                "MAX_LOOP_RVEC" {
                    $rvtExportDefinition.RemovePocketsMaxDepthRange = [double]::Parse(($preset.Value -split " " | Select-Object -First 1)) # Assuming matching units
                    break
                }
                # Emboss
                "REMOVE_EMBOSS_SELECTOR" {
                    $rvtExportDefinition.RemoveEmbossStyle = $map[$preset.Value]
                    break
                }
                "MAX_HEIGHT_RVEC" {
                    $rvtExportDefinition.RemoveEmbossMaxHeightRange = [double]::Parse(($preset.Value -split " " | Select-Object -First 1)) # Assuming matching units
                    break
                }
                # Tunnels
                "REMOVE_TUNNEL_SELECTOR" {
                    $rvtExportDefinition.RemoveTunnelsStyle = $map[$preset.Value]
                    break
                }
                # Revit Structure
                "RVT_STRUCTURE_SELECTOR" {
                    $rvtExportDefinition.Structure = $map[$preset.Value]
                    break
                }
                # Advanced properties
                "FILL_INTERNAL_VOIDS_TOGGLE" {
                    $rvtExportDefinition.RemoveAllInternalVoids = $preset.Value
                    break
                }
                "REMOVE_INTERNAL_PARTS_TOGGLE" {
                    $rvtExportDefinition.RemoveInternalParts = $preset.Value
                    break
                }
                "USE_COLOR_OVERRIDE_FROM_SOURCE_TOGGLE" {
                    $rvtExportDefinition.UseColorOverrideFromSourceComponent = $preset.Value
                    break
                }
                default {
                    Write-Warning "Unknown preset key: $($preset.Key)"
                    break
                }
            }
        }
    } else {
        # Proceed with default export options if no preset has been selected/available
        # Input
        $rvtExportDefinition.IsAssociativeDesignView = $false
    
        # Envelopes
        $rvtExportDefinition.EnvelopesReplaceStyle = [Inventor.EnvelopesReplaceStyleEnum]::kNoneReplaceStyle
    
        # Part Removal
        $rvtExportDefinition.RemovePartsBySize = $true
        $rvtExportDefinition.RemovePartsSize = 10
    
        # Feature Removal; for ranges, values are in cm
        $rvtExportDefinition.RemoveHolesStyle = [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveByRange
        $rvtExportDefinition.RemoveHolesDiameterRange = 10
        $rvtExportDefinition.RemoveChamfersStyle = [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll
        $rvtExportDefinition.RemoveFilletsStyle = [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll
        $rvtExportDefinition.RemovePocketsStyle = [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll
        $rvtExportDefinition.RemoveEmbossStyle = [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll
        $rvtExportDefinition.RemoveTunnelsStyle = [Inventor.SimplificationRemoveStyleEnum]::kSimplificationRemoveAll
    
        # Output
        $rvtExportDefinition.Structure = [Inventor.RevitExportStructureTypeEnum]::kAllInOneElementStructure
        $rvtExportDefinition.EnableUpdating = $true
    
        # Advanced Options
        $rvtExportDefinition.UseColorOverrideFromSourceComponent = $true
        $rvtExportDefinition.RemoveAllInternalVoids = $true
        $rvtExportDefinition.RemoveInternalParts = $true
    }

    try {
        $rvtExportResult = $document.ComponentDefinition.RevitExports.Add($rvtExportDefinition)
        $exportResult = $true

        if ($localFullFileName -ne $rvtExportResult.FullFileName) {
            $localFullFileName = $rvtExportResult.FullFileName
        }
    } catch {
        $exportResult = $false
        $exportResult | Add-Member -NotePropertyName Error -NotePropertyValue $_.Exception
    }
    
    $closeResult = Close-Document
    if (-not $exportResult) {
        throw("Failed to export document $($file.LocalPath) to $localFullFileName! Reason: $($exportResult.Error.Message)")
    }
    if (-not $closeResult) {
        throw("Failed to close document $($file.LocalPath)! Reason: $($closeResult.Error.Message))")
    }
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
$uploadObject = Add-ApsBucketFile $project $currentParentFolder $localFullFileName

# Get existing item from folder contents
$item = $contents | Where-Object { $_.type -eq "items" -and $_.attributes.displayName -eq $([System.IO.Path]::GetFileName($localFullFileName)) }
if (-not $item) {
    # Create first version if item does not exist
    $version = Add-ApsFirstVersion $project $currentParentFolder $localFullFileName $uploadObject
}
else {
    # Create next version if item already exists
    $version = Add-ApsNextVersion $project $item $localFullFileName $uploadObject
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
