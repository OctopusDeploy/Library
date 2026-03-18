function global:ConvertTo-CompressedJsonForAssertion {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Json
    )

    return (ConvertFrom-Json -InputObject $Json | ConvertTo-Json -Depth 10 -Compress)
}

function global:PesterBeJsonEquivalent($value, $expected) {
    return (ConvertTo-CompressedJsonForAssertion -Json $value) -eq (ConvertTo-CompressedJsonForAssertion -Json $expected)
}

function global:PesterBeJsonEquivalentFailureMessage($value, $expected) {
    return "Expected JSON equivalent to: {$expected}`nBut was: {$value}"
}

function global:NotPesterBeJsonEquivalentFailureMessage($value, $expected) {
    return "Expected JSON not equivalent to: {$expected}`nBut was: {$value}"
}
