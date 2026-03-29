# Configure template

# Check to see if $IsWindows is available
if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Set TLS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

# Downloads and extracts liquibase to the work folder
Function Get-Liquibase {
    # Define parameters
    param ($Version) 

    $repositoryName = "liquibase/liquibase"

    # Check to see if version wasn't specified
    if ([string]::IsNullOrEmpty($Version)) {
        # Get the latest version download url
        $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object { $_.EndsWith(".zip") })
    }
    else {
        $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version $Version | Where-Object { $_.EndsWith(".zip") })
    }

    # Extract the downloaded file
    Expand-DownloadedFile -DownloadUrls $downloadUrl | Out-Null
    
    # Parse downloaded version
    if ($downloadUrl -is [array]) {
        $downloadedFileName = [System.IO.Path]::GetFileName($downloadUrl[0])
    }
    else {
        $downloadedFileName = [System.IO.Path]::GetFileName($downloadUrl)
    }

    # Return the downloaded version
    return $downloadedFileName.SubString($downloadedFileName.IndexOf("-") + 1).Replace(".zip", "")    
}

# Downloads the files
Function Expand-DownloadedFile {
    # Define parameters
    param (
        $DownloadUrls
    )
    
    # Loop through results
    foreach ($url in $DownloadUrls) {
        # Download the zip file
        $folderName = [System.IO.Path]::GetFileName("$PSScriptroot/$($url.Substring($url.LastIndexOf("/")))").Replace(".zip", "")
        $zipFile = "$PSScriptroot/$folderName/$($url.Substring($url.LastIndexOf("/")))"
        Write-Host "Downloading $zipFile from $url ..."
        
        if ((Test-Path -Path "$PSScriptroot/$folderName") -eq $false) {
            # Create folder
            New-Item -Path "$PSScriptroot/$folderName/" -ItemType Directory
        }

        # Download the zip file
        Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing | Out-Null

        # Extract package
        Write-Host "Extracting $zipFile ..."
        Expand-Archive -Path $zipFile -DestinationPath "$PSSCriptRoot/$folderName" | Out-Null
    }
}


# Downloads and extracts Java to the work folder, then adds the location of java.exe to the $env:PATH variabble so it can be called
Function Get-Java {
    # Check to see if a folder needs to be created
    if ((Test-Path -Path "$PSScriptRoot/jdk") -eq $false) {
        # Create new folder
        New-Item -ItemType Directory -Path "$PSSCriptRoot/jdk"
    }

    # Download java
    Write-Output "Downloading Java ... "
    
    # Determine OS
    if ($IsWindows) {
        Invoke-WebRequest -Uri "https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip" -OutFile "$PSScriptroot/jdk/openjdk-21.0.2_windows-x64_bin.zip" -UseBasicParsing

        # Extract
        Write-Output "Extracting Java ... "
        Expand-Archive -Path "$PSScriptroot\jdk\openjdk-21.0.2_windows-x64_bin.zip" -DestinationPath "$PSSCriptRoot/jdk"

        # Get Java executable
        $javaExecutable = Get-ChildItem -Path "$PSScriptRoot\jdk" -Recurse | Where-Object { $_.Name -eq "java.exe" }
    }
    
    if ($IsLinux) {
        Invoke-WebRequest -Uri "https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-x64_bin.tar.gz" -OutFile "$PSScriptroot/jdk/openjdk-21.0.2_linux-x64_bin.tar.gz" -UseBasicParsing

        # Extract
        Write-Output "Extracting Java ... "
        tar -xvzf "$PSScriptroot/jdk/openjdk-21.0.2_linux-x64_bin.tar.gz" --directory "$PSScriptRoot/jdk"

        # Get Java executable
        $javaExecutable = Get-ChildItem -Path "$PSScriptRoot/jdk" -Recurse | Where-Object { $_.Name -eq "java" }   
    }
    
    # Add path to current session as first entry to bypass other versions of Java that may be installed.
    $env:PATH = "$($javaExecutable.Directory)$([IO.Path]::PathSeparator)" + $env:PATH
    
}

Function Get-DriverAssets {
    # Define parameters
    param (
        $DownloadInfo
    )

    # Declare working variables
    $assetFilePath = ""

    # Check to see if there are multiple assets to download
    if ($DownloadInfo -is [array]) {
        # Declare local variables
        $assetFiles = @()

        # Loop through array
        foreach ($url in $DownloadInfo) {
            # Download the asset
            Write-Host "Downloading asset from $url..."
            $assetPath = "$PSScriptroot/$($url.Substring($url.LastIndexOf("/")))"
            
            # Skip test assets
            if ($assetPath.EndsWith("tests.jar")) {
                Write-Host "Asset is for testing, skipping ..."
                continue
            }
            
            Invoke-WebRequest -Uri $url -Outfile $assetPath -UseBasicParsing
            $assetFiles += $assetPath
        }

        # Assign paths
        $assetFilePath = $assetFiles -join "$([IO.Path]::PathSeparator)"
    }
    else {
        # Download asset
        Write-Host "Downloading asset from $DownloadInfo ..."
        $assetFilePath = "$PSScriptroot/$($DownloadInfo.Substring($DownloadInfo.LastIndexOf("/")))"
        Invoke-WebRequest -Uri $DownloadInfo -Outfile $assetFilePath -UseBasicParsing
    }

    # Return path
    return $assetFilePath
}

# Gets download url of latest release with an asset
Function Get-LatestVersionDownloadUrl {
    # Define parameters
    param(
        $Repository,
        $Version
    )
    
    # Define local variables
    $releases = "https://api.github.com/repos/$Repository/releases"
    
    # Get latest version
    Write-Host "Determining latest release of $Repository ..."
    
    $tags = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)
    
    if ($null -ne $Version) {
        # Get specific version
        $tags = ($tags | Where-Object { $_.name.EndsWith($Version) })

        # Check to see if nothing was returned
        if ($null -eq $tags) {
            # Not found
            Write-Host "No release found matching version $Version, getting highest version using Major.Minor syntax..."

            # Get the tags
            $tags = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)

            # Parse the version number into a version object
            $parsedVersion = [System.Version]::Parse($Version)
            $partialVersion = "$($parsedVersion.Major).$($parsedVersion.Minor)"
            
            # Filter tags to ones matching only Major.Minor of version specified
            $tags = ($tags | Where-Object { $_.name.Contains("$partialVersion.") -and $_.draft -eq $false })
            
            # Grab the latest
            if ($null -eq $tags)
            {
            	# decrement minor version
                $minorVersion = [int]$parsedVersion.Minor
                $minorVersion --
                
                # return the urls
                return (Get-LatestVersionDownloadUrl -Repository $Repository -Version "$($parsedVersion.Major).$($minorVersion)")
            }
        }
    }

    # Find the latest version with a downloadable asset
    foreach ($tag in $tags) {
        if ($tag.assets.Count -gt 0) {
            return $tag.assets.browser_download_url
        }
    }

    # Return the version
    return $null
}

# Finds the specified changelog file
Function Get-ChangeLog {
    # Define parameters
    param ($FileName)
    
    # Find file
    $fileReference = (Get-ChildItem -Path $OctopusParameters["Octopus.Action.Package[liquibaseChangeSet].ExtractedPath"] -Recurse | Where-Object { $_.Name -eq $FileName })

    # Check to see if something weas returned
    if ($null -eq $fileReference) {
        # Not found
        Write-Error "$FileName was not found in $PSScriptRoot or subfolders."
    }

    # Return the reference
    return $fileReference
}

# Downloads the appropriate JDBC driver
Function Get-DatabaseJar {
    # Define parameters
    param ($DatabaseType)

    # Declare local variables
    $driverPath = ""

    # Check to see if a folder needs to be created
    if ((Test-Path -Path "$PSScriptRoot/DatabaseDriver") -eq $false) {
        # Create new folder
        New-Item -ItemType Directory -Path "$PSSCriptRoot/DatabaseDriver" | Out-Null
    }

    # Download the driver for the selected type
    switch ($DatabaseType) {
        "Cassandra" {

			# Get the release download
            Write-Host "Downloading Cassandra JDBC driver bundle ..."
			$downloadUrl = Get-LatestVersionDownloadUrl -Repository "ing-bank/cassandra-jdbc-wrapper"
           
            # Find driver
            $driverPath = (Get-DriverAssets -DownloadInfo $downloadUrl)

            # Set repo name
            $repositoryName = "liquibase/liquibase-cassandra"
            
            if ([string]::IsNullOrEmpty($liquibaseVersion)) {
                # Get the latest version for the extension
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object { $_.EndsWith(".jar") })
           	}
            else {
                # Download version matching extension
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version $liquibaseVersion | Where-Object { $_.EndsWith(".jar") })
            }           

            $extensionPath = Get-DriverAssets -DownloadInfo $downloadUrl
            
            # Make driver path null
            $driverPath = "$driverPath$([IO.Path]::PathSeparator)$extensionPath"

            break
        }
        "CosmosDB"
        {
			# Download the (long) list of dependencies
            $driverPaths = @()

			# Set repo name
            $repositoryName = "liquibase/liquibase-cosmosdb"

			if ([string]::IsNullOrEmpty($liquibaseVersion))
            {
            	# Get the latest version for the extension
            	$downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object {$_.EndsWith(".jar")})
           	}
            else
            {
            	# Download version matching extension
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version $liquibaseVersion | Where-Object {$_.EndsWith(".jar")})
            }    
            
            $extensionPath = Get-DriverAssets -DownloadInfo $downloadUrl
                     
			# Add to driver path
            $driverPaths += $extensionPath
            
            Write-Host "Downloading azure-cosmos driver ..."
            $driverVersion = "4.28.0"
            $filePath = "$PSScriptroot/DatabaseDriver/azure-cosmos-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/azure/azure-cosmos/$driverVersion/azure-cosmos-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            # Add to driver path
            $driverPaths += $filePath
            
            Write-Host "Downloading azure-core driver ..."
            $driverVersion = "1.27.0"
            $filePath = "$PSScriptroot/DatabaseDriver/azure-core-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/azure/azure-core/$driverVersion/azure-core-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            $files = Get-ChildItem -Path "$PSScriptRoot/DatabaseDriver"
            
            Write-Host "There are these $files"


            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading jackson core driver ..."
            $driverVersion = "2.13.2"
            $filePath = "$PSScriptroot/DatabaseDriver/jackson-core-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/$driverVersion/jackson-core-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading slf4j core driver ..."
            $driverVersion = "1.7.36"
            $filePath = "$PSScriptroot/DatabaseDriver/slf4j-api-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/$driverVersion/slf4j-api-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty buffer driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-buffer-$driverVersion.final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-buffer/$driverVersion.Final/netty-buffer-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath
			
            Write-Host "Downloading reactor-core driver ..."
            $driverVersion = "3.4.16"
            $filePath = "$PSScriptroot/DatabaseDriver/reactor-core-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/projectreactor/reactor-core/$driverVersion/reactor-core-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading reactor-netty-core driver ..."
            $driverVersion = "1.0.17"
            $filePath = "$PSScriptroot/DatabaseDriver/reactor-core-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/projectreactor/netty/reactor-netty-core/$driverVersion/reactor-netty-core-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading reactor-netty-core driver ..."
            $driverVersion = "1.0.17"
            $filePath = "$PSScriptroot/DatabaseDriver/reactor-netty-http-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/projectreactor/netty/reactor-netty-http/$driverVersion/reactor-netty-http-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-resolver driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-resolver-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-resolver/$driverVersion.Final/netty-resolver-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing  | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-transport driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-transport-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-transport/$driverVersion.Final/netty-transport-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing  | Out-Null
            
            
            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading reactivestreams driver ..."
            $driverVersion = "1.0.3"
            $filePath = "$PSScriptroot/DatabaseDriver/reactive-streams-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/reactivestreams/reactive-streams/$driverVersion/reactive-streams-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading jackson-databind driver ..."
            $driverVersion = "2.13.2.1"
            $filePath = "$PSScriptroot/DatabaseDriver/jackson-databind-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/$driverVersion/jackson-databind-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading jackson-annotations driver ..."
            $driverVersion = "2.13.2"
            $filePath = "$PSScriptroot/DatabaseDriver/jackson-annotations-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/$driverVersion/jackson-annotations-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath
            
            Write-Host "Downloading jackson-module-afterburner driver ..."
            $driverVersion = "2.13.2"
            $filePath = "$PSScriptroot/DatabaseDriver/jackson-module-afterburner-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/fasterxml/jackson/module/jackson-module-afterburner/$driverVersion/jackson-module-afterburner-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading reactor-netty driver ..."
            $driverVersion = "1.0.17"
            $filePath = "$PSScriptroot/DatabaseDriver/reactor-netty-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/projectreactor/netty/reactor-netty/$driverVersion/reactor-netty-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-transport-native-unix-common driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-transport-native-unix-common-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-transport-native-unix-common/$driverVersion.Final/netty-transport-native-unix-common-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-transport-native-epoll driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-transport-native-epoll-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-transport-native-epoll/$driverVersion.Final/netty-transport-native-epoll-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-tcnative-boringssl-static driver ..."
            $driverVersion = "2.0.51"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-tcnative-boringssl-static-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-tcnative-boringssl-static/$driverVersion.Final/netty-tcnative-boringssl-static-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-resolver-dns driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-resolver-dns-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-resolver-dns/$driverVersion.Final/netty-resolver-dns-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-handler-proxy driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-handler-proxy-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-handler-proxy/$driverVersion.Final/netty-handler-proxy-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-handler driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-handler-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-handler/$driverVersion.Final/netty-handler-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-common driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-common-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-common/$driverVersion.Final/netty-common-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-codec-socks driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-codec-socks-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-codec-socks/$driverVersion.Final/netty-codec-socks-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-codec-http driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-codec-http-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-codec-http/$driverVersion.Final/netty-codec-http-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-codec-http2 driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-codec-http2-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-codec-http2/$driverVersion.Final/netty-codec-http2-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-codec-dns driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-codec-dns-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-codec-dns/$driverVersion.Final/netty-codec-dns-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-codec driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-codec-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-codec/$driverVersion.Final/netty-codec-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading micrometer-core driver ..."
            $driverVersion = "1.8.4"
            $filePath = "$PSScriptroot/DatabaseDriver/micrometer-core-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/micrometer/micrometer-core/$driverVersion/micrometer-core-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading metrics-core driver ..."
            $driverVersion = "4.2.9"
            $filePath = "$PSScriptroot/DatabaseDriver/metrics-core-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/dropwizard/metrics/metrics-core/$driverVersion/metrics-core-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading LatencyUtils driver ..."
            $driverVersion = "2.0.3"
            $filePath = "$PSScriptroot/DatabaseDriver/LatencyUtils-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/latencyutils/LatencyUtils/$driverVersion/LatencyUtils-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading jackson-datatype-jsr310 driver ..."
            $driverVersion = "2.12.5"
            $filePath = "$PSScriptroot/DatabaseDriver/jackson-datatype-jsr310-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/fasterxml/jackson/datatype/jackson-datatype-jsr310/$driverVersion/jackson-datatype-jsr310-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-tcnative-classes driver ..."
            $driverVersion = "2.0.51"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-tcnative-classes-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-tcnative-classes/$driverVersion.Final/netty-tcnative-classes-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-transport-classes-kqueue driver ..."
            $driverVersion = "4.1.73"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-transport-classes-kqueue-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-transport-classes-kqueue/$driverVersion.Final/netty-transport-classes-kqueue-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading slf4j-simple driver ..."
            $driverVersion = "1.7.36"
            $filePath = "$PSScriptroot/DatabaseDriver/slf4j-simple-$driverVersion.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/$driverVersion/slf4j-simple-$driverVersion.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-transport-classes-epoll driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-transport-classes-epoll-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-transport-classes-epoll/$driverVersion.Final/netty-transport-classes-epoll-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

            Write-Host "Downloading netty-transport-native-kqueue driver ..."
            $driverVersion = "4.1.75"
            $filePath = "$PSScriptroot/DatabaseDriver/netty-transport-native-kqueue-$driverVersion.Final.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/io/netty/netty-transport-native-kqueue/$driverVersion.Final/netty-transport-native-kqueue-$driverVersion.Final.jar" -Outfile $filePath -UseBasicParsing | Out-Null
            

            # Add to driver path
            $driverPaths += $filePath

			# Return driver list separated by system specific PathSeparator
            $driverPath = ($driverPaths -join [IO.Path]::PathSeparator)
            
            $files = Get-ChildItem -Path "$PSScriptRoot/DatabaseDriver"
            
            #Write-Host "There are these $files"
            
       		break
        }        
        "DB2" {
            # Use built-in driver
            $driverPath = $null
            break
        }
        "MariaDB" {
            # Download MariaDB driver
            Write-Host "Downloading MariaDB driver ..."
            $driverPath = "$PSScriptroot/DatabaseDriver/mariadb-java-client-3.5.7.jar"
            Invoke-WebRequest -Uri "https://dlm.mariadb.com/4550269/Connectors/java/connector-java-3.5.7/mariadb-java-client-3.5.7.jar" -OutFile $driverPath -UseBasicParsing
             
            break
        }
        "MongoDB" {
            # Download MongoDB driver
            Write-Host "Downloading Maven MongoDB driver ..."
            $driverPath = "$PSScriptroot/DatabaseDriver/mongo-java-driver-3.12.7.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/mongodb/mongo-java-driver/3.12.7/mongo-java-driver-3.12.7.jar" -Outfile $driverPath -UseBasicParsing
            
            # Check to see if they are using a licenced version
            if (![string]::IsNullOrWhitespace($liquibaseProLicenseKey)) {
                # Set the paid version url
                $mongoVersions = Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/liquibase/ext/liquibase-commercial-mongodb" -UseBasicParsing
                
                # Loop through links, look for ones that evaluate to version
                $versions = @()
                foreach ($link in $mongoVersions.Links) {
                    Write-Verbose "Evaluating: $link"
                    if (![string]::IsNullOrWhitespace($link.title)) {
                        # Get the inner text
                        $versionNumber = $link.title.Replace("/", "")

                        # Check to see if $versionNumber can be parsed as a versionNumber
                        $versionOut = $null
                        if ([System.Version]::TryParse($versionNumber, [ref]$versionOut)) {
                            $versions += $versionOut
                        }
                    }
                }

                # Get the highest version number
                $info = ($versions | Measure-Object -Maximum)

                $downloadUrl = "https://repo1.maven.org/maven2/org/liquibase/ext/liquibase-commercial-mongodb/$($info.Maximum)/liquibase-commercial-mongodb-$($info.Maximum).jar"                
            }
            else {
                # Set repo name
                $repositoryName = "liquibase/liquibase-mongodb"            
                
                # Download latest OSS version
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object { $_.EndsWith(".jar") })
            }
                        
            $extensionPath = Get-DriverAssets -DownloadInfo $downloadUrl
            
            # Make driver path null
            $driverPath = "$driverPath$([IO.Path]::PathSeparator)$extensionPath"
            
            break
        }
        "MySQL" {
            # Download MariaDB driver
            Write-Host "Downloading MySQL driver ..."
            Invoke-WebRequest -Uri "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.28.zip" -OutFile "$PSScriptroot/DatabaseDriver/mysql-connector-java-8.0.28.zip" -UseBasicParsing -UserAgent "curl/7.8.3.1"

            # Extract package
            Write-Host "Extracting MySQL driver ..."
            Expand-Archive -Path "$PSScriptroot/DatabaseDriver/mysql-connector-java-8.0.28.zip" -DestinationPath "$PSSCriptRoot/DatabaseDriver"

            # Find driver
            $driverPath = (Get-ChildItem -Path "$PSScriptRoot/DatabaseDriver" -Recurse | Where-Object { $_.Name -eq "mysql-connector-java-8.0.28.jar" }).FullName

            break
        }
        "Oracle" {
            # Download Oracle driver
            Write-Host "Downloading Oracle driver ..."
            $driverPath = "$PSScriptroot/DatabaseDriver/ojdbc10.jar"
            Invoke-WebRequest -Uri "https://download.oracle.com/otn-pub/otn_software/jdbc/211/ojdbc11.jar" -OutFile $driverPath -UseBasicParsing

            break
        }
        "SqlAnywhere" {
            Write-Host "Downloading jTds driver ..."
            
            $downloadUrl = (Get-LatestVersionDownloadUrl -Repository "milesibastos/jTDS" | Where-Object {$_.Contains("-dist")})
            Invoke-WebRequest -Uri $downloadUrl -OutFile "$PSScriptroot/DatabaseDriver/jtds.zip" -UseBasicParsing

            # Extract package
            Write-Host "Extracting jTds driver ..."
            Expand-Archive -Path "$PSScriptroot/DatabaseDriver/jtds.zip" -DestinationPath "$PSScriptRoot/DatabaseDriver"

            # Find driver
            $driverPath = (Get-ChildItem -Path "$PSScriptRoot/DatabaseDriver" -Recurse | Where-Object {$_.Name -like "jtds-*.jar"}).FullName

            break
        }
        "SqlServer" {
            # Download Microsoft driver
            Write-Host "Downloading Sql Server driver ..."
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2186163" -OutFile "$PSScriptroot/DatabaseDriver/sqljdbc_10.2.0.0_enu.zip" -UseBasicParsing

            # Extract package
            Write-Host "Extracting SqlServer driver ..."
            Expand-Archive -Path "$PSScriptroot/DatabaseDriver/sqljdbc_10.2.0.0_enu.zip" -DestinationPath "$PSSCriptRoot/DatabaseDriver"

            # Find driver
            $driverPath = (Get-ChildItem -Path "$PSSCriptRoot/DatabaseDriver" -Recurse | Where-Object { $_.Name -eq "mssql-jdbc-10.2.0.jre11.jar" }).FullName
            
            # Determine architecture
            if ([System.Environment]::Is64BitOperatingSystem) {
                # Locate auth dll
                $authDll = Get-ChildItem -Path "$PSScriptRoot/DatabaseDriver" -Recurse | Where-Object { $_.Name -eq "mssql-jdbc_auth-10.2.0.x64.dll" }
            }
            else {
                $authDll = Get-ChildItem -Path "$PSScriptRoot/DatabaseDriver" -Recurse | Where-Object { $_.Name -eq "mssql-jdbc_auth-10.2.0.x86.dll" }
            }
            
            # Add the dll to the path so it can find it.
            $env:PATH += "$([IO.Path]::PathSeparator)$($authDll.Directory)"
            
            break
        }
        "PostgreSQL" {
            # Download PostgreSQL driver
            Write-Host "Downloading PostgreSQL driver ..."
            $driverPath = "$PSScriptroot/DatabaseDriver/postgresql-42.2.12.jar"
            Invoke-WebRequest -Uri "https://jdbc.postgresql.org/download/postgresql-42.2.12.jar" -OutFile $driverPath -UseBasicParsing
            
            # Download the WAFFLE jna driver for Windows Authentication
            $repositoryName = "waffle/waffle"
            
            # Latest version of Waffle (2.3.0) doesn't seem to work, can't find sspi method, specify version 1.9.0
            $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version "1.9.0" | Where-Object { $_.EndsWith(".zip") })
            Expand-DownloadedFile -DownloadUrls $downloadUrl | Out-Null
            
            # Get all waffle jars
            $waffleFolder = (Get-ChildItem -Path "$PSScriptroot" -Recurse | Where-Object { $_.PSIsContainer -and $_.Name -like "Waffle*" })           
            $waffleJars = (Get-ChildItem -Path $waffleFolder.FullName -Recurse | Where-Object { $_.Extension -eq ".jar" })
            
            foreach ($jar in $waffleJars) {
                $driverPath += "$([IO.Path]::PathSeparator)$($jar.FullName)"
            }


            break
        }
        "Snowflake" {
            # Set repo name
            $repositoryName = "liquibase/liquibase-snowflake"

            # Download Snowflake driver
            Write-Host "Downloading Snowflake driver ..."
            $driverPath = "$PSScriptroot/DatabaseDriver/snowflake-jdbc-3.9.2.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/3.9.2/snowflake-jdbc-3.9.2.jar" -OutFile $driverPath -UseBasicParsing

            if ([string]::IsNullOrEmpty($liquibaseVersion)) {
                # Get the latest version for the extension
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object { $_.EndsWith(".jar") })
           	}
            else {
                # Download version matching extension
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version $liquibaseVersion | Where-Object { $_.EndsWith(".jar") })
            }
                        
            $extensionPath = Get-DriverAssets -DownloadInfo $downloadUrl
            
            # Make driver path null
            $driverPath = "$driverPath$([IO.Path]::PathSeparator)$extensionPath"


            break
        }
        default {
            # Display error
            Write-Error "Unknown database type: $DatabaseType."
        }
    }

    # Return the driver location
    return $driverPath
}

# Returns the connection string formatted for the database type
Function Get-ConnectionUrl {
    # Define parameters
    param ($DatabaseType, 
        $ServerPort, 
        $ServerName, 
        $DatabaseName, 
        $QueryStringParameters)

    # Define local variables
    $connectionUrl = ""

    # Download the driver for the selected type
    switch ($DatabaseType) {
        "Cassandra" {
            #$connectionUrl = "jdbc:cassandra://{0}:{1};DefaultKeyspace={2}"
            $connectionUrl = "jdbc:cassandra://{0}:{1}/{2}"
            break
        }
        "CosmosDB"
        {
            $connectionUrl = "cosmosdb://{0}:$($liquibasePassword)@{0}:{1}/{2}" 
            break
        }        
        "DB2" {
            $connectionUrl = "jdbc:db2://{0}:{1}/{2}"
            break
        }
        "MariaDB" {
            $connectionUrl = "jdbc:mariadb://{0}:{1}/{2}"
            
            # Check for Windows Authentication type
            if ($liquibaseAuthenticationMethod -eq "windowsauthentication") {
                # Add querysting parameter
                $connectionUrl += "?integratedSecurity=true"
            }
            
            break
        }
        "MongoDB" {        
            $connectionUrl = "mongodb://{0}:{1}/{2}"            
            break
        }
        "MySQL" {
        
            $connectionUrl = "jdbc:mysql://{0}:{1}/{2}"
            
            # Check for Windows Authentication type
            if ($liquibaseAuthenticationMethod -eq "windowsauthentication") {
                # Add querysting parameter
                $connectionUrl += "?integratedSecurity=true"
            }
            
            break
        }
        "Oracle" {
            $connectionUrl = "jdbc:oracle:thin:@{0}:{1}/{2}"
            break
        }
        "SqlAnywhere" {
            $connectionUrl = "jdbc:jtds:sybase://{0}:{1}/{2}"
            break
        }
        "SqlServer" {
            $connectionUrl = "jdbc:sqlserver://{0}:{1};database={2};"
            
            switch ($liquibaseAuthenticationMethod) {
                "azuremanagedidentity" {
                    # Add querystring parameter
                    $connectionUrl += "Authentication=ActiveDirectoryMSI;"
                    break
                }
                "windowsauthentication" {
                    # Add querysting parameter
                    $connectionUrl += "integratedSecurity=true;"
                	
                    break
                }
            }
            
            break
        }
        "PostgreSQL" {
            $connectionUrl = "jdbc:postgresql://{0}:{1}/{2}"
            
            # Check for Windows Authentication type
            if ($liquibaseAuthenticationMethod -eq "windowsauthentication") {
                # Add querysting parameter
                $connectionUrl += "?gsslib=sspi"
            }
            
            break
        }
        "Snowflake" {
            $connectionUrl = "jdbc:snowflake://{0}.snowflakecomputing.com?db={2}"
            break
        }
        default {
            # Display error
            Write-Error "Unkonwn database type: $DatabaseType."
        }
    }

    if (![string]::IsNullOrWhitespace($QueryStringParameters)) {       	
        if ($connectionUrl.Contains("?")) {
           	# Replace the ? with & in connection string parameters
            $QueryStringParameters = $QueryStringParameters.Replace("?", "&")
        }
        
        # Appen connecion string
        $connectionUrl += "$QueryStringParameters"
    }

    # Return the url
    return ($connectionUrl -f $ServerName, $ServerPort, $DatabaseName)
}

# Create array for arguments
$liquibaseArguments = @()

# Check to see if it's running on Windows
if ($IsWindows) {
    # Disable the progress bar so downloading files via Invoke-WebRequest are faster
    $ProgressPreference = 'SilentlyContinue'
}

# Check for license key
if (![string]::IsNullOrWhitespace($liquibaseProLicenseKey)) {
    # Add key to arguments
    $liquibaseArguments += "--liquibaseProLicenseKey=$liquibaseProLicenseKey"
}

# Find Change log
$changeLogFile = (Get-ChangeLog -FileName $liquibaseChangeLogFileName)
$liquibaseArguments += "--changeLogFile=$($changeLogFile.Name)"

# Set the location to where the file is
Set-Location -Path $changeLogFile.Directory

# Check to see if it needs to be downloaed to machine
if ($liquibaseDownload -eq $true) {
    # Download and extract liquibase - get the version for extensions that are version specific
    $liquibaseVersion = Get-Liquibase -Version $liquibaseVersion -DownloadFolder $workingFolder

    # Download and extract java and add it to PATH environment variable
    Get-Java
}
else {
    if (![string]::IsNullOrEmpty($liquibaseClassPath)) {
        $liquibaseArguments += "--classpath=$liquibaseClassPath"
    }
}

# Check to see if liquibase path has been defined
if ([string]::IsNullOrWhitespace($liquibaseExecutablePath)) {

	if ($env:IsContainer)
    {
    	$liquibaseExecutablePath = "/"	
    }
    else
    {
    	# Assign root
    	$liquibaseExecutablePath = $PSSCriptRoot
    }
}

# Get the executable location
if ($IsWindows) {
    $liquibaseExecutable = Get-ChildItem -Path $liquibaseExecutablePath -Recurse | Where-Object { $_.Name -eq "liquibase.bat" }
}

if ($IsLinux) {
    $liquibaseExecutable = Get-ChildItem -Path $liquibaseExecutablePath -Recurse | Where-Object { $_.Name -eq "liquibase" }
}

# Add path to current session
$env:PATH += "$([IO.Path]::PathSeparator)$($liquibaseExecutable.Directory)"

# Check to make sure it was found
if ([string]::IsNullOrEmpty($liquibaseExecutable)) {
    # Could not find the executable
    Write-Error "Unable to find liquibase.bat in $PSScriptRoot or subfolders."
}

# Get connection Url
$connectionUrl = Get-ConnectionUrl -DatabaseType $liquibaseDatabaseType -ServerPort $liquibaseServerPort -ServerName $liquibaseServerName -DatabaseName $liquibaseDatabaseName -QueryStringParameters $liquibaseQueryStringParameters

# Add username
$liquibaseArguments += "--username=$liquibaseUsername"

# Determine authentication method
switch ($liquibaseAuthenticationMethod) {
    "azuremanagedidentity" {
        # SQL Server driver doesn't assign password
        if ($liquibaseDatabaseType -ne "SqlServer") {
            # Get login token
            Write-Host "Generating Azure Managed Identity token ..."
            $token = Invoke-RestMethod -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://ossrdbms-aad.database.windows.net" -Headers @{"MetaData" = "true" } -UseBasicParsing

            $liquibasePassword = $token.access_token
            $liquibaseArguments += "--password=`"$liquibasePassword`""
        }
    }
    "awsiam" {
        # Region is part of the RDS endpoint, extract
        $region = ($liquibaseServerName.Split("."))[2]

        Write-Host "Generating AWS IAM token ..."
        $liquibasePassword = (aws rds generate-db-auth-token --hostname $liquibaseServerName --region $region --port $liquibaseServerPort --username $liquibaseUsername)
        $liquibaseArguments += "--password=`"$liquibasePassword`""

        break
    }
    "gcpserviceaccount" {
        # Define header
        $header = @{ "Metadata-Flavor" = "Google" }

        # Retrieve service accounts
        $serviceAccounts = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" -Headers $header -UseBasicParsing

        # Results returned in plain text format, get into array and remove empty entries
        $serviceAccounts = $serviceAccounts.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

        # Retreive the specific service account assigned to the VM
        $serviceAccount = $serviceAccounts | Where-Object { $_.Contains("iam.gserviceaccount.com") }

        Write-Host "Generating GCP IAM token ..."
        # Retrieve token for account
        $token = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/$serviceAccount/token" -Headers $header -UseBasicParsing
        
        $liquibasePassword = $token.access_token
        $liquibaseArguments += "--password=`"$liquibasePassword`""
    }
    "usernamepassword" {
        # Add password
        $liquibaseArguments += "--password=`"$liquibasePassword`""
        
        break
    }
}

# Add connection url
$liquibaseArguments += "--url=`"$connectionUrl`""

# Determine if the output variable needs to be set
if ($liquibaseCommand.EndsWith("SQL")) {
    # Add the output variable as the command name
    $liquibaseArguments += "--outputFile=`"$PSScriptRoot/artifacts/$($liquibaseCommand).sql`""
    
    # Create the folder
    if ((Test-Path -Path "$PSScriptRoot/artifacts") -eq $false) {
        New-Item -Path "$PSScriptRoot/artifacts" -ItemType "Directory"
    }
}


# Add the additional switches
foreach ($liquibaseSwitch in $liquibaseAdditionalSwitches) {
    $liquibaseArguments += $liquibaseSwitch
}

switch ($liquibaseCommandStyle) {
    "legacy" {
        # Add the command to execute
        $liquibaseArguments += $liquibaseCommand
    }
    "modern" {
        # Insert the command at the beginning
        $liquibaseArguments = @($liquibaseCommand) + $liquibaseArguments
    }
}

# Add command arguments
$liquibaseArguments += $liquibaseCommandArguments

# Display what's going to be run
if (![string]::IsNullOrWhitespace($liquibasePassword)) {
    $liquibaseDisplayArguments = $liquibaseArguments.PSObject.Copy()
    for ($i = 0; $i -lt $liquibaseDisplayArguments.Count; $i++) {
        if ($null -ne $liquibaseDisplayArguments[$i]) {
            if ($liquibaseDisplayArguments[$i].Contains($liquibasePassword)) {
                $liquibaseDisplayArguments[$i] = $liquibaseDisplayArguments[$i].Replace($liquibasePassword, "****")
            }
        }
    }
    
    Write-Host "Executing the following command: $($liquibaseExecutable.FullName) $liquibaseDisplayArguments"
}
else {
    Write-Host "Executing the following command: $($liquibaseExecutable.FullName) $liquibaseArguments"
}

# Check to see if the user has specified the drivers need to be downloaded
if ($liquibaseDownloadDatabaseDriver -eq $true)
{
	# Download any additional drivers based on the database technology being deployed to
    $driverPath = Get-DatabaseJar -DatabaseType $liquibaseDatabaseType

    # Check to see if it's null
    if ($null -ne $driverPath) {
        # Create folder to hold jar files to override
        New-Item -Path "$PWD/liquibase_libs/" -ItemType Directory    

        # Copy contents into liquibase_libs folder
        $driverPaths = $driverPath.Split([IO.Path]::PathSeparator)

        foreach ($driver in $driverPaths) {
            # Copy the items
            $files = Get-ChildItem -Path $driver

            foreach ($file in $files) {
                Write-Host "Copying $($file.FullName) to $PWD/liquibase_libs/$($file.Name)"
                Copy-Item -Path $file.FullName -Destination "$PWD/liquibase_libs/$($file.Name)"
            }
            
        }

    }
}



# Declare variable to hold output from Tee-Object
$liquibaseCommandOutput;

# Redirection of stderr to stdout is done different on Windows versus Linux
if ($IsWindows) {
    # Batch file uses a find command which is located in c:\windows\system32 and not included in regular PowerShell sessions
    $env:PATH = $env:PATH + ";c:\windows\system32"
    $liquibaseArguments += "2>&1"
    # Execute Liquibase
    & $liquibaseExecutable.FullName $liquibaseArguments | Tee-Object -Variable liquibaseCommandOutput
}

if ($IsLinux) {
    # Execute Liquibase
    & $liquibaseExecutable.FullName $liquibaseArguments 2>&1 | Tee-Object -Variable liquibaseCommandOutput
}

Set-OctopusVariable -name "LiquibaseCommandOutput" -value $liquibaseCommandOutput

# Check exit code
if ($lastExitCode -ne 0) {
    # Fail the step
    Write-Error "Execution of Liquibase failed!"
}

# Check to see if there were any files output
if ((Test-Path -Path "$PSScriptRoot/artifacts") -eq $true) {
    # Loop through items
    foreach ($item in (Get-ChildItem -Path "$PSScriptRoot/artifacts")) {
        New-OctopusArtifact -Path $item.FullName -Name $item.Name
    }
}