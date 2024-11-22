#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

function GetRoleNameById($roleId) {
    $roles = @{
        1   = "Folder Create"
        2   = "Folder Delete"
        3   = "Folder Read"
        4   = "File Create"
        5   = "File Delete Conditional"
        6   = "File Read"
        8   = "File Check Out"
        9   = "File Undo Check Out (Current User)"
        10  = "File Check In"
        11  = "File Rename"
        12  = "Folder Rename"
        13  = "File Delete Unconditional"
        17  = "File Undo Check Out (All Users)"
        19  = "File Move"
        20  = "File Promote"
        22  = "Item Create"
        23  = "Item Read"
        24  = "Item Edit"
        27  = "Item Change Item Number"
        34  = "Item Administer Item Number"
        35  = "File Version Delete Conditional"
        36  = "File Version Delete Unconditional"
        37  = "File Dependency Update"
        39  = "User Create"
        41  = "User Read"
        42  = "User Update"
        43  = "User Assign Role"
        46  = "Vault Create"
        47  = "Vault Delete"
        48  = "Vault Attach"
        49  = "Vault Detach"
        51  = "Purge Files"
        52  = "Purge Set Options"
        53  = "Purge Get Options"
        54  = "Manage Roles"
        60  = "Properties Rebuild Index"
        62  = "Vault Backup"
        63  = "Vault Restore"
        64  = "ERP Import"
        65  = "ERP Export"
        69  = "Library Info Update"
        72  = "Content Publish"
        73  = "Content Category Add"
        74  = "Content Category Delete"
        75  = "Content Category Update"
        76  = "Vault Set Options"
        77  = "Vault Get Options"
        78  = "Label Read"
        79  = "Label Create"
        80  = "Label Delete"
        81  = "Administrator User Update"
        82  = "Administrator User Read"
        83  = "Change Order Edit"
        84  = "Change Order Participate"
        85  = "Change Order Routing Create"
        86  = "Change Order Routing Edit"
        89  = "Item Delete Conditional"
        90  = "Forum Read"
        91  = "Item Administer Unit of Measure"
        92  = "Change Order Read"
        93  = "Change Order Create"
        96  = "Library Create"
        97  = "Library Delete"
        98  = "Library Attach"
        99  = "Library Detach"
        102 = "ACL Read"
        103 = "ACL Write"
        104 = "File Status Override"
        105 = "Administer Visualization Watermark Definitions"
        106 = "Access Cloaked Objects"
        107 = "Vault management on local site"
        108 = "Vault Migrate"
        109 = "Library Migrate"
        111 = "Manage site configurations"
        112 = "Auto File Naming Scheme Update"
        113 = "Override Restrict Life Cycle State Change to Change Order"
        114 = "Change Order Delete Unconditional"
        115 = "Vault Defragment"
        116 = "Library Defragment"
        117 = "Item Purge"
        118 = "Job Queue Read"
        119 = "Job Queue Add"
        120 = "Job Queue Reserve"
        121 = "Job Queue Delete"
        122 = "File Change File Number"
        123 = "File Administer File Number"
        124 = "Modify Visualization Attachment"
        125 = "Job Queue Enable"
        126 = "File BOM Read"
        201 = "File Add & Remove User Defined Property"
        202 = "File Change LifeCycle State"
        203 = "File Change LifeCycle Definition"
        204 = "File Change Revision"
        205 = "File Change Revision Scheme"
        206 = "File Change Category"
        207 = "Manage Behavior Definitions"
        208 = "Read Behavior Definitions"
        209 = "Manage Property Definitions"
        210 = "Manage workgroups"
        213 = "Link Read"
        214 = "Link Create"
        215 = "Link Delete"
        216 = "Folder Edit User Defined Property"
        217 = "Folder Add & Remove User Defined Property"
        218 = "Folder Change Category"
        219 = "Item Add & Remove User Defined Property"
        221 = "Import historical data"
        222 = "Change Order Restricted Change"
        223 = "Item Delete Unconditional"
        224 = "Link Move"
        225 = "Custom Entity Read"
        226 = "Custom Entity Create"
        227 = "Folder Change LifeCycle State"
        228 = "Folder Change LifeCycle Definition"
        229 = "Custom Entity Delete Conditional"
        230 = "Custom Entity Delete Unconditional"
        231 = "Custom Entity Manage Definitions"
        233 = "Custom Entity Change Category"
        234 = "Custom Entity Rename"
        236 = "Custom Entity Edit User Defined Property"
        237 = "Custom Entity Add & Remove User Defined Property"
        238 = "Custom Entity Change LifeCycle State"
        239 = "Custom Entity Change LifeCycle Definition"
        240 = "Item Change Category"
        241 = "Item Change Revision"
        242 = "Item Change Revision Scheme"
        243 = "Item Change LifeCycle State"
        244 = "Item Change LifeCycle Definition"
        245 = "Item Version Delete"
        246 = "Item Rollback LifeCycle State"
        247 = "Get File Rollback Lifecycle State Target"
        248 = "File Rollback LifeCycle State"
        249 = "File BOM Update"
        250 = "Link Edit User Defined Property"
        251 = "Link Add & Remove User Defined Property"
        252 = "Change Order Delete Conditional"
        253 = "Object Get Attributes"
        254 = "Object Set Attributes"
        255 = "Manage Numbering Schemes"
        256 = "File Download"
        257 = "Markup Read"
        258 = "Markup Edit"
        259 = "Markup Delete"
    }

    return $roles[$roleId]
}

function GetMissingRoles([array]$roleIds) {
    $permissions = $global:vault.AdminService.GetPermissionsByUserId($global:vaultConnection.UserID)
    $ids = $permissions | ForEach-Object { $_.Id }
    $missingRoles = @()
    foreach($roleId in $roleIds) {
        if ($ids -notcontains $roleId) {
            $missingRoles += "'$(GetRoleNameById $roleId)'"
        }
    }

    if ($missingRoles.Count -gt 0) {
        return $missingRoles -join ", "
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
