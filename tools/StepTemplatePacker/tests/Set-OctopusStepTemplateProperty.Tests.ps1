$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

function Assert-JsonEquivalent {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ActualJson,
        [Parameter(Mandatory = $true)]
        [string] $ExpectedJson
    )

    $actualValue = ConvertFrom-Json -InputObject $ActualJson | ConvertTo-Json -Depth 10 -Compress
    $expectedValue = ConvertFrom-Json -InputObject $ExpectedJson | ConvertTo-Json -Depth 10 -Compress
    $actualValue | Should Be $expectedValue
}

Describe "Set-OctopusStepTemplateProperty" {

        It "Properties collection does not exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }

        It "No properties exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }

        It "Specified property does not exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"otherProperty`": `"`" } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"otherProperty`": `"`",`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }

        It "Property does not exist" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }

        It "Property exists with a null value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : null } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }

        It "Property exists with an empty string value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"`" } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }

        It "Property exists with a string value" {
            $stepJson = ConvertFrom-Json -InputObject "{ `"Properties`": { `"Octopus.Action.Script.Syntax`" : `"mySyntax`" } }";
            Set-OctopusStepTemplateProperty -StepJson     $stepJson `
	                                    -PropertyName "Octopus.Action.Script.Syntax" `
                                            -Value        "PowerShell";
            $expected = "{`r`n  `"Properties`": {`r`n    `"Octopus.Action.Script.Syntax`": `"PowerShell`"`r`n  }`r`n}";
            Assert-JsonEquivalent -ActualJson (ConvertTo-OctopusJson -InputObject $stepJson) -ExpectedJson $expected
        }


}
