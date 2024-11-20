#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - Data Management Projects

# Function to get all projects. Returns all project objects from the given hub.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/hubs-hub_id-projects-GET
function Get-ApsProjects($hub) {
    Write-Host "Reading Projects..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/project/v1/hubs/$($hub.id)/projects"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.data
}

# Function to get a single project. Returns a project object with the given name or $null.
function Get-ApsProject($hub, $projectName) {
    $projects = Get-ApsProjects $hub
    $project = $projects | Where-Object { $_.attributes.name -eq $projectName }
    if ($project) {
        return $project
    } else {
        return $null
    }
}

# Function to get all top folders in a project
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/hubs-hub_id-projects-project_id-topFolders-GET
function Get-ApsTopFolders($hub, $project) {
    Write-Host "Reading Top Folders..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/project/v1/hubs/$($hub.id)/projects/$($project.id)/topFolders"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }

    $response = Invoke-RestMethod @parameters
    return $response.data
}

# Function to get the 'Project Files' folder of a given project. Returns the folder object or $null.
function Get-ApsProjectFilesFolder($hub, $project) {
    $folders = Get-ApsTopFolders $hub $project
    $projectFilesFolder = $folders | Where-Object { $_.attributes.name -eq "Project Files" } 
    if ($projectFilesFolder) {
        return $projectFilesFolder
    } else {
        return $null
    }
}
