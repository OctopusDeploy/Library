$existingRules = Get-WebConfiguration /system.webServer/security/ipSecurity/* -location $Site -pspath IIS://;
[Object[]]$newRules = @();

$ips = $IpAddresses -split '\n';
$ips = $ips.Trim('\r');
foreach ($u in $ips) {
    $a = $u.Split("/");
    $newRules += [Object]@{ ipAddress = $a[0]; subnetMask = $a[1]; allowed = $true };
}

if ($EnableProxyMode -eq "true") {
    Write-Output "Enabling proxy mode"
    set-webconfigurationproperty -Filter /system.webServer/security/ipSecurity -location $Site -Name "enableProxyMode" -Value "true"
}

if ($SetDeny -eq "true") {
    Write-Output "Setting Deny rule"
    set-webconfigurationproperty -Filter /system.webServer/security/ipSecurity -location $Site -Name "allowUnlisted" -Value "false"
}

function addRules([string]$website, [Object[]]$newRules, [Object[]]$oldRules) {

    foreach ($rule in $newRules) {
        if (ruleExists $rule $oldRules) {
            Write-Host "Rule $($rule.ipAddress)/$($rule.subnetMask) already exists";

            continue;
        }

        $value = @{ipAddress = $($rule.ipAddress); allowed = "true" }
        if ([string]::IsNullOrEmpty($rule.subnetMask)) {
            Write-Output "Adding ip $($rule.ipAddress) to allow"
        }
        else {
            Write-Output "Adding ip $($rule.ipAddress)/$($rule.subnetMask) to allow"
            $value.subnetMask = $rule.subnetMask;
        }

        add-webconfiguration /system.webServer/security/ipSecurity -location $website -value $value -pspath IIS://
    }    
}

function clearRules([string]$website, [Object[]]$newRules, [Object[]]$oldRules) {

    foreach ($rule in $oldRules) {
        if (ruleExists $rule $newRules) {
            continue;
        }

        Write-Host "Rule $($rule.ipAddress)/$($rule.subnetMask) is not exists, remove it";

        Clear-WebConfiguration -Filter $rule.ItemXPath -location $rule.Location
    }    
}

function ruleExists([Object]$rule, [Object[]]$rules) {
    foreach ($r in $rules) {
        if ($r.ipAddress -eq $rule.ipAddress -and $r.allowed -eq $rule.allowed) {
            if ($r.subnetMask -eq $rule.subnetMask) {
                return $true;
            }

            if (([string]::IsNullOrEmpty($r.subnetMask) -or $r.subnetMask -eq "255.255.255.255") -and ([string]::IsNullOrEmpty($rule.subnetMask) -or $rule.subnetMask -eq "255.255.255.255")) {
                return $true;
            }
        }
    }

    return $false;
}

addRules $Site $newRules $existingRules;
clearRules $Site $newRules $existingRules;
