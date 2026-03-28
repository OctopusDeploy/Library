function Add-ValueToHashtable
{
    param(
    [Parameter(Mandatory = 1)][object]$variable,
    [Parameter(Mandatory = 1)][hashtable]$hashtable
    )

    if ($variable.value.GetType() -eq [System.String])
    {
        $hashtable.Add($variable.Name, $variable.value)
        return
    }

    if (($variable.value.GetType() -eq (New-Object 'System.Collections.Generic.Dictionary[String,String]').GetType()) -or ($variable.value.GetType() -eq [Hashtable]))
    {
        foreach ($element in $variable.Value.GetEnumerator())
        {
            $obj = New-Object PsObject -Property @{ Name = $element.Key; Value = $element.Value }
            Add-ValueToHashtable -variable $obj -hashtable $hashtable
        }
        return
    }

    throw "Add-ValueToHashtable method does not know what to do with type " + $variable.value.GetType().Name
}

function Get-UnixDate
{
    $epoch = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0	
    $now = Get-Date
    return ([math]::truncate($now.ToUniversalTime().Subtract($epoch).TotalMilliSeconds))
}

function Get-IsRollback
{
    $currentVersion = New-Object -TypeName System.Version -ArgumentList $OctopusReleaseNumber
    $prevVersion = New-Object -TypeName System.Version -ArgumentList $OctopusReleasePreviousNumber

    return ($currentVersion.CompareTo($prevVersion) -lt 0)
}

function Get-OctopusVariablesJson
{
    $octoVariables = @{}

    foreach ($var in (Get-Variable -Name OctopusParameters*))
    {
        Add-ValueToHashtable -variable $var -hashtable $octoVariables
    }

    $octoVariables.Add("isrollback", (Get-IsRollback))
    $octoVariables.Add("timestamp", (Get-UnixDate))
    $octoVariables.Add("safeprojectname", $OctopusParameters["Octopus.Project.Name"].Replace(" ", "_"))

    return ($octoVariables | ConvertTo-Json -Compress)
}

function ConvertTo-AsciiString
{
    param(  
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$input)
    
    process {
        #custom desired transformation
        $tmp = $input.Replace([char]0x00EC, "i")
        #fallback
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($tmp)
        $asciiArray = [System.Text.Encoding]::Convert([System.Text.Encoding]::UTF8, [System.Text.Encoding]::ASCII, $bytes)
        $ascistring = [System.Text.Encoding]::ASCII.GetString($asciiArray)
        return $ascistring
    }
}

$json = Get-OctopusVariablesJson | ConvertTo-AsciiString
$body = New-Object PsObject -Property @{ properties = @{}; routing_key = "#"; payload = $json; payload_encoding = "string" } | ConvertTo-Json -Compress

$securepassword = ConvertTo-SecureString $rabbitPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($rabbitUsername, $securepassword)

Invoke-RestMethod -Uri "$rabbitUrl/api/exchanges/$rabbitVirtualHost/$rabbitExchange/publish" -Method Post -Credential $cred -Body $body -ContentType "application/json"