try{
    #region Types - Constants
    Add-Type -assembly "system.io.compression.filesystem"
    $shaloMaskString = '********'
    #endregion

    #region Params
    $shaloArtifactPath = $OctopusParameters['shaloArtifactPath']
    Write-Host "     Artifact path: [$shaloArtifactPath]"

    $shaloCollectedArtifactName = $OctopusParameters['shaloCollectedArtifactName']
    Write-Host "     Artifact name: [$shaloCollectedArtifactName]"

    $shaloArtifactTempPath = $OctopusParameters['shaloArtifactTempPath']
    if($shaloArtifactTempPath.Length -eq 0){
        Write-Error "     Artifact Temporal path not set."
        exit 1
    }
    Write-Host "     Artifact Temporal path: [$shaloArtifactTempPath]"

    

    $shaloCompressionLevel = $OctopusParameters['shaloCompressionLevel']
    switch($shaloCompressionLevel) {
        'Optimal' {$shaloCompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal} 
        'Fastest' {$shaloCompressionLevel = [System.IO.Compression.CompressionLevel]::Fastest} 
        'NoCompression' {$shaloCompressionLevel = [System.IO.Compression.CompressionLevel]::NoCompression} 
    }
    Write-Host "     Artifact compresion Level: [$shaloCompressionLevel]"

    $shaloMaskFilers = $OctopusParameters['shaloMaskFilers']
    $shaloMaskKeys = $OctopusParameters['shaloMaskKeys']
    if($shaloMaskFilers.Length -gt 0 -and $shaloMaskKeys.Length -gt 0){
        Write-Host "     Scrub sensitive values from this file extensions : [$shaloMaskFilers]"
        $shaloMaskFilers = $shaloMaskFilers.Split(',')
        $shaloMaskKeys = $shaloMaskKeys.Split(',')
    }
    #endregion

    
    if(Test-Path -Path $shaloArtifactPath){
        Write-Host ''
        #region Create Temporal Artifact
        $shaloArtifactObject = Get-Item $shaloArtifactPath
        try{
        	Write-Host '     Cleaning Artifact Temporal Folder'
            Remove-Item -Path $shaloArtifactTempPath -Force -Recurse
        }catch{
        }
        if($shaloArtifactObject.PSIsContainer){
            Write-Host '     Artifact type: [Directory]'
            Copy-Item -Path $shaloArtifactPath -Destination $shaloArtifactTempPath -Recurse -Force
        }else{
            Write-Host '     Artifact type: [File]'
            New-Item -Path $shaloArtifactTempPath -Force -ItemType Directory
            Copy-Item -Path $shaloArtifactObject.FullName -Destination ($shaloArtifactTempPath + "\" + $shaloArtifactObject.Name) -Force
        }
        Write-Host '     Temporal artifact created'
        #endregion
    
        #region Apply Mask
        Write-Host ''
        Write-Host '     Masking sensitive data'
        if($shaloMaskFilers.Length -gt 0 -and $shaloMaskKeys.Length -gt 0){
            $shaloArtifactTempObjects = Get-ChildItem -Path $shaloArtifactTempPath -Force -Recurse
            foreach($shaloItem in $shaloArtifactTempObjects){
                if($shaloMaskFilers.Trim() -contains $shaloItem.Extension){
                    foreach($ShaloKey in $shaloMaskKeys){
                        (Get-Content $shaloItem.FullName) -replace $ShaloKey.Trim(), $shaloMaskString| Set-Content $shaloItem.FullName
                    }
                }
            }
        }
        #endregion

        #region Compress and Collect
        Write-Host ''
        Write-Host ''
        Write-Host '     Compressing artifact...'
        Write-Host "     Artifact Temporal Path [$shaloArtifactTempPath]"
        Compress-Archive -Path $shaloArtifactTempPath -DestinationPath "$shaloArtifactTempPath\$shaloCollectedArtifactName.zip" -Force -CompressionLevel $shaloCompressionLevel
        Write-Host '     Artifact compressed'
       

        Write-Host ''
        Write-Host ''
        Write-Host '     Collecting artifact...'
        Write-Host "     Artifact Path [$shaloArtifactTempPath\$shaloCollectedArtifactName.zip]"
        $Shalohash = Get-FileHash "$shaloArtifactTempPath\$shaloCollectedArtifactName.zip" -Algorithm MD5 | Select Hash
        Write-Host '     MD5 hash [' $Shalohash.Hash ']'
        New-OctopusArtifact -Path "$shaloArtifactTempPath\$shaloCollectedArtifactName.zip" -Name "$shaloCollectedArtifactName.zip"
        Write-Host '     Artifact Collected'
        
        Write-Host ''
        Write-Host ''
    }else{
        Write-Host ''
        Write-Host ''
        Write-Warning '     Artifact not found!'
    }
    
        Write-Host ''
        Write-Host ''
        Write-Host 'Done!'

}catch{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Error "We failed to processing $FailedItem. The error message was $ErrorMessage"
    exit 1
}