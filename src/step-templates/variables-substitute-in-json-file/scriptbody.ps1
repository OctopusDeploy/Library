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

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

$ErrorActionPreference = "Stop"

function UpdateJsonFile ([hashtable]$variables, [string]$fullpath) {
    Write-Host 'Starting the json file variable substitution' $variables.Count
    if ($variables -eq $null) {
        throw "Missing parameter value $variables"
    }

	$pathExists = Test-Path $fullpath
	if(!$pathExists) {
		Write-Host 'ERROR: Path '$fullpath ' does not exist'
		Exit 1
	}

	$json = Get-Content $fullpath -Raw | ConvertFrom-Json
    Write-Host 'Json content read from file'

	foreach($variable in $variables.GetEnumerator()) {
		$key = $variable.Key
        Write-Host 'Processing' $key
        $keys = $key.Split(':')
		$sub = $json
		$pre = $json
		$found = $true
		$lastKey = ''
		foreach($k in $keys) {
			if($sub | Get-Member -name $k -Membertype Properties){
				$pre = $sub
				$sub = $sub.$k
			}
			else
			{
				$found = $false
				break
			}

			$lastKey = $k
		}

		if($found) {
            Write-Host $key 'found in Json content'
            if($pre.$lastKey -eq $null) {
                Write-Host $key 'is null in the original source json...values CANNOT be null on the source json file...exiting with 1'
                Exit 1
            }

			$typeName = $pre.$lastKey.GetType().Name
			[bool]$b = $true
			[int]$i = 0
			[decimal]$d = 0.0
			if($typeName -eq 'String'){
				$pre.$lastKey = $variable.Value
			}
			elseif($typeName -eq 'Boolean' -and [bool]::TryParse($variable.Value, [ref]$b)) {
				$pre.$lastKey = $b
			}
			elseif($typeName -eq 'Int32' -and [int]::TryParse($variable.Value, [ref]$i)){
				$pre.$lastKey = $i
			}
			elseif($typeName -eq 'Decimal' -and [decimal]::TryParse($variable.Value, [ref]$d)){
				$pre.$lastKey = $d
			}
			elseif($typeName -eq 'Object[]') {
                if($pre.$lastKey.Length -ne 0 -and $pre.$lastKey[0].GetType().Name -eq 'String') {
				    $pre.$lastKey = $variable.Value.TrimStart('[').TrimEnd(']').Split(',')
                }
                else {
                    Write-Host 'ERROR: Cannot handle ' $key ' with type ' $typeName 
				    'Only nonempty string arrays are supported at the moment meaning that it has to be a 
				    string array with atleast one element in it in the original source appsettings.json 
				    file...Skipping update and exiting with 1'
				    Exit 1
                }
			}
			else {
				Write-Host 'ERROR: Cannot handle ' $key ' with type ' $typeName 
				'Only string, boolean, interger, decimal and non-empty string arrays are supported at the moment
                ...Skipping update and exiting with 1'
				Exit 1
			}

            Write-Host $key 'updated in json content with value' $pre.$lastKey 

		}
        else {
            Write-Host $key 'not found in Json content...skipping it'
        }
	}
    
	$json | ConvertTo-Json -depth 99 | Set-Content $fullpath

    
    Write-Host $fullpath 'file variables updated successfully...Done'
}


if($OctopusParameters -eq $null) {
    Write-Host 'OctopusParameters is null...exiting with 1'
    Exit 1    
}

function ConvertListToHashtable([object[]]$list) {
    $h = @{}
    foreach ($element in $list) {
	    $h.Add($element.Key, $element.Value)
    }
    return $h
}

$oParams = $OctopusParameters.getenumerator() | where-object {$_.key -notlike "Octopus*" -and $_.key -notlike "env:*"}

UpdateJsonFile `
(ConvertListToHashtable $oParams) `
(Get-Param "JsonFilePath" -Required)
