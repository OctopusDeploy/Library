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

& {
	param(
    	[string]$SnowChangeDeploySnowflakeDatabaseName,
    	[string]$SnowChangeDeploySnowflakeWarehouse,
        [string]$SnowChangeDeploySnowflakeDeploymentRole,
        [string]$SnowChangeDeploySnowflakeDeploymentUser,
        [string]$SnowChangeDeploySnowflakeRegion,
        [string]$SnowChangeDeploySnowflakeAccountName,
        [string]$SnowChangeDeploySNOWSQL_PWD,
        [string]$SnowChangeDeployPath
      )

	python --version

# Acquire snowchange.py dependencies
	python.exe -m pip install --upgrade pip
	pip install --upgrade wheel
	pip install --upgrade snowflake-connector-python

# Identify or acquire path to snowchange.py

	if (!$SnowChangeDeployPath) {
      Write-Host "Snowchange path not provided. Downloading from Github."

      $wc = New-Object System.Net.WebClient
      $wc.Encoding = [System.Text.Encoding]::UTF8

      $targetFolder = Join-Path $Env:OctopusCalamariWorkingDirectory 'snowchange'
      $file = "snowchange.py"
      $targetPath = Join-Path $targetFolder $file
      $url = "https://raw.githubusercontent.com/jamesweakley/snowchange/master/$file"

      Write-Host -Message "Attempting to create $targetFolder"
      New-Item -ItemType "directory" -Path "$targetFolder"                
      Write-Host -Message "Attempting to download from $url"
      $wc.DownloadFile("$url", "$targetPath")

		$SnowChangeDeployPath = $targetPath
	}

# Identify path to Scripts for snowchange.py to execute

	$scriptsPath = $OctopusParameters["Octopus.Action.Package[SnowChangeDeploySnowflakeScriptsPackage].ExtractedPath"]

# Set Process-level Environment variable for SNOWSQL_PWD

	$pword = "$SnowChangeDeploySNOWSQL_PWD"
	Set-Item -Path Env:SNOWSQL_PWD -Value $pword

# If a DB was specified, generate the metadata table name

	if ($SnowChangeDeploySnowflakeDatabaseName) {
    	$metadataTable = "$SnowChangeDeploySnowflakeDatabaseName",".SNOWCHANGE.CHANGE_HISTORY" -Join ""
    }

# Invoke snowchange.py

	if ($metadataTable) {
      python $SnowChangeDeployPath `
      -f "$scriptsPath" `
      -a "$SnowChangeDeploySnowflakeAccountName" `
      --snowflake-region "$SnowChangeDeploySnowflakeRegion" `
      -u "$SnowChangeDeploySnowflakeDeploymentUser" `
      -r "$SnowChangeDeploySnowflakeDeploymentRole" `
      -w "$SnowChangeDeploySnowflakeWarehouse" `
      -c "$metadataTable"
    } else {
      python $SnowChangeDeployPath `
      -f "$scriptsPath" `
      -a "$SnowChangeDeploySnowflakeAccountName" `
      --snowflake-region "$SnowChangeDeploySnowflakeRegion" `
      -u "$SnowChangeDeploySnowflakeDeploymentUser" `
      -r "$SnowChangeDeploySnowflakeDeploymentRole" `
      -w "$SnowChangeDeploySnowflakeWarehouse"    
    }
} `
(Get-Param 'SnowChangeDeploySnowflakeDatabaseName') `
(Get-Param 'SnowChangeDeploySnowflakeWarehouse' -Required) `
(Get-Param 'SnowChangeDeploySnowflakeDeploymentRole' -Required) `
(Get-Param 'SnowChangeDeploySnowflakeDeploymentUser' -Required) `
(Get-Param 'SnowChangeDeploySnowflakeRegion' -Required) `
(Get-Param 'SnowChangeDeploySnowflakeAccountName' -Required) `
(Get-Param 'SnowChangeDeploySNOWSQL_PWD' -Required) `
(Get-Param 'SnowChangeDeployPath')
