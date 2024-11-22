#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - Data Management Items and Versions

# Function to get the latest version (tip version) from an item. Returns a version object.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-items-item_id-tip-GET
function Get-ApsItemById($project, $id) {
    Write-Host "Reading Item..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/items/$([System.Web.HttpUtility]::UrlEncode($id))"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.data
}

# Function to get the latest version (tip version) from an item. Returns a version object.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-items-item_id-tip-GET
function Get-ApsTipVersion($project, $item) {
    Write-Host "Reading Tip Version..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/items/$([System.Web.HttpUtility]::UrlEncode($item.id))/tip"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.data
}

# Function to create a new item in the specified folder. Returns the tip version object of the created item.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-items-POST
function Add-ApsFirstVersion($project, $folder, $fullFilePath, $uploadObject, [Hashtable]$refs = $null) {
    Write-Host "Creating First Version..."

    $json = @{
        "jsonapi"  = @{
            "version" = "1.0"
        }
        "data"     = @{
            "type"          = "items"
            "attributes"    = @{
                "displayName" = [System.IO.Path]::GetFileName($fullFilePath)
                "extension"   = @{
                    "type"    = "items:autodesk.bim360:File"
                    "version" = "1.0"
                }
            }
            "relationships" = @{
                "tip"    = @{
                    "data" = @{
                        "type" = "versions"
                        "id"   = "1"
                    }
                }
                "parent" = @{
                    "data" = @{
                        "type" = "folders"
                        "id"   = "$($folder.id)"
                    }
                }
            }
        }
        "included" = @(
            @{
                "type"          = "versions"
                "id"            = "1"
                "attributes"    = @{
                    "name"      = [System.IO.Path]::GetFileName($fullFilePath)
                    "extension" = @{
                        "type"    = "versions:autodesk.bim360:File"
                        "version" = "1.0"
                    }
                }
                "relationships" = @{
                    "storage" = @{
                        "data" = @{
                            "type" = "objects"
                            "id"   = "$($uploadObject.objectId)"
                        }
                    }
                }
            }
        )
    }
    if ($null -ne $refs -and $refs.Count -gt 0) {
        $json.included[0].relationships += $refs
    }
    $body = ConvertTo-Json $json -Depth 100 -Compress
    $parameters = @{
        "Uri"         = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/items"
        "Method"      = "Post"
        "ContentType" = "application/vnd.api+json"
        "Headers"     = $ApsConnection.RequestHeaders
        "Body"        = $body
    }
    $response = Invoke-RestMethod @parameters
    $item = $response.data

    # Get and return the tip *version* of the item
    $parameters = @{
        "Uri"     = $item.relationships.tip.links.related.href
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.data
}

# Function to create a new version of the specified item. Returns the version object.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-versions-POST
function Add-ApsNextVersion($project, $existingItem, $fullFilePath, $uploadObject, [Hashtable]$refs = $null) {
    Write-Host "Creating Next Version..."

    $json = @{
        "jsonapi" = @{
            "version" = "1.0"
        }
        "data"    = @{
            "type"          = "versions"
            "attributes"    = @{
                "name"      = [System.IO.Path]::GetFileName($fullFilePath)
                "extension" = @{
                    "type"    = "versions:autodesk.bim360:File"
                    "version" = "1.0"
                }
            }
            "relationships" = @{
                "item"    = @{
                    "data" = @{
                        "type" = "items"
                        "id"   = "$($existingItem.id)"
                    }
                }
                "storage" = @{
                    "data" = @{
                        "type" = "objects"
                        "id"   = "$($uploadObject.objectId)"
                    }
                }
            }
        }
    }
    if ($null -ne $refs -and $refs.Count -gt 0) {
        $json.data.relationships += $refs
    }
    $body = ConvertTo-Json $json -Depth 100 -Compress
    $parameters = @{
        "Uri"         = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/versions"
        "Method"      = "Post"
        "ContentType" = "application/vnd.api+json"
        "Headers"     = $ApsConnection.RequestHeaders
        "Body"        = $body
    }
    $response = Invoke-RestMethod @parameters
    return $response.data
}

# Function to build references between the ACC objects based on Vault file children. 
# Returns a list of references as hashtable to be used in Add-ApsFirstVersion and Add-ApsNextVersion.
# $nestedType can be: "overlay", "attachment" or $null
# Reference: https://aps.autodesk.com/blog/bim360-docs-setting-external-references-between-files-upload-linked-files
function Get-ApsVersionRefs($childFiles, $filesAndVersionsDictionary, $nestedType = $null) {
    if ($childFiles.Count -gt 0) {
        $values = @()
        foreach ($childFile in $childFiles | Sort-Object { $_._Name }) {
            $versionId = $filesAndVersionsDictionary[$childFile._FullPath]
            if (-not $nestedType) {
                $values += @{
                    "type" = "versions"
                    "id"   = "$($versionId)"
                    "meta" = @{
                        "refType"   = "xrefs"
                        "direction" = "from"
                        "extension" = @{
                            "type"    = "xrefs:autodesk.core:Xref"
                            "version" = "1.0"
                        }
                    }
                }
            } else {
                $values += @{
                    "type" = "versions"
                    "id"   = "$($versionId)"
                    "meta" = @{
                        "refType"   = "xrefs"
                        "direction" = "from"
                        "extension" = @{
                            "type"    = "xrefs:autodesk.core:Xref"
                            "version" = "1.1"
                            "data"    = @{
                                "nestedType" = "$($nestedType)"
                            }
                        }
                    }
                }
            }
        }

        return @{"refs" = @{ "data" = @($values)}}
    }
    else {
        return $null;
    }
}

# Function to get all references of the specified version. Returns a list of references.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-versions-version_id-relationships-refs-GET/
function Get-ApsVersionReferences($project, $version) { 
    Write-Host "Reading Version References..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/versions/$([System.Web.HttpUtility]::UrlEncode($version.id))/relationships/refs"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $result = Invoke-RestMethod @parameters
    return $result
}

# Function to add references to the specified version.
# NOT Supported by ACC!!! Use only for model derivative use cases
# detail=BIM360 currently does not support the creation of refs.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-versions-version_id-relationships-refs-POST/
function Add-ApsVersionReferences($project, $version, $childFiles, $filesAndVersionsDictionary) {
    Write-Host "Adding Version References..."

    if ($childFiles.Count -gt 0) {
        foreach ($childFile in $childFiles | Sort-Object { $_._Name }) {
            $body = ConvertTo-Json @{
                "jsonapi" = @{
                    "version" = "1.0"
                }
                "data"    = @{
                    "type" = "versions"
                    "id"   = "$($filesAndVersionsDictionary[$childFile._FullPath])"
                    "meta" = @{
                        "extension" = @{
                            "type"    = "xrefs:autodesk.core:Xref"
                            "version" = "1.0"
                            "data"    = @{}
                        }
                    }
                }
            } -Depth 100 -Compress

            $parameters = @{
                "Uri"         = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/versions/$([System.Web.HttpUtility]::UrlEncode($version.id))/relationships/refs"
                "Method"      = "Post"
                "ContentType" = "application/vnd.api+json"
                "Headers"     = $ApsConnection.RequestHeaders
                "Body"        = $body
            }
            Invoke-RestMethod @parameters
        }
    }
}

# Function to lock or unlock the specified item. Returns the updated item object.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-items-item_id-PATCH
# https://stackoverflow.com/questions/73286387/is-there-an-autodesk-forge-api-available-to-lock-files-in-bim-360-or-acc
function Update-ApsItemLocked($project, $version, $locked = $false) {
    Write-Host "Updating Item Locked..."

    $body = ConvertTo-Json @{
        "jsonapi" = @{
            "version" = "1.0"
        }
        "data"    = @{
            "type"       = "items"
            "id"         = "$($version.relationships.item.data.id)"
            "attributes" = @{
                "reserved" = $locked
            }
        }
    } -Depth 100 -Compress
    $parameters = @{
        "Uri"         = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/items/$([System.Web.HttpUtility]::UrlEncode($version.relationships.item.data.id))"
        "Method"      = "Patch"
        "Headers"     = $ApsConnection.RequestHeaders
        "ContentType" = "application/vnd.api+json"
        "Body"        = $body
    }
    $response = Invoke-RestMethod @parameters
    return $response.data
}
