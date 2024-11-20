#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - ACC - Files (Document Management) - Custom Attributes (beta)

# Function to get all custom attribute definitions of a given folder. Returns an array of custom attribute definition objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/document-management-custom-attribute-definitions-GET/
function Get-ApsAccCustomAttributeDefinitions($project, $folder) {
    Write-Host "Reading Custom Attribute Definitions..."
    
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/bim360/docs/v1/projects/$($project.id.TrimStart("b."))/folders/$([System.Web.HttpUtility]::UrlEncode($folder.id))/custom-attribute-definitions"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all custom attributes of a given version. Returns an array of custom attribute objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/document-management-versionsbatch-get-POST/
function Get-ApsAccCustomAttributes($project, $version) {
    Write-Host "Reading Custom Attributes..."

    $body = ConvertTo-Json @{"urns" = @($version.id)} -Compress

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/bim360/docs/v1/projects/$($project.id.TrimStart("b."))/versions:batch-get"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }
    $response = Invoke-RestMethod @parameters 
    return $response.results
}

# Function to update custom attributes of a given version. Returns nothing.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/document-management-custom-attribute-definitions-POST/
function Update-ApsAccCustomAttributes($project, $version, [HashTable]$properties) {
    Write-Host "Updating Custom Attributes..."

    $values = @()
    foreach ($prop in $properties.GetEnumerator()) {
        $value = @{
            "id" = $prop.Name
            "value" = $prop.Value
        }
        $values += $value
    }
    $body = ConvertTo-Json @($values) -Compress
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/bim360/docs/v1/projects/$($project.id.TrimStart("b."))/versions/$([System.Web.HttpUtility]::UrlEncode($version.id))/custom-attributes:batch-update"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }
    $response = Invoke-RestMethod @parameters
    $response | Out-Null
}


# Autodesk Platform Services - ACC - Files (Document Management) - Permissions (beta)

# Function to add permissions to a given folder for a given user. Returns nothing.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/document-management-projects-project_id-folders-folder_id-permissionsbatch-create-POST/
function Add-ApsAccFolderPermissions($project, $folder, $subjectUser) {
    Write-Host "Adding Folder Permissions..."
    
    $body = ConvertTo-Json @(@{
        "subjectId" = "$($subjectUser.id)"
        "subjectType" = "USER"
        "actions" = @(
            "VIEW",
            "DOWNLOAD",
            "COLLABORATE",
            "PUBLISH",
            "EDIT"
        )
    }) -Depth 100 -Compress

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/bim360/docs/v1/projects/$($project.id.TrimStart("b."))/folders/$($folder.id)/permissions:batch-create"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }
    $response = Invoke-RestMethod @parameters
    $response | Out-Null 
}
