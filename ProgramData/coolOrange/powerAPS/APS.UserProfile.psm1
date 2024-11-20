#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# Autodesk Platform Services - User Profile

# Function to get the user information. Returns the user object.
# API documentation: https://aps.autodesk.com/en/docs/profile/v1/reference/profile/oidcuserinfo/
function Get-ApsUserInfo {
    Write-Host "Reading User Info..."

    $response = Invoke-RestMethod -Uri "https://api.userprofile.autodesk.com/userinfo" -Method Get -Headers $ApsConnection.RequestHeaders
    return $response
}