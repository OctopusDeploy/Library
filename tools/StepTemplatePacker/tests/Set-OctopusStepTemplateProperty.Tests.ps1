$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

Describe "Set-OctopusStepTemplateProperty" {

        It "Properties collection does not exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }

        It "No properties exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }

        It "Specified property does not exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"otherProperty`": `"`" } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"otherProperty`": `"`",`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }

        It "Property does not exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }

        It "Property exists with a null value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : null } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }

        It "Property exists with an empty string value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"`" } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }

        It "Property exists with a string value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"mySyntax`" } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            ConvertTo-OctopusJson -InputObject $stepJson `
               | Should Be $expected;
        }


}