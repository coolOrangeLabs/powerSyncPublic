#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - ACC - Relationships

# Function to get all relationship entity types. Returns an array of relationship entity type objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/relationship-service-v2-get-writable-relationship-domains-GET/
function Get-ApsAccRelationshipEntityTypes() {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading Relationship Entity Types..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/bim360/relationship/v2/utility/relationships:writable"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }    
    $response = Invoke-RestMethod @parameters
    return $response
}

# Function to get all relationships of a given project. Returns an array of relationship objects.
# API documentation: https://aps.autodesk.com/en/docs/bim360/v1/reference/http/relationship-service-v2-search-relationships-GET/
function Get-ApsAccRelationships($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading Relationships..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/bim360/relationship/v2/containers/$($project.id.TrimStart("b."))/relationships:search"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }    
    $response = Invoke-RestMethod @parameters
    return $response.relationships
}

# Function to add relationships between two versions. Returns a relationship object.
# API documentation: https://aps.autodesk.com/en/docs/bim360/v1/reference/http/relationship-service-v2-add-relationships-PUT/
function Add-ApsAccRelationship($project, $version1, $version2) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Adding Relationship..."

    $body = ConvertTo-Json @(@{
        entities = @(
            @{
                domain    = "autodesk-bim360-documentmanagement"
                type      = "fileversion"
                id        = "$($version1.id)"
                createdOn = "$($version1.attributes.createTime)"
            },
            @{
                domain    = "autodesk-bim360-documentmanagement"
                type      = "fileversion"
                id        = "$($version2.id)"
                createdOn = "$($version2.attributes.createTime)"
            }
        )
    }) -Depth 100 -Compress
    $parameters = @{
        "Uri"         = "https://developer.api.autodesk.com/bim360/relationship/v2/containers/$($project.id.TrimStart("b."))/relationships"
        "Method"      = "Put"
        "ContentType" = "application/json"
        "Body"        = $body
        "Headers"     = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response
}

# Function to remove relationships between two versions. Returns nothing.
# API documentation: https://aps.autodesk.com/en/docs/bim360/v1/reference/http/relationship-service-v2-delete-relationships-POST/
function Remove-ApsAccRelationships($project, [array]$relationshipIds) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Removing Relationships..."

    $body = ConvertTo-Json @($relationshipIds) -Depth 100 -Compress
    $parameters = @{
        "Uri"         = "https://developer.api.autodesk.com/bim360/relationship/v2/containers/$($project.id.TrimStart("b."))/relationships:delete"
        "Method"      = "Post"
        "ContentType" = "application/json"
        "Body"        = $body        
        "Headers"     = $ApsConnection.RequestHeaders
    }    
    $response = Invoke-RestMethod @parameters
    return $response
}
