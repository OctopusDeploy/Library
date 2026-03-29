param(
        [string]$NSAddress,
        [string]$ServiceName,
        [string]$Action,
        [string]$NSUserName,
        [string]$NSPassword,
        [string]$NSProtocol
)


$ErrorActionPreference = "Stop"

function Connect-NSAppliance {
    <#
    .SYNOPSIS
        Connect to NetScaler Appliance
    .DESCRIPTION
        Connect to NetScaler Appliance. A custom web request session object will be returned
    .PARAMETER NSAddress
        NetScaler Management IP address
    .PARAMETER NSName
        NetScaler DNS name or FQDN
    .PARAMETER NSUserName
        UserName to access the NetScaler appliance
    .PARAMETER NSPassword
        Password to access the NetScaler appliance
    .PARAMETER Timeout
        Timeout in seconds to for the token of the connection to the NetScaler appliance. 900 is the default admin configured value.
    .EXAMPLE
         $Session = Connect-NSAppliance -NSAddress 10.108.151.1
    .EXAMPLE
         $Session = Connect-NSAppliance -NSName mynetscaler.mydomain.com
    .OUTPUTS
        CustomPSObject
    .NOTES
        Copyright (c) Citrix Systems, Inc. All rights reserved.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ParameterSetName='Address')] [string]$NSAddress,
        [Parameter(Mandatory=$true,ParameterSetName='Name')] [string]$NSName,
        [Parameter(Mandatory=$false)] [string]$NSUserName="nsroot",
        [Parameter(Mandatory=$false)] [string]$NSPassword="nsroot",
        [Parameter(Mandatory=$false)] [int]$Timeout=900
    )
    Write-Verbose "$($MyInvocation.MyCommand): Enter"

    if ($PSCmdlet.ParameterSetName -eq 'Address') {
        Write-Verbose "Validating IP Address"
        $IPAddressObj = New-Object -TypeName System.Net.IPAddress -ArgumentList 0
        if (-not [System.Net.IPAddress]::TryParse($NSAddress,[ref]$IPAddressObj)) {
            throw "'$NSAddress' is an invalid IP address"
        }
        $nsEndpoint = $NSAddress
    } elseif ($PSCmdlet.ParameterSetName -eq 'Name') {
        $nsEndpoint = $NSName
    }


    $login = @{"login" = @{"username"=$NSUserName;"password"=$NSPassword;"timeout"=$Timeout}}
    $loginJson = ConvertTo-Json $login

    try {
        Write-Verbose "Calling Invoke-RestMethod for login"
        $response = Invoke-RestMethod -Uri "$($Script:NSURLProtocol)://$nsEndpoint/nitro/v1/config/login" -Body $loginJson -Method POST -SessionVariable saveSession -ContentType application/json

        if ($response.severity -eq "ERROR") {
            throw "Error. See response: `n$($response | fl * | Out-String)"
        } else {
            Write-Verbose "Response:`n$(ConvertTo-Json $response | Out-String)"
        }
    }
    catch [Exception] {
        throw $_
    }


    $nsSession = New-Object -TypeName PSObject
    $nsSession | Add-Member -NotePropertyName Endpoint -NotePropertyValue $nsEndpoint -TypeName String
    $nsSession | Add-Member -NotePropertyName WebSession  -NotePropertyValue $saveSession -TypeName Microsoft.PowerShell.Commands.WebRequestSession

    Write-Verbose "$($MyInvocation.MyCommand): Exit"

    return $nsSession
}

function Set-NSMgmtProtocol {
    <#
    .SYNOPSIS
        Set $Script:NSURLProtocol, this will be used for all subsequent invocation of NITRO APIs
    .DESCRIPTION
        Set $Script:NSURLProtocol
    .PARAMETER Protocol
        Protocol, acceptable values are "http" and "https"
    .EXAMPLE
        Set-Protocol -Protocol https
    .NOTES
        Copyright (c) Citrix Systems, Inc. All rights reserved.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [ValidateSet("http","https")] [string]$Protocol
    )

    Write-Verbose "$($MyInvocation.MyCommand): Enter"

    $Script:NSURLProtocol = $Protocol

    Write-Verbose "$($MyInvocation.MyCommand): Exit"
}

function Invoke-NSNitroRestApi {
    <#
    .SYNOPSIS
        Invoke NetScaler NITRO REST API
    .DESCRIPTION
        Invoke NetScaler NITRO REST API
    .PARAMETER NSSession
        An existing custom NetScaler Web Request Session object returned by Connect-NSAppliance
    .PARAMETER OperationMethod
        Specifies the method used for the web request
    .PARAMETER ResourceType
        Type of the NS appliance resource
    .PARAMETER ResourceName
        Name of the NS appliance resource, optional
    .PARAMETER Action
        Name of the action to perform on the NS appliance resource
    .PARAMETER Payload
        Payload  of the web request, in hashtable format
    .PARAMETER GetWarning
        Switch parameter, when turned on, warning message will be sent in 'message' field and 'WARNING' value is set in severity field of the response in case there is a warning.
        Turned off by default
    .PARAMETER OnErrorAction
        Use this parameter to set the onerror status for nitro request. Applicable only for bulk requests.
        Acceptable values: "EXIT", "CONTINUE", "ROLLBACK", default to "EXIT"
    .EXAMPLE
        Invoke NITRO REST API to add a DNS Server resource.
        $payload = @{ip="10.8.115.210"}
        Invoke-NSNitroRestApi -NSSession $Session -OperationMethod POST -ResourceType dnsnameserver -Payload $payload -Action add
    .OUTPUTS
        Only when the OperationMethod is GET:
        PSCustomObject that represents the JSON response content. This object can be manipulated using the ConvertTo-Json Cmdlet.
    .NOTES
        Copyright (c) Citrix Systems, Inc. All rights reserved.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [PSObject]$NSSession,
        [Parameter(Mandatory=$true)] [ValidateSet("DELETE","GET","POST","PUT")] [string]$OperationMethod,
        [Parameter(Mandatory=$true)] [string]$ResourceType,
        [Parameter(Mandatory=$false)] [string]$ResourceName,
        [Parameter(Mandatory=$false)] [string]$Action,
        [Parameter(Mandatory=$false)] [ValidateScript({$OperationMethod -eq "GET"})] [hashtable]$Arguments=@{},
        [Parameter(Mandatory=$false)] [ValidateScript({$OperationMethod -ne "GET"})] [hashtable]$Payload=@{},
        [Parameter(Mandatory=$false)] [switch]$GetWarning=$false,
        [Parameter(Mandatory=$false)] [ValidateSet("EXIT", "CONTINUE", "ROLLBACK")] [string]$OnErrorAction="EXIT"
    )

    Write-Verbose "$($MyInvocation.MyCommand): Enter"

    Write-Verbose "Building URI"
    $uri = "$($Script:NSURLProtocol)://$($NSSession.Endpoint)/nitro/v1/config/$ResourceType"
    if (-not [string]::IsNullOrEmpty($ResourceName)) {
        $uri += "/$ResourceName"
    }
    if ($OperationMethod -ne "GET") {
        if (-not [string]::IsNullOrEmpty($Action)) {
            $uri += "?action=$Action"
        }
    } else {
        if ($Arguments.Count -gt 0) {
            $uri += "?args="
            $argsList = @()
            foreach ($arg in $Arguments.GetEnumerator()) {
                $argsList += "$($arg.Name):$([System.Uri]::EscapeDataString($arg.Value))"
            }
            $uri += $argsList -join ','
        }
        #TODO: Add filter, view, and pagesize
    }
    Write-Verbose "URI: $uri"

    if ($OperationMethod -ne "GET") {
        Write-Verbose "Building Payload"
        $warning = if ($GetWarning) { "YES" } else { "NO" }
        $hashtablePayload = @{}
        $hashtablePayload."params" = @{"warning"=$warning;"onerror"=$OnErrorAction;<#"action"=$Action#>}
        $hashtablePayload.$ResourceType = $Payload
        $jsonPayload = ConvertTo-Json $hashtablePayload -Depth ([int]::MaxValue)
        Write-Verbose "JSON Payload:`n$jsonPayload"
    }

    try {
        Write-Verbose "Calling Invoke-RestMethod"
        $restParams = @{
            Uri = $uri
            ContentType = "application/json"
            Method = $OperationMethod
            WebSession = $NSSession.WebSession
            ErrorVariable = "restError"
        }

        if ($OperationMethod -ne "GET") {
            $restParams.Add("Body",$jsonPayload)
        }

        $response = Invoke-RestMethod @restParams

        if ($response) {
            if ($response.severity -eq "ERROR") {
                throw "Error. See response: `n$($response | fl * | Out-String)"
            } else {
                Write-Verbose "Response:`n$(ConvertTo-Json $response | Out-String)"
            }
        }
    }
    catch [Exception] {
        if ($ResourceType -eq "reboot" -and $restError[0].Message -eq "The underlying connection was closed: The connection was closed unexpectedly.") {
            Write-Verbose "Connection closed due to reboot"
        } else {
            throw $_
        }
    }

    Write-Verbose "$($MyInvocation.MyCommand): Exit"

    if ($OperationMethod -eq "GET") {
        return $response
    }
}

$psver = $PSVersionTable.PSVersion.Major
if ($psver -eq "1" -or $psver -eq "2") {
    Write-Error "NetScaler ADC Enable Disable Service requires PowerShell v3 or newer. Installed version v$psver"
    return -1
}

$NSAddress = $OctopusParameters['HostName']
$NSUserName = $OctopusParameters['Username']
$NSPassword = $OctopusParameters['Password']
$NSProtocol="http"
$Action = $OctopusParameters['EnableOrDisable']
$ServiceName = $OctopusParameters['ServiceName']
$GracefulShutdown = $OctopusParameters['Graceful']
$GraceFulShutdownDelay = $OctopusParameters['GracefulDelay']

if(!$NSAddress) {
    Write-Error "No NetScaler address specified. Please specify an address"
    exit -2
}

if(!$NSUserName) {
    Write-Error "No username specified. Please specify a username"
    exit -2
}

if(!$NSPassword) {
    Write-Error "No password specified. Please specify a password"
    exit -2
}

if(!$Action) {
    Write-Error "No action set. Action must either be enable or disable. Please select an action"
    exit -2
}

if(!$GracefulShutdown) {
    Write-Error "Graceful shutdown not selected. Must either be yes or no. Please select an option"
    exit -2
}

if(!$ServiceName) {
    Write-Error "Service name must be specified. Please specify service name"
    exist -2
}


Set-NSMgmtProtocol -Protocol $NSProtocol
$myNSSession = Connect-NSAppliance -NSAddress $NSAddress -NSUserName $NSUserName -NSPassword $NSPassword
$payload = @{name=$ServiceName}
if($Action -eq "disable") {
    $payload = @{name=$ServiceName;graceful=$GracefulShutdown;delay=$GraceFulShutdownDelay}
}

Invoke-NSNitroRestApi -NSSession $myNSSession -OperationMethod POST -ResourceType service -Payload $payload -Action $Action
