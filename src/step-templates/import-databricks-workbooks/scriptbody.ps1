$ErrorActionPreference = "Stop" #region fucntions
function Set-DatabricksWorkBook
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $AccessToken, 
        [Parameter()]
        [String]
        $DataBricksInstanceUri,
        [Parameter()]
        [String]
        $WorkbooksUploadPath,
        [Parameter()]
        [String]
        $DatabrickImportFolder
    )

    $headers = @{
        'Authorization' = ("Bearer {0}" -f $AccessToken )
    }
    $APIVersion = '/api/2.0'
    $APICommand = '/workspace/import'
    $Uri = "https://$DataBricksInstanceUri$APIVersion$APICommand"
        
    Get-ChildItem -Path $WorkbooksUploadPath -Recurse -File | ForEach-Object{ $currentWorkBook = $_
        Write-Host ("Importing Workbook:{0}" -f $currentWorkBook.FullName)
 		$workbookContent =  [Convert]::ToBase64String((Get-Content -path $currentWorkBook.FullName -Encoding byte))
    
        if($DatabrickImportFolder.EndsWith("/"))
    	{
    		$workbookPath   = "{0}{1}" -f $DatabrickImportFolder , $currentWorkBook.BaseName
    	}
    	else 
    	{
        	$workbookPath   = "{0}/{1}" -f $DatabrickImportFolder , $currentWorkBook.BaseName
    	}
        
        switch ($currentWorkBook.Extension.ToLower()) 
        {
            '.ipynb' { 
                $workbookLanguage = "PYTHON" 
                $workbookFormat   = "JUPYTER"
                break
            }
            '.scala' {
                $workbookLanguage = "SCALA"
                $workbookFormat   = "SOURCE"
                break
        }
        Default 
            {
                $workbookLanguage = "SQL"
                $workbookFormat   = "SOURCE"
            }
        }
        $requestBody = ConvertTo-Json -InputObject @{ 
            content = $workbookContent
            path = $workbookPath
            language = $workbookLanguage
            format = $workbookFormat
            overwrite = $true
            }
        
        $apiResponse = Invoke-RestMethod -Method Post  -Uri  $Uri -Headers $headers -Body $requestBody
        return $apiResponse
    }
}


function Set-DatabricksWorkspaceFolder
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $AccessToken, 
        [Parameter()]
        [String]
        $DataBricksInstanceUri,
        [Parameter()]
        [String]
        $DatabrickFolder
    )

    $headers = @{
        'Authorization' = ("Bearer {0}" -f $AccessToken )
    }
    $APIVersion = '/api/2.0'
    $APIListCommand = '/workspace/list'
    $APIMkdirsCommand = '/workspace/mkdirs'
    $ListUri = "https://$DataBricksInstanceUri$APIVersion$APIListCommand"
    $MkdirsUri = "https://$DataBricksInstanceUri$APIVersion$APIMkdirsCommand"

    $pathRoute = $DatabrickFolder.Substring(1) -split '/'
    $basePath = "/"
    foreach($path in $pathRoute)
    {
        $requestBody = @{ 
            path = $basePath
        }
        $apiResponse = Invoke-RestMethod -Uri $ListUri -Headers $headers -Body $requestBody -ContentType application/json  
        $workSpaceFolder = $apiResponse.objects | Where-Object {$_.object_type -eq "DIRECTORY" -and $_.path -eq ( "{0}{1}" -f $basePath , $path) } 
        if($null -eq $workSpaceFolder)
        {
            $requestBody = ConvertTo-Json -InputObject  @{ 
                path = ( "{0}{1}" -f $basePath , $path)
            } 
            Invoke-RestMethod -Method Post -Uri $MkdirsUri -Headers $headers -Body $requestBody
        }
        $basePath = "{0}/{1}/" -f $basePath , $path
        if($basePath.StartsWith("//"))
        {
            $basePath = $basePath.Substring(1)
        }
    }
}

#endregion fucntions


$DatabrickWorkBookImportFolder = $OctopusParameters["Octopus.Action.Package[DeployDataBricksWorkBookPackage].ExtractedPath"]

Write-Host "Checking WorkSpace Folders"
Set-DatabricksWorkspaceFolder  -AccessToken $DataBricksAccessToken -DataBricksInstanceUri $DataBricksInstanceUri -DatabrickFolder $DatabricksImportFolder
Write-Host "Importing Databricks Workbooks"
Set-DatabricksWorkBook -AccessToken $DataBricksAccessToken -DataBricksInstanceUri $DataBricksInstanceUri -WorkbooksUploadPath $DatabrickWorkBookImportFolder -DatabrickImportFolder $DatabricksImportFolder
