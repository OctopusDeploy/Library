Import-Module Pester

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirName = Split-Path -Leaf $here
write-host $here
$toTest = (Join-Path $here "..\..\step-template\ssis-deploy-sqlagentjob.ps1")

# Initialize OctopusParameters
$OctopusParameters = @{}
$OctopusParameters.Add("SSIS_ServerName", "localhost")
$OctopusParameters.Add("SSIS_FolderName", "Hekla")
$OctopusParameters.Add("SSIS_ProjectName", "Dummy.MA.Postings.ispac")
$OctopusParameters.Add("SSIS_PackageName", "Package")
$OctopusParameters.Add("SSIS_JobName", "1 Job Name Testing")
$OctopusParameters.Add("SSIS_CatalogName", "SSISDB")
$OctopusParameters.Add("SSIS_EnvironmentName", "Test")
$OctopusParameters.Add("SSIS_JobStepName", "Job Step Name Test 1")
$OctopusParameters.Add("SSIS_JobScheduleName", "Job Schedule Name")
$OctopusParameters.Add("SSIS_JobExecutionFrequency", "Daily")
$OctopusParameters.Add("SSIS_JobFrequencyInterval", "1")
$OctopusParameters.Add("SSIS_JobExecutionTimeHour", "12")
$OctopusParameters.Add("SSIS_JobExecutionTimeMinute", "00")


#arrange: We need to deploy first a project
$expectedProjectName = $OctopusParameters["SSIS_ProjectName"]
$isPester = $True #Indicate to script this is test
. "$toTest"



Describe "Validate Scripts and Powershell " {
    # Add Tests
    write-host "Executing...."
    write-host $toTest
        Context 'Step Template Setup' {
        It "Arion-deploy-sqljob.ps1 is correct ps1" {
            $toTest | Should Exist
        }

        It "File Contains valid ps1" {
            $psFile = Get-Content -Path $toTest -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should Be 0
         }

    } #end of context

}

Describe "Check Project Exists " {
    # Add Tests
    write-host "returning $Catalog"
    Write-Host "Get project $Project"
    Write-Host "Project time $Project.LastDeployedTime"
    write-host $toTest
        Context 'Step Template Setup' {
        It "Project Name exists" {
            $Project.Name | Should Be $expectedProjectName
        }

        It "Deployment Date is Today" {
            $deploymentDate = $Project.LastDeployedTime
            $deploymentDate.Date | Should -Be (Get-Date).Date
         }

    } #end of context

}

