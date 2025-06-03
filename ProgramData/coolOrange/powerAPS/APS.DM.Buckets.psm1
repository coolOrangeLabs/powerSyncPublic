#==============================================================================#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#                                                                              #
# Copyright (C) 2024 COOLORANGE S.r.l.                                         #
#==============================================================================#

# Autodesk Platform Services - Data Management Hubs and Projects

# Function to download a file by version to the specified local path. 
# Reference: https://aps.autodesk.com/en/docs/data/v2/tutorials/download-file/
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/buckets-:bucketKey-objects-:objectKey-signeds3download-GET
function Get-ApsBucketFile($version, $path = "C:\TEMP") {
    Write-Host "Downloading File..."

    $uri = New-Object System.Uri -ArgumentList @($version.relationships.storage.meta.link.href)
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com$($uri.AbsolutePath)/signeds3download"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $responseDownload = Invoke-RestMethod @parameters

    # Download the File
    $ProgressPreference = 'SilentlyContinue' 
    Invoke-WebRequest -Uri $responseDownload.url -OutFile ([System.IO.Path]::Combine($path, $version.attributes.displayName))
    $ProgressPreference = 'Continue'
}

# Function to upload a file to a specified folder in a project. Returns an upload status object.
# Reference: https://aps.autodesk.com/en/docs/data/v2/reference/http/projects-project_id-storage-POST
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/buckets-:bucketKey-objects-:objectKey-signeds3upload-GET
# API documentation: https://aps.autodesk.com/en/docs/data/v2/reference/http/buckets-:bucketKey-objects-:objectKey-signeds3upload-POST
function Add-ApsBucketFile($project, $folder, $fullFilePath) {
    Write-Host "Creating Storage Object..."

    $body = ConvertTo-Json @{
        "jsonapi" = @{
            "version" = "1.0"
        }
        "data" = @{
            "type" = "objects"
            "attributes" = @{
                "name" = "$([System.IO.Path]::GetFileName($fullFilePath))"
            }
            "relationships" = @{
                "target" = @{
                    "data" = @{
                        "type" = "folders"
                        "id" = "$($folder.id)"
                    }
                }
            }
        }
    } -Depth 100 -Compress
  
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/data/v1/projects/$($project.id)/storage"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/vnd.api+json"
        "Body" = (New-Object System.Text.UTF8Encoding($false)).GetBytes($body)
    }
    $responseStorage = Invoke-RestMethod @parameters
    $storage = $responseStorage.data

    $parts = $storage.id.Split(":")
    for ($i = 1; $i -le $parts.Count; $i++) { 
        if ($parts[$i] -eq "os.object") {
            $osObject = $parts[$i + 1]
            break
        }
    }
    $osObjects = $osObject.Split("/")
    $bucketKey = $osObjects[0]
    $objectKey = $osObjects[1]

    # Generate a Signed S3 URL
    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/oss/v2/buckets/$bucketKey/objects/$objectKey/signeds3upload?minutesExpiration=60"
        "Method" = "Get"
        "Headers" = $ApsConnection.RequestHeaders
    }
    $responseUpload = Invoke-RestMethod @parameters
    $urls = $responseUpload.urls
    $url = $urls[0]

    Write-Host "Uploading file '$fullFilePath' to S3..."

    # Upload a File to the Signed URL
    Set-ItemProperty -Path $fullFilePath -Name IsReadOnly -Value $false
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -Method Put -InFile $fullFilePath
    $ProgressPreference = 'Continue'

    # Complete the Upload
    $body = ConvertTo-Json @{
        "uploadKey" = "$($responseUpload.uploadKey)"
    } -Depth 100 -Compress

    $parameters = @{
        "Uri" = "https://developer.api.autodesk.com/oss/v2/buckets/$bucketKey/objects/$objectKey/signeds3upload"
        "Method" = "Post"
        "Headers" = $ApsConnection.RequestHeaders
        "ContentType" = "application/json"
        "Body" = $body
    }    
    $responseFinalized = Invoke-RestMethod @parameters
    return $responseFinalized
}
