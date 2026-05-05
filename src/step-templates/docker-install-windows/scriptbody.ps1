Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies

$DockerModule = Get-Module -ListAvailable -Name DockerMsftProvider 
if (-Not $DockerModule) {
    Write-Host "Installing DockerMsftProvider module"
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
} else {
    Write-Host "DockerMsftProvider module already installed"
}

try {
	$DockerPackage = Get-Package -Name docker
} catch [Exception] {}

if (-Not $DockerPackage) {
    Write-Host "Installing docker package"
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force

    Write-Host "Restarting machine..."
    Restart-Computer -Force
} else {
    Write-Host "docker package already installed"
}