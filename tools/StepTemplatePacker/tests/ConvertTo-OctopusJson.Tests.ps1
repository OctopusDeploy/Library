$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

Describe "ConvertTo-OctopusDeploy" {

    It "InputObject is null" {
        $input    = $null;
        $expected = "null";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is an empty string" {
        $input    = [string]::Empty;
        $expected = "`"`"";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is a simple string" {
        $input    = "my simple string";
        $expected = "`"my simple string`"";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is a string with special characters" {
        $input    = "my \ `"string`" with `r`n special `t characters";
        $expected = "`"my \\ \`"string\`" with \r\n special \t characters`"";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is a positive integer" {
        $input    = 100;
        $expected = "100";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is a negative integer" {
        $input    = -100;
        $expected = "-100";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is an empty array" {
        $input    = @();
        $expected = "[]";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is a populated array" {
        $input    = @( $null, 100, "my string" );
        $expected = "[`r`n  null,`r`n  100,`r`n  `"my string`"`r`n]";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is an empty PSCustomObject" {
	$input    = new-object PSCustomObject;
        $expected = "{}";
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is a populated PSCustomObject" {
	$input    = [PSCustomObject] [ordered] @{
            "myNull"     = $null
            "myInt"      = 100
            "myString"   = "text"
	    "myArray"    = @( $null, 200, "string", [PSCustomObject] [ordered] @{ "nestedProperty" = "nestedValue" } )
	    "myPsObject" = [PSCustomObject] [ordered] @{ "childProperty" = "childValue" }
	};
        $expected = @"
{
  "myNull": null,
  "myInt": 100,
  "myString": "text",
  "myArray": [
    null,
    200,
    "string",
    {
      "nestedProperty": "nestedValue"
    }
  ],
  "myPsObject": {
    "childProperty": "childValue"
  }
}
"@
        ConvertTo-OctopusJson -InputObject $input `
            | Should Be $expected;
    }

    It "InputObject is an unhandled type" {
        { ConvertTo-OctopusJson -InputObject ([System.Guid]::NewGuid()) } `
            | Should Throw "Unhandled input object type 'System.Guid'.";
    }

}