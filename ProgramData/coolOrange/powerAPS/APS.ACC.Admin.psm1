#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - ACC - Account Admin

# Function to get all users of a given ACC project. Returns an array of user objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-projectsprojectId-users-GET/
function Get-ApsAccProjectUsers($project) {
    Write-Host "Reading Project Users..."
    
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/projects/$(($project.id -replace '^b\.', ''))/users"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }    
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get a single user of a given ACC project by the given User ID. Returns a user object.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-projectsprojectId-users-userId-GET/
function Get-ApsAccProjectUser($project, $userId) {
    Write-Host "Reading Project User..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/projects/$(($project.id -replace '^b\.', ''))/users/$($userId)"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }    
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to find a user in a given ACC project by the given email address. Returns a user object or $null.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-projectsprojectId-users-GET/
function Find-ApsAccProjectUser($project, $email) {
    Write-Host "Finding Project User..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/projects/$(($project.id -replace '^b\.', ''))/users?filter[email]=$email"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    $user = $response.results | Where-Object { $_.email -eq $email }
    if ($user) {
        return $user
    } else {
        return $null
    }
}

# Function to add a user to a given ACC project. Returns a user object.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-projects-project-Id-users-POST/
# TODO: change the available products if needed
function Add-ApsAccProjectUser($project, $user) {
    Write-Host "Adding Project User..."

    $body = ConvertTo-Json @{
        "email" = $user.email
        "companyId" = $user.companyId
        "roleIds" = @($user.roleIds)
        "products" = @(
            @{
                "key" = "projectAdministration"
                "access" = "administrator"
            },
            @{
                "key" = "designCollaboration"
                "access" = "administrator"
            },
            @{
                "key" = "build"
                "access" = "administrator"
            },
            @{
                "key" = "cost"
                "access" = "administrator"
            },
            @{
                "key" = "modelCoordination"
                "access" = "administrator"
            },
            @{
                "key" = "docs"
                "access" = "administrator"
            }             
        )
    } -Depth 100 -Compress

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/projects/$(($project.id -replace '^b\.', ''))/users"
        "Method" = "Post"
        "ContentType" = "application/json"
        "Headers" = $ApsConnection.RequestHeaders
        "Body" = $body
    }

    $response = Invoke-RestMethod @parameters
    return $response
}

# Function to get a single ACC project by the given Project ID. Returns a project object.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-projectsprojectId-GET/
function Get-ApsAccProject($projectId) {
    Write-Host "Reading Project..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/projects/$(($projectId -replace '^b\.', ''))"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response
}

# Function to get all project templates of a given ACC account. Returns an array of project objects classfied as 'template'.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-accounts-accountidprojects-GET/
function Get-ApsAccProjectTemplates($hub) {
    Write-Host "Reading Project Templates..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/accounts/$(($hub.id -replace '^b\.', ''))/projects?filter[classification]=template&filter[status]=active"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results  
}

# Function to add a new project to a given ACC account. Returns a project object.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/admin-accounts-accountidprojects-POST/
function Add-ApsAccProject($hub, $name, $number, $type, $templateId) {
    Write-Host "Adding Project..."

    $body = ConvertTo-Json @{
        "name" = $name
        "type" = $type
        "jobNumber" = $number
        "template" = @{
            "projectId" = $templateId
            "options" = @{
                "field" = @{
                    "includeCompanies" = $true
                    "includeLocations" = $false
                }
            }
        }
    } -Depth 100 -Compress
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/admin/v1/accounts/$(($hub.id -replace '^b\.', ''))/projects"
        "Method" = "Post"
        "ContentType" = "application/json"
        "Headers" = $ApsConnection.RequestHeaders
        "Body" = $body
    }

    $response = Invoke-RestMethod @parameters
    return $response
}

# Function to get all business units of a given ACC account. Returns an array of business unit objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/business_units_structure-GET/
function Get-ApsAccBusinessUnits($hub) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::TwoLegged) {
        throw "Two-legged authentication is required"
    }    

    Write-Host "Reading Business Units..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/hq/v1/accounts/$(($hub.id -replace '^b\.', ''))/business_units_structure"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}
