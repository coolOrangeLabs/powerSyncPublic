#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - ACC - Issues

# Function to get all issues of a given project. Returns an array of issue objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/issues-issues-GET/
function Get-ApsAccIssues($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading Issues..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/issues/v1/projects/$($project.id.TrimStart("b."))/issues"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all comments of a given issue. Returns an array of comment objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/issues-comments-GET/
function Get-ApsAccIssueComments($project, $issue) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading Issue Comments..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/issues/v1/projects/$($project.id.TrimStart("b."))/issues/$($issue.id)/comments"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to add a comment to a given issue. Returns a comment object.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/issues-comments-POST/
function Add-ApsAccIssueComments($project, $issue, $commentText) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Adding Issue Comment..."

    $body = ConvertTo-Json @{ "body" = "$($commentText)" } -Depth 100 -Compress
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/issues/v1/projects/$($project.id.TrimStart("b."))/issues/$($issue.id)/comments"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }
    $response = Invoke-RestMethod @parameters
    return $response
}

# Function to get all issue types of a given project. Returns an array of issue type objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/issues-issue-types-GET/
function Get-ApsAccIssueTypes($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }
    
    Write-Host "Reading Issue Types..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/issues/v1/projects/$($project.id.TrimStart("b."))/issue-types?include=subtypes"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

# Function to get all root causes of a given project. Returns an array of root cause objects.
# API documentation: https://aps.autodesk.com/en/docs/acc/v1/reference/http/issues-issue-root-cause-categories-GET/
function Get-ApsAccRootCauses($project) {
    if ($ApsConnection.AuthType -ne [powerAps.ApsAuthType]::ThreeLegged) {
        throw "Three-legged authentication is required"
    }

    Write-Host "Reading Root Causes..."
    
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/construction/issues/v1/projects/$($project.id.TrimStart("b."))/issue-root-cause-categories?include=rootcauses"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}
