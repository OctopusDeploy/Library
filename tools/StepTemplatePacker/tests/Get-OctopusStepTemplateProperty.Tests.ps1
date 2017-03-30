$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

Describe "Get-OctopusStepTemplateProperty" {

        It "Properties collection does not exist and no default value is specified" {
            $stepJson = "{ }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                | Should Be ([string]::Empty);
        }

        It "Properties collection does not exist and a default value is specified" {
            $stepJson = ConvertFrom-Json -InputObject "{ }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
					    -DefaultValue "PowerShell" `
                | Should Be "PowerShell";
        }

        It "Property does not exist and no default value is specified" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                | Should Be ([string]::Empty);
        }

        It "Property does not exist and a default value is specified" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
					    -DefaultValue "PowerShell" `
                | Should Be "PowerShell";
        }

        It "Property exists with a null value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : null } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                | Should Be $null;
        }

        It "Property exists with an empty string value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"`" } }"
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                | Should Be ([string]::Empty);
        }

        It "Property exists with a string value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"PowerShell`" } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                | Should Be "PowerShell";
        }

        It "Property exists with a null value and a default value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : null } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
					    -DefaultValue "myDefaultValue" `
                | Should Be $null;
        }

        It "Property exists with an empty string value and a default value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"`" } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
					    -DefaultValue "myDefaultValue" `
                | Should Be ([string]::Empty);
        }

        It "Property exists with a string value and a default value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"PowerShell`" } }";
            Get-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
					    -DefaultValue "myDefaultValue" `
                | Should Be "PowerShell";
        }

}