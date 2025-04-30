#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - ACC - Assets

# Function to get all asset categories of a given ACC project. Returns an array of category objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-categories-GET/
function Get-ApsAccAssetCategories ($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading ACC Asset Categories..."
 
    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/construction/assets/v1/projects/$(($project.id -replace '^b\.', ''))/categories"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
 
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all asset status sets of a given ACC project. Returns an array of asset status set objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-assets-v2-GET/
function Get-ApsAccAssetStatusSets($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading ACC Asset Staus Sets..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/construction/assets/v1/projects/$(($project.id -replace '^b\.', ''))/status-step-sets"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
 
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all assets of a given ACC project. Returns an array of asset objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-assets-batch-get-v2-POST/
function Get-ApsAccAssetsByIds($project, [array]$ids) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading ACC Assets..."

    $body = ConvertTo-Json @{"ids" = @($ids)} -Compress
    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/construction/assets/v2/projects/$(($project.id -replace '^b\.', ''))/assets:batch-get"
        "Method"  = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }
 
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all assets of a given ACC project. Returns an array of asset objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-assets-v2-GET/
function Get-ApsAccAssets($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading ACC Assets..."
 
    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/construction/assets/v2/projects/$(($project.id -replace '^b\.', ''))/assets"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
 
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all assets of a given ACC project with a given category. Returns an array of asset objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-assets-v2-GET/
function Get-ApsAccAssetsByCategory($project, $category) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading ACC Assets..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/construction/assets/v2/projects/$(($project.id -replace '^b\.', ''))/assets?filter[categoryId]=$($category.id)"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
 
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all assets of a given ACC project with a given category and a given status label. Returns an array of asset objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-assets-v2-GET/
function Get-ApsAccAssetsByCategoryAndStatusLabel($project, $category, $statusLabel) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading ACC Assets..."

    $parameters = @{
        "Uri"     = "https://developer.api.autodesk.com/construction/assets/v2/projects/$(($project.id -replace '^b\.', ''))/assets?filter[categoryId]=$($category.id)&filter[statusLabel]=$($statusLabel)"
        "Method"  = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
 
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to update the status of a given ACC asset
# Returns a set of key:value pairs. The key is the asset ID of the asset that was revised. The value is the fully revised asset.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/assets-assets-batch-patch-PATCH-v2/
function Update-ApsAccAssetStatus($project, $asset, $status) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Updating ACC Asset Status..."
    
    $body = ConvertTo-Json @{
        "$($asset.id)" = @{
            "statusId" = "$($status.id)"
        }
    } -Depth 100 -Compress
    $parameters = @{
        "Uri"         = "https://developer.api.autodesk.com/construction/assets/v2/projects/$(($project.id -replace '^b\.', ''))/assets:batch-patch"
        "Method"      = "Patch"
        "Headers"     = $ApsConnection.RequestHeaders        
        "ContentType" = "application/json"
        "Body"        = $body        
    }

    $response = Invoke-RestMethod @parameters
    return $response
}
