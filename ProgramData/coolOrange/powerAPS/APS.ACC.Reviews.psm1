#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Only works with Private Reviews API beta! The ClientID must be registered for the beta program.
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Autodesk Platform Services - ACC - Reviews
# Private Beta - documentation not available online; check email from acc.review.api.feedback@autodesk.com

function Get-ApsAccReviewWorkflows($project) {
    $parameters = @{ 
        "Uri" = "https://developer.api.autodesk.com/construction/reviews/v1/projects/$($project.id.TrimStart("b."))/workflows"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

function Get-ApsAccReviews($project) {
    $parameters = @{ 
        "Uri" = "https://developer.api.autodesk.com/construction/reviews/v1/projects/$($project.id.TrimStart("b."))/reviews"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

function Get-ApsAccReviewVersions($project, $review) {
    $parameters = @{ 
        "Uri" = "https://developer.api.autodesk.com/construction/reviews/v1/projects/$($project.id.TrimStart("b."))/reviews/$($review.id)/versions"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $response = Invoke-RestMethod @parameters
    return $response.results
}

function Add-ApsAccReview($project, $workflow, $reviewName, $reviewNotes, $versions) { 
    $fileVersions = @()
    foreach($version in $versions) {
        $fileVersions += @{
            "urn" = $version.id
        }
    }

    $body = ConvertTo-Json @{
        "name" = $reviewName
        "fileVersions" = @($fileVersions)
        "workflowId" = "$($workflow.id)"
        "notes" = "$($reviewNotes)"
        "workflowOptions" = @{
            "copyFilesOptions" = @{
                "folderUrn" = "$($workflow.copyFilesOptions.folderUrn)"
            }
            "steps" = @($workflow.steps)
        }
    } -Depth 100 -Compress
    
    $parameters = @{ 
        "Uri" = "https://developer.api.autodesk.com/construction/reviews/v1/projects/$($project.id.TrimStart("b."))/reviews"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }
    $response = Invoke-RestMethod @parameters
    return $response
}
