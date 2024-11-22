#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

function GetMissingRoles([array]$roles) {
    $permissions = $global:vault.AdminService.GetPermissionsByUserId($global:vaultConnection.UserID)
    $names = $permissions | ForEach-Object { $_.Descr }
    $missing = @()
    foreach($role in $roles) {
        if ($names -notcontains $role) {
            $missing += "'$role'"
        }
    }

    if ($missing.Count -gt 0) {
        return $missing -join ", "
    } else {
        return $null
    }
}

function GetVaultApsAuthenticationSettings($force = $false) {
    $json = $global:vault.KnowledgeVaultService.GetVaultOption("POWERAPS_AUTH_SETTINGS") 
    if ($json) {
        $settings = @{}
		(ConvertFrom-Json $json).PsObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value }
        if (-not $settings.ClientId -or -not $settings.ClientSecret -or -not $settings.CallbackUrl -or -not $settings.Scope) {
            if ($force) { return $settings }
            return [powerAPS.Error]::new(
                "The Autodesk Platform Services (APS) application is not fully configured. Go to 'Tools' / 'powerSync: APS Connection Settings...' to fully configure the APS application!", 
                "powerSync: Configuration error"
            )
        } else {
            return $settings
        }
    } 

    return [powerAPS.Error]::new(
        "An Autodesk Platform Services (APS) application must be configured. Go to 'Tools' / 'powerSync: APS Connection Settings...' to configure an APS application!", 
        "powerSync: Configuration error"
    )
}

function SetVaultApsAuthenticationSettings([Hashtable]$settings) {
    $global:vault.KnowledgeVaultService.SetVaultOption("POWERAPS_AUTH_SETTINGS", (ConvertTo-Json $settings)) | Out-Null
}

function GetVaultAccDefaultAccount() {
    return $global:vault.KnowledgeVaultService.GetVaultOption("POWERAPS_ACC_ACCOUNT")
}

function SetVaultAccDefaultAccount($accountName) {
    $global:vault.KnowledgeVaultService.SetVaultOption("POWERAPS_ACC_ACCOUNT", $accountName) | Out-Null
}

function GetVaultAccFolderBehaviors($force = $false) {
    $json = $global:vault.KnowledgeVaultService.GetVaultOption("POWERAPS_FOLDER_SETTINGS") 
    if ($json) {
        $settings = @{}
		(ConvertFrom-Json $json).PsObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value }
        if (-not $settings["Category"] -or -not $settings["Hub"] -or -not $settings["Project"] -or -not $settings["Folder"]) {
            if ($force) { 
                return $settings
            } else {
                return [powerAPS.Error]::new(
                    "A Vault folder category and Vault folder properties must be configured. Go to 'Tools' / 'powerSync: Vault Folder Settings...' to define these Vault behaviors!", 
                    "powerSync: Configuration error"
                )
            }
        } else {
            return $settings
        }
    } 
    else {
        return [powerAPS.Error]::new(
            "A Vault folder category and Vault folder properties must be configured. Go to 'Tools' / 'powerSync: Vault Folder Settings...' to define these Vault behaviors!", 
            "powerSync: Configuration error"
        )
    }
}

function SetVaultAccFolderBehaviors([Hashtable]$settings) {
    $global:vault.KnowledgeVaultService.SetVaultOption("POWERAPS_FOLDER_SETTINGS", (ConvertTo-Json $settings)) | Out-Null
}

function GetVaultAccProjectFolder($folderFullName) {
    $settings = GetVaultAccFolderBehaviors
    if ($settings -is [powerAPS.Error]) { return $settings }

    $categoryName = $settings["Category"]
    $projectFolder = $null
    $folder = $global:vault.DocumentService.GetFolderByPath($folderFullName)
    if ($folder.Cat.CatName -eq $categoryName) {
        $projectFolder = $folder
    }
    else {
        while ($folder.Cat.CatName -ne $categoryName -and $folder.FullName -ne "$") {
            $folder = $global:vault.DocumentService.GetFolderByID($folder.ParID)
            if ($folder.Cat.CatName -eq $categoryName) {
                $projectFolder = $folder
                break
            }
        }
    }

    if (-not $projectFolder) {
        return [powerAPS.Error]::new(
            "The ACC project cannot be determined! Assign an ACC project to a Vault folder first!", 
            "powerSync: Project not defined"
        )
    }

    return $projectFolder
}

function GetVaultAccProjectProperties($folderFullName) {
    $settings = GetVaultAccFolderBehaviors
    if ($settings -is [powerAPS.Error]) { return $settings }

    $projectFolder = GetVaultAccProjectFolder $folderFullName
    if ($projectFolder -is [powerAPS.Error]) { return $projectFolder }

    $propDefs = $global:vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FLDR")
    
    $hubPropDef = $propDefs | Where-Object { $_.DispName -eq $settings["Hub"] }
    $projectPropDef = $propDefs | Where-Object { $_.DispName -eq $settings["Project"] }
    $folderPropDef = $propDefs | Where-Object { $_.DispName -eq $settings["Folder"] }

    $propInsts = $global:vault.PropertyService.GetProperties("FLDR", @($projectFolder.Id), @($hubPropDef.Id, $projectPropDef.Id, $folderPropDef.Id))
    
    $properties = @{}
    $properties["Name"] = $projectFolder.Name
    $properties["FullName"] = $projectFolder.FullName
    $properties["Hub"] = $propInsts | Where-Object { $_.PropDefId -eq $hubPropDef.Id } | Select-Object -ExpandProperty Val
    $properties["Project"] = $propInsts | Where-Object { $_.PropDefId -eq $projectPropDef.Id } | Select-Object -ExpandProperty Val
    $properties["Folder"] = $propInsts | Where-Object { $_.PropDefId -eq $folderPropDef.Id } | Select-Object -ExpandProperty Val
    
    return $properties
}

function GetVaultAccAttributeMapping($vaultFolderPath) {
    $folder = GetVaultAccProjectFolder $vaultFolderPath
    if ($folder -is [powerAPS.Error]) { return $folder }
    
    $mapping = @{}
    $attributes = $global:vault.PropertyService.GetEntityAttributes($folder.Id, "CO.VLT.ACC")
    $attribute = $attributes | Where-Object { $_.Attr -eq "CustomAttributeMapping" }
    if ($attribute -and $attribute.Val) {
		(ConvertFrom-Json $attribute.Val).PsObject.Properties | ForEach-Object { 
            if ($_.Name -and $_.Value) {
                $mapping[$_.Name] = $_.Value
            }
        }
    }
    return $mapping
}

function SetVaultAccAttributeMapping($vaultFolderPath, [Hashtable]$mapping) {
    $folder = GetVaultAccProjectFolder $vaultFolderPath
    if ($folder -is [powerAPS.Error]) { return $folder }

    $json = ConvertTo-Json $mapping
    $global:vault.PropertyService.SetEntityAttribute($folder.Id, "CO.VLT.ACC", "CustomAttributeMapping", $json);
}

function GetVaultSingleFile() {
    $bookmark = ""
    $status = $null
    $results = $global:vault.DocumentService.FindFilesBySearchConditions($null, $null, $null, $false, $true, [ref]$bookmark, [ref]$status)
    $file = Get-VaultFile -FileId $results[0].Id
    return $file
}
