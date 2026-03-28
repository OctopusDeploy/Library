# Running outside octopus
param(
    [string]$regExports
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

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

# More custom functions would go here

& {
    param(
        [string]$regExports
    ) 

    Write-Host "Registry Export Configuration Variables"
    Write-Host "regExports: $regExports"

    ForEach ($regExp in $regExports.Split(';'))  {
        
        $regFile = $regExp.Trim()
        
        if( $regFile.Length -lt 1 ){ break }

        $output = ""

        $fi=Get-Item $regFile
        $file=$fi.OpenText()

        While(!($file.EndOfStream)){
            $line=$file.ReadLine()
            $outputLine = $line

            if($line -match "`"=`""){
                $keyValue = $line -split "`"=`""
                $key = $keyValue[0] -replace "^`"" , ""
                $oldVal = $keyValue[1] -replace "`"$" , ""
                $newVal = $OctopusParameters[$key]
                
                Write-Host "Looking for key $key in OctopusParameters hash"

                if($newVal){
                    Write-Host "Updating $key from $oldVal to $newVal"
                    $outputLine = "`"$key`"=`"$newVal`""
                }
            }
            
            $output += $outputLine + "`r`n"
        }

        $output | Out-File "c:\temp\output.reg"
    }

 } `
(Get-Param 'regExports' -Required)