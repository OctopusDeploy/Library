Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\" -Filter Azure* -Recurse -Force | Remove-Item -Force -Recurse -Verbose

Install-Module -Name $ModuleName -RequiredVersion $AzurePSModuleVersion -Force -Verbose