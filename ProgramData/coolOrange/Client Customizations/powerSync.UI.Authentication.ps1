#==============================================================================#
# (c) 2024 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

function Get-DialogApsAuthentication([Hashtable]$settings) {
    class DataContext {
        [bool] $Pkce
        [string] $ClientId
        [string] $ClientSecret
        [string] $CallbackUrl
        [System.Collections.ObjectModel.ObservableCollection[PsObject]] $Scope

        DataContext() {
            $this.Scope = New-Object System.Collections.ObjectModel.ObservableCollection[PsObject]
        }
    }

    $dataContext = [DataContext]::new()
    $dataContext.Pkce = $settings["Pkce"]
    $dataContext.ClientId = $settings["ClientId"]
    $dataContext.ClientSecret = $settings["ClientSecret"]
    $dataContext.CallbackUrl = $settings["CallbackUrl"]

    if (-not $settings["Scope"]) {
        $settings["Scope"] = "data:read data:write account:read"
    }
    $scopes = $settings["Scope"].Split(" ")
    foreach ($value in @(
            "account:read", 
            "account:write",
            "data:read", 
            "data:write", 
            "data:create", 
            "data:search", 
            "bucket:read", 
            "bucket:write", 
            "bucket:update", 
            "bucket:delete",             
            "user:read", 
            "user:write", 
            "user-profile:read", 
            "code:all",
            "viewables:read",
            "openid")) {
        $dataContext.Scope.Add((New-Object PsObject -Property @{ Name=$value; Checked=$scopes.Contains($value) }))
    }
  
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $xamlFile = [xml](Get-Content "C:\ProgramData\coolOrange\Client Customizations\powerSync.UI.Authentication.xaml")
    $window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )
    $window.WindowStartupLocation = "CenterScreen"
    $window.Owner = $Host.UI.RawUI.WindowHandle
    $window.DataContext = $dataContext
    $window.FindName('ClientSecret').Password = $window.DataContext.ClientSecret

    $window.FindName('Ok').add_Click({
        if ($window.DataContext.Pkce) {
            $window.DataContext.ClientSecret = ""
        } else {
            $window.DataContext.ClientSecret = $window.FindName('ClientSecret').Password
        }
        
        $window.DialogResult = $true
        $window.Close()
    }.GetNewClosure())

    $window.FindName('Test').add_Click({
        $window.DataContext.ClientSecret = $window.FindName('ClientSecret').Password
        $scope = ($window.DataContext.Scope | Where-Object { $_.Checked } | Select-Object -ExpandProperty Name) -join " "

        $arguments = @{
            ClientId = $window.DataContext.ClientId
            CallbackUrl = $window.DataContext.CallbackUrl
            Scope = $scope
        }

        if ($arguments.ClientId -eq "" -or $arguments.CallbackUrl -eq "" -or $scope -eq "") {
            [System.Windows.MessageBox]::Show("Please fill in all fields", "APS Connection Test", "OK", "Error")
            return
        }
    
        $vaultLogin = [Autodesk.Connectivity.WebServicesTools.AutodeskAccount]::Login([IntPtr]::Zero)
        if ($vaultLogin -and $vaultLogin.AccountEmail) {
            $arguments.Username = $vaultLogin.AccountEmail
        }
    
        if ($window.DataContext.Pkce) {
            $arguments.ClientSecret = ""
        } else {
            $arguments.ClientSecret = $window.DataContext.ClientSecret
        }

        Close-APSConnection
        $connected = Open-APSConnection @arguments
        
        if ($connected) {
            [System.Windows.MessageBox]::Show("Autodesk Platform Services (APS) Connection successful", "APS Connection Test", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("Autodesk Platform Services (APS) Connection failed", "APS Connection Test", "OK", "Error")
        }
    }.GetNewClosure())

    $window.FindName('GoTo').add_Click({
        Start-Process "https://aps.autodesk.com/myapps/"
    }.GetNewClosure())

    if ($window.ShowDialog()) {
        $settings["Pkce"] = $window.DataContext.Pkce
        $settings["ClientId"] = $dataContext.ClientId
        $settings["ClientSecret"] = $dataContext.ClientSecret
        $settings["CallbackUrl"] = $dataContext.CallbackUrl
        $settings["Scope"] = ($dataContext.Scope | Where-Object { $_.Checked } | Select-Object -ExpandProperty Name) -join " "
        return $settings
    }
    return $null
}