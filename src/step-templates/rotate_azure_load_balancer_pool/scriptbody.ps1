$LoadBalancerNames = [string]$OctopusParameters['RotateAzureLoadBalancerPool.LoadBalancerName']
$AvailablePools = [string]$OctopusParameters['RotateAzureLoadBalancerPool.AvailablePools']
$RuleNames = [string]$OctopusParameters['RotateAzureLoadBalancerPool.RuleNames']
$WhatIf = [bool]::Parse($OctopusParameters['RotateAzureLoadBalancerPool.WhatIf'])

if ($null -eq $LoadBalancerNames) {
    throw 'No load balancers selected. Please select at least one load balancer.'
} else {
    # Trim white space and blank lines and get all load balancers that match the names.
    $loadBalancers = $LoadBalancerNames.Split("`n").Trim().Where({ $_ }) | ForEach-Object { Get-AzLoadBalancer -Name $_ }
}
if ($null -eq $AvailablePools) {
    throw 'No pools selected. Please select at least one pool.'
} else {
    $AvailablePools = $AvailablePools.Split("`n").Trim().Where({ $_ }) # Trim white space and blank lines.
}
if ($null -eq $RuleNames) {
    throw 'No rules selected. Please select at least one rule name or use an asterisk (*) to select all rules.'
} else {
    $RuleNames = $RuleNames.Split("`n").Trim().Where({ $_ }) # Trim white space and blank lines.
}

foreach ($loadBalancer in $loadBalancers) {
    $loadBalancerName = $loadBalancer.Name
    $resourceGroupName = $loadBalancer.ResourceGroupName
    $allPools = Get-AzLoadBalancerBackendAddressPool -LoadBalancerName $loadBalancerName -ResourceGroupName $resourceGroupName

    Write-Host "Updating Load Balancer '$loadBalancerName'."

    # Start by assuming no rules match
    $rules = @()

    # Add each distinct rule that matches one of the rule names
    foreach ($ruleName in $RuleNames) {
        $rules += $LoadBalancer.LoadBalancingRules | Where-Object {
            $_.Id.Split('/')[-1] -like $ruleName -and
            $_.Id -notin $rules.Id
        }
    }

    if ($rules.Count -eq 0) {
        Write-Warning "No matching rules were found on load balancer '$loadBalancerName'."
        continue
    }

    # Resolve any wildcards in AvailablePools to get a list of valid pool names.
    $validPoolNames = @()
    foreach ($name in $AvailablePools) {
        $validPoolNames += $allPools.Name | Where-Object { $_ -like $name }
    }

    # The same pool could match multiple wildcards so get a unique list
    if ($validPoolNames) {
        $validPoolNames = [array]($validPoolNames | Select-Object -Unique)
    } else {
        Write-Warning "No valid pools were found on load balancer '$loadBalancerName'."
        continue
    }

    # Update each rule with a new pool 
    foreach ($rule in $rules) {
        $currentPoolName = $rule.BackendAddressPool.Id.Split('/')[-1]

        # This will find the next pool in the list, cycling back to the beginning if at the end. If the current pool isn't in the list,
        # its index will be -1. The next index will be zero so the first pool will be selected. 
        $index = $validPoolNames.IndexOf($currentPoolName)
        $nextIndex = ($index + 1) % $validPoolNames.Count
        $newPoolName = $validPoolNames[$nextIndex]

        # Get the new pool to use
        if ($newPoolName -in $allPools.Name) {
            $newPool = Get-AzLoadBalancerBackendAddressPool -ResourceGroupName $resourceGroupName -LoadBalancerName $loadBalancerName -Name $newPoolName
        } else {
            throw "Backend Pool '$newPoolName' does not exist on load balancer '$loadBalancerName'."
        }

        if ($currentPoolName -eq $newPoolName) {
            Write-Highlight "Rule '$($rule.Name)' is already pointing to pool '$currentPoolName' on load balancer '$loadBalancerName'."
        } else {
            Write-Highlight "Rule '$($rule.Name)' is pointing to pool '$currentPoolName'. Updating to pool '$newPoolName' on load balancer '$loadBalancerName'."
            $rule.BackendAddressPool.Id = $newPool.Id

            foreach ($pool in $rule.BackendAddressPools) {
                $pool.Id = $newPool.Id
            }
        }
    }

    if ($WhatIf) {
        Write-Highlight "WhatIf is set to true so skipping changes on Azure for load balancer '$loadBalancerName'."
    } else {
        Write-Verbose "Writing changes to Azure for load balancer '$loadBalancerName'."
        Set-AzLoadBalancer -LoadBalancer $loadBalancer | Out-Null
    }
}
