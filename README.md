# powerSync

[![Windows](https://img.shields.io/badge/Platform-Windows-lightgray.svg)](https://www.microsoft.com/en-us/windows/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue.svg)](https://microsoft.com/PowerShell/)
[![Vault](https://img.shields.io/badge/Autodesk%20Vault-2024+2025-yellow.svg)](https://www.autodesk.com/products/vault/)
[![Autodesk Platform Services](https://img.shields.io/badge/Autodesk%20Platform%20Services-APIs-purple.svg)](https://aps.autodesk.com/)

[![powerJobs Processor](https://img.shields.io/badge/coolOrange%20powerJobs%20Processor-24+25-orange.svg)](https://www.coolorange.com/powerjobs)
[![powerJobs Client](https://img.shields.io/badge/coolOrange%20powerJobs%20Client-24+25-orange.svg)](https://www.coolorange.com/powerjobs)


## Disclaimer

THE SAMPLE CODE ON THIS REPOSITORY IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.

THE USAGE OF THIS SAMPLE IS AT YOUR OWN RISK AND **THERE IS NO SUPPORT** RELATED TO IT.

## Description
powerSync is an extension for powerJobs to integrate with Autodesk Construction Cloud (ACC) and Fusion Team. It makes use of the Autodesk Platform Services (APS) APIs.

## Prerequisites
powerSync requires coolOrange powerJobs to be installed on the Autodesk Vault Job Processor and on the Autodesk Vault Clients.

## Installation
- Download and install powerJobs Client and powerJobs Processor.
- Clone or download the repository and copy all folders and files from 'Program Files/coolOrange/Modules/powerAPS' to `%programfiles%\coolOrange\Modules\powerAPS` and from 'ProgramData/coolOrange' to `%programdata%\coolOrange`. 
- Restart Vault to apply the changes.

## Webinar Recording
The configuration of powerSync, its base functionality and the benefits were explained in a dedicated webinar. The recording of this webinar can be found here: https://www.coolorange.com/webinar-follow-up-synchronize-autodesk-vault-with-acc

## Cmdlets
powerSync contains PowerShell functions (cmdlets) for Autodesk Platform Services (APS) OAuth authentication. The cmdlets are bundled in a PowerShell module called `powerAPS` and support 2-legged and 3-legged OAuth authentication, including UI for 3-legged user authentication in PowerShell and Autodesk Vault.

OAuth tokens are refreshed automatically during the objects lifespan.

To use it in a PowerShell script, the powerAPS module must be imported:

```powershell
Import-Module powerAPS
```

### Open-ApsConnection cmdlet
#### Description
Opens a connection to Autodesk Platform Services (APS) using the APS Authentication API. Once connected the global variable `$ApsConnection` can be used to communicate with APS.



#### Parameters
| Parameter    | Description                                                                                              | Mandatory | Remarks                                                                                                                    |
|--------------|----------------------------------------------------------------------------------------------------------|-----------|----------------------------------------------------------------------------------------------------------------------------|
| ClientId     | Client ID of the APS Application                                                                         | true      |                                                                                                                            |
| ClientSecret | Client Secret of the APS Application                                                                     | false     | Not needed when app is of type 'PKCE'                                                                                      |
| CallbackUrl  | URL-encoded callback URL that the end user will be redirected to after completing the authorization flow | false     | This must match the pattern of the callback URL field of the APS App's registration Not needed for 2-legged authentication |
| Scope        | Please see https://aps.autodesk.com/en/docs/oauth/v2/developers_guide/scopes/ for more details           | false     | Default: 'data:read data:write'                                                                                            |
| AccountId    | Autodesk Account ID (used in the 'x-user-id' Request Header")                                            | false     | Not needed when app is 3-legged                                                                                            |
| Username     | Autodesk Email Address                                                                                   | false     |                                                                                                                            |
| Password     | Autodesk Password                                                                                        | false     |                                                                                                                            |
| Visible      | Dialog always visible, even if all required parameters are provided                                      | false     |                                                                                                                            |
| Express      | Skip the Username and Consent pages, if possible                                                         | false     |                                                                                                                            |

#### Examples
**3-legged example: fully automated incl. 'Import-Module' and Hubs query**

Doesn't displays a login window, automatically fills out username and password and agrees the APS consent. Once authenticated, all APS hubs are listed: 

```powershell
Import-Module powerAPS

$apsParameters = @{
    "ClientId"     = $clientId
    "ClientSecret" = $clientSecret
    "CallbackUrl"  = $callbackUrl
    "Scope"        = $scope
    "Username"     = $username
    "Password"     = $password
}
$result = Open-APSConnection @apsParameters -Express
if (-not $result) {
    throw "Cannot connect to APS"
}

$parameters = @{
    "Uri" = "https://developer.api.autodesk.com/project/v1/hubs"
    "Method" = "Get"
    "Headers" = $ApsConnection.RequestHeaders
}
$response = Invoke-RestMethod @parameters

foreach ($hub in $response.data) {
    Write-Host $hub.attributes.name
}
```

**3-legged example: username automated**

Displays a login window, automatically fills out username and waits until the user enters the password. Once entered, powerAPS automatically agrees the consent and closes the window :

```powershell
$apsParameters = @{
    "ClientId"     = $clientId
    "ClientSecret" = $clientSecret
    "CallbackUrl"  = $callbackUrl
    "Scope"        = $scope
    "Username"     = $username
}
$result = Open-APSConnection @apsParameters -Express -Visible

...
```

**3-legged example: username automated (PKCE)**

Displays a login window, fills out username automatically and waits until the user enters the password. Once entered, powerAPS automatically agrees the consent and closes the window: 

```powershell
$apsParameters = @{
    "ClientId"     = $clientId
    "CallbackUrl"  = $callbackUrl
    "Scope"        = $scope
    "Username"     = $username
}
$result = Open-APSConnection @apsParameters -Express -Visible

...
```

**2-legged example**

Doesn't displays the login window, no need for username, password or consent: 

```powershell
$apsParameters = @{
    "ClientId"     = $clientId
    "ClientSecret" = $clientSecret
    "AccountId"    = $accountId
    "Scope"        = $scope
}
$result = Open-APSConnection @apsParameters

...
```

### Close-ApsConnection cmdlet
#### Description
Closes an existing APS connection and removes the `$ApsConnection` object.

#### Parameters
none

#### Example
```powershell
Close-APSConnection
```


### $ApsConnection variable

#### Description
Once authenticated with `Open-ApsConnection` this global object is available until `Close-ApsConnection` is called or the underlying PowerShell session ends.

#### Fields

| Name          | Type      | Remarks                                                                                                                                                                                       |
|---------------|-----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Token         | String    | The bearer token including the prefix "Bearer"                                                                                                                                                |
| Issued        | DateTime  | The time the token has been issued                                                                                                                                                            |
| Lifespan      | Integer   | The overall lifespan of the token in seconds                                                                                                                                                  |
| ExpiresIn     | Integer   | The remaining lifespan of the token in seconds                                                                                                                                                |
| ValidUntil    | DateTime  | The time until the token is valid                                                                                                                                                             |
| RefreshToken  | String    | The refresh token that is beeing used for the next automatic refresh                                                                                                                          |
| ClientId      | String    | The client ID this token is associated to                                                                                                                                                     |
| AuthType      | Enum      | The type of the authentication. Either 'TwoLegged' or 'ThreeLegged'                                                                                                                           |
| Scope         | String    | The scope of the authentication                                                                                                                                                               |
| CallbackUrl   | String    | The callback URL of the authentication                                                                                                                                                        |
| Username      | String    | The username of the authentication                                                                                                                                                            |
| RequestHeader | HashTable | A HashTable that can be used for the Invoke-RestMethod header parameter. "Authorization"="<BEARER TOKEN" for 3-legged, and "Authorization"="<BEARER TOKEN" + "x-user-id" = AccountId for 2-legged |

## Known Limitations
Coming soon...