#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

Import-Module powerAPS

# Import all modules in the powerAPS folder
foreach ($module in Get-Childitem "C:\ProgramData\coolOrange\powerAPS" -Name -Filter "*.psm1") {
    Import-Module "C:\ProgramData\coolOrange\powerAPS\$module" -Force -Global
}

function ApsTokenIsValid() {
    # Re-import all modules in the powerAPS folder, in case anything changed in the scripts
    foreach ($module in Get-Childitem "C:\ProgramData\coolOrange\powerAPS" -Name -Filter "*.psm1") {
        Import-Module "C:\ProgramData\coolOrange\powerAPS\$module" -Force -Global
    }

    # Check if the APS connection is already established
    if ($ApsConnection -and $ApsConnection.Token) {
        return $true
    }

    # Get the APS authentication settings from Vault
    $settings = GetVaultApsAuthenticationSettings
    if ($settings -is [powerAPS.Error]) {
        $settings.ShowErrorMessage()
        return $false
    }

    $arguments = @{
        ClientId = $settings.ClientId
        CallbackUrl = $settings.CallbackUrl
        Scope = $settings.Scope
    }

    # Get the Vault user email and use it as the default username
    $vaultLogin = [Autodesk.Connectivity.WebServicesTools.AutodeskAccount]::Login([IntPtr]::Zero)
    if ($vaultLogin -and $vaultLogin.AccountEmail) {
        $arguments.Username = $vaultLogin.AccountEmail
    }

    if (-not $settings.Pkce) {
        $arguments.ClientSecret = $settings.ClientSecret
    }

    # Connect to APS
    return Open-APSConnection @arguments -Express
}
