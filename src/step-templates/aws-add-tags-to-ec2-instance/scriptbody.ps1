# Running outside octopus
param(
    [string]$odInstanceId,
    [string]$odAction,
    [string]$odTags,
    [string]$odAccessKey,
    [string]$odSecretKey,
    [switch]$whatIf
) 

$ErrorActionPreference = "Stop" 

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if (!$result -or $result -eq $null) {
        if ($Default) {
            $result = $Default
        } elseif ($Required) {
            throw "Missing parameter value $Name"
        }
    }

    return $result
}


& {
    param(
        [string]$odInstanceId,
        [string]$odAction,
        [string]$odTags,
        [string]$odAccessKey,
        [string]$odSecretKey
    ) 
    
    # If AWS key's are not provided as params, attempt to retrieve them from Environment Variables
    if ($odAccessKey -or $odSecretKey) {
        Set-AWSCredentials -AccessKey $odAccessKey -SecretKey $odSecretKey -StoreAs default
    } elseif (([Environment]::GetEnvironmentVariable("AWS_ACCESS_KEY", "Machine")) -or ([Environment]::GetEnvironmentVariable("AWS_SECRET_KEY", "Machine"))) {
        Set-AWSCredentials -AccessKey ([Environment]::GetEnvironmentVariable("AWS_ACCESS_KEY", "Machine")) -SecretKey ([Environment]::GetEnvironmentVariable("AWS_SECRET_KEY", "Machine")) -StoreAs default
    } else {
        throw "AWS API credentials were not available/provided."
    }



    Write-Output ("------------------------------")
    Write-Output ("Add/Remove Instance Tags:")
    Write-Output ("------------------------------")
    
    $filterArray = @()
    $tagsHash = (ConvertFrom-StringData $odTags).GetEnumerator()
    Foreach ($tag in $tagsHash) {
        $tagObj = $(Get-EC2Instance -InstanceId $odInstanceId).Instances.Tags | ? {$_.Key -eq $tag.Key -and $_.Value -eq $tag.Value}
        $tagObjCount = ($tagObj | measure).Count
        if ($tagObjCount -gt 0) {
            if ($odAction -eq "New") {
                Write-Output ("Cannot Add: The tag '$($tag.Key)=$($tag.Value)' already exists, skipping...")
            } elseif ($odAction -eq "Remove") {
                Write-Output ("The tag '$($tag.Key)=$($tag.Value)' exists, deleting...")

                try {
                    Remove-EC2Tag -Tags @{key=$tag.Key} -resourceId $odInstanceId -Force
                }
                catch [Amazon.EC2.AmazonEC2Exception] {
                    throw $_.Exception.errorcode + '-' + $_.Exception.Message
                }
            }
        } else {
            if ($odAction -eq "New") {
                Write-Output ("The combination of tag and value '$($tag.Key)=$($tag.Value)' does not exist, Creating/Updating tag...")

                try {
                    New-EC2Tag -Tags @{key=$tag.Key;value=$tag.Value} -resourceId $odInstanceId
                }
                catch [Amazon.EC2.AmazonEC2Exception] {
                    throw $_.Exception.errorcode + '-' + $_.Exception.Message
                }
            } elseif ($odAction -eq "Remove") {
                Write-Output ("Cannot Remove: The tag '$($tag.Key)=$($tag.Value)' does not exist, skipping...")
            }
        }
    }
 } `
 (Get-Param 'odInstanceId' -Required) `
 (Get-Param 'odAction' -Required) `
 (Get-Param 'odTags' -Required) `
 (Get-Param 'odAccessKey') `
 (Get-Param 'odSecretKey')