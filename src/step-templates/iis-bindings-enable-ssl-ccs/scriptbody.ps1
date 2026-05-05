$WebSiteName = $OctopusParameters['IisCcsWebSiteName'];
[bool]$SNI = $false;
if (-not [bool]::TryParse($OctopusParameters['IisCcsSNI'], [ref]$SNI)) {
    $SNI = $true;
}
$SslFlags = 2; # Use CCS
if ($SNI) {
	$SslFlags = 3; # Use SNI CCS
}
$PortMap = [System.Collections.Generic.Dictionary[int,int]]::new();
foreach ($mapping in [regex]::Matches($OctopusParameters['IisCcsPortMap'],"([0-9]+):([0-9]+)")) {
    $PortMap.Add([int]$mapping.Groups[1].Value, [int]$mapping.Groups[2].Value);
}
$httpBindings = Get-WebBinding -Name $WebSiteName -Protocol http | Foreach-Object { $_.bindingInformation };
if (-not $httpBindings) {
    Write-Error "The site $WebSiteName does not exist, or it has not HTTP binding"
}
foreach ($binding in (Get-WebBinding -Name $WebSiteName -Protocol http | Foreach-Object { $_.bindingInformation })) {
    $parts = $binding.Split(":");
    $IPAddress = $parts[0];
    $HostHeader = $parts[2];
    [int]$Port = 0;
    if ([string]::IsNullOrEmpty($HostHeader)) {
        Write-Warning "The binding $binding has no hostname, skipping";
    } elseif (-not $PortMap.TryGetValue([int]$parts[1], [ref]$Port)) {
        Write-Warning "There is no port mapping for the binding $binding, skipping";
    } else {
        Write-Verbose "Binding HTTP $binding to HTTPS $($IPAddress):$($Port):$($HostHeader)";
        $existingBinding = Get-WebBinding -Name $WebSiteName -Protocol https -IPAddress $IPAddress -Port $Port -HostHeader $HostHeader;
        if ($existingBinding) {
            if ($existingBinding.sslFlags -ne $SslFlags) {
                Write-Host "Change SSL flags of binding $($IPAddress):$($Port):$($HostHeader)";
                Set-WebBinding -Name $WebSiteName -IPAddress $IPAddress -Port $Port -HostHeader $HostHeader -PropertyName SslFlags -Value $SslFlags;
            }
        } else {
            Write-Host "Create HTTPS binding $($IPAddress):$($Port):$($HostHeader)";
            New-WebBinding -Name $WebSiteName -Protocol https -IPAddress $IPAddress -Port $Port -HostHeader $HostHeader -SslFlags $SslFlags;
        }
    }
}