#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - Data Management Folders

# Function to get all items and subfolders. Returns all items objects and folder objects from the given folder.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-folders-folder_id-contents-GET
function Get-ApsFolderContents($project, $folder) {
    #Write-Host "Reading Folder Contents..."

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/folders/$($folder.id)/contents"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    #$response = Invoke-RestMethod @parameters
    #return $response.data

    $response = Invoke-WebRequest @parameters
    $ms = New-Object System.IO.MemoryStream
    $response.RawContentStream.CopyTo($ms)
    $json = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    $data = $json | ConvertFrom-Json
    return $data.data
}

# Function to create a new folder. Returns a folder object.
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-folders-POST
function Add-ApsFolder($project, $parentFolder, $folderName) {
    Write-Host "Creating Folder '$($folderName)'..."

    $body = ConvertTo-Json @{
        "jsonapi" = @{
            "version" = "1.0"
        }
        "data" = @{
            "type" = "folders"
            "attributes" = @{
                "name" = "$($folderName)"
                "extension" = @{
                    "type" = "folders:autodesk.bim360:Folder"
                    "version" = "1.0"
                }
            }
            "relationships" = @{
                "parent" = @{
                    "data" = @{
                        "type" = "folders"
                        "id" = "$($parentFolder.id)"
                    }
                }
            }
        }
    } -Depth 100 -Compress

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/folders"
        "Method" = "Post"
        "ContentType" = "application/vnd.api+json"
        "Headers" = $ApsConnection.RequestHeaders
        "Body" = (New-Object System.Text.UTF8Encoding($false)).GetBytes($body)
    }    
    $response = Invoke-RestMethod @parameters
    return $response.data
}
