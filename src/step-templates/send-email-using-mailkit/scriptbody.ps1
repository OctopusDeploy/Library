$ErrorActionPreference = "Stop";

if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}
$emailSubject = $OctopusParameters["SendEmail.Subject"]
$emailSmtpServer = $OctopusParameters["SendEmail.SmtpServer"]
$emailSmtpPort = $OctopusParameters["SendEmail.SmtpPort"]
$emailCredentialsUsername = $OctopusParameters["SendEmail.Credentials.Username"]
$emailCredentialsPassword = $OctopusParameters["SendEmail.Credentials.Password"]
$emailSecureSocketOption = $OctopusParameters["SendEmail.SecureSocketOption"]

$validSecureSocketOptions = @("None", "Auto", "SslOnConnect", "StartTls", "StartTlsWhenAvailable")
if(-not $validSecureSocketOptions.Contains($emailSecureSocketOption)) {
    Write-Error "Invalid SecureSocketOption: $emailSecureSocketOption. Must be one of: $($validSecureSocketOptions -join ", ")."
    return
}

$emailFromAddress = $OctopusParameters["SendEmail.FromAddress"]
$emailToAddresses = $OctopusParameters["SendEmail.TOAddresses"]
$emailCcAddresses = $OctopusParameters["SendEmail.CCAddresses"]
$emailReplyToAddress = $OctopusParameters["SendEmail.ReplyToAddress"]

$HtmlBody = $OctopusParameters["SendEmail.HtmlBody"]
$TextBody = $OctopusParameters["SendEmail.TextBody"]

Write-Verbose "Checking for MimeKit and MailKit packages."
try {
    
    $MimeKitPackage = (Get-Package MimeKit -ErrorAction Stop) | Select-Object -First 1
} 
catch {
    $MimeKitPackage = $null
}
if ($null -eq $MimeKitPackage) {
    Write-Output "Downloading MimeKit from nuget.org."
    Install-Package -Name 'MimeKit' -Source "https://www.nuget.org/api/v2" -SkipDependencies -Force -Scope CurrentUser
    $MimeKitPackage = (Get-Package MimeKit) | Select-Object -First 1
}

try {
    $MailKitPackage = (Get-Package MailKit -ErrorAction Stop) | Select-Object -First 1
} 
catch {
    $MailKitPackage = $null
}
if ($null -eq $MailKitPackage) {
    Write-Output "Downloading MailKit from nuget.org."
    Install-Package -Name 'MailKit' -Source "https://www.nuget.org/api/v2" -SkipDependencies -Force -Scope CurrentUser
    $MailKitPackage = (Get-Package MailKit) | Select-Object -First 1
}

$MimeKitPath = Join-Path (Get-Item $MimeKitPackage.source).Directory.FullName "lib/netstandard2.1/MimeKit.dll"
$MailKitPath = Join-Path (Get-Item $MailKitPackage.source).Directory.FullName "lib/netstandard2.1/MailKit.dll"

Add-Type -Path $MimeKitPath
Add-Type -Path $MailKitPath

# Validation/Setting of Secure Socket Options needed after libraries loaded
switch($emailSecureSocketOption) {
    "Auto" {
        $secureSocketOption = [MailKit.Security.SecureSocketOptions]::Auto
    }
    "None" {
        $secureSocketOption = [MailKit.Security.SecureSocketOptions]::None
    }
    "SslOnConnect" {
        $secureSocketOption = [MailKit.Security.SecureSocketOptions]::SslOnConnect
    }
    "StartTls" {
        $secureSocketOption = [MailKit.Security.SecureSocketOptions]::StartTls
    }
    "StartTlsWhenAvailable" {
        $secureSocketOption = [MailKit.Security.SecureSocketOptions]::StartTlsWhenAvailable
    }
    default {
        Write-Error "Invalid SecureSocketOption: $emailSecureSocketOption. Must be one of: $($validSecureSocketOptions -join ", ")."
        return
    }
}

$SMTP = New-Object MailKit.Net.Smtp.SmtpClient

$Message = New-Object MimeKit.MimeMessage
$ContentBuilder = [MimeKit.BodyBuilder]::new()

$ContentBuilder.HtmlBody = $HtmlBody
$ContentBuilder.TextBody = $TextBody
Write-Verbose "Setting From address: $emailFromAddress" 
$Message.From.Add($emailFromAddress)
$toAddresses = $emailToAddresses -split ","
Write-Verbose "Setting TO addresses: $emailToAddresses"
foreach($toAddress in $toAddresses) {
    $Message.To.Add($toAddress)
}

if(-not [string]::IsNullOrWhitespace($emailCcAddresses)) {
    Write-Verbose "Setting CC addresses: $emailCcAddresses"
    $ccAddresses = $emailCcAddresses -split ","
    foreach($ccAddress in $ccAddresses) {
        $Message.Cc.Add($ccAddress)
    }
}
if(-not [string]::IsNullOrWhitespace($emailReplyToAddress)) {
    Write-Verbose "Setting ReplyTo address: $emailReplyToAddress"
    $Message.ReplyTo.Add($emailReplyToAddress)
}

Write-Verbose "Setting subject to: $emailSubject"
$Message.Subject = $emailSubject
Write-Verbose "Setting MimeMessage Body contents"
$Message.Body = $ContentBuilder.ToMessageBody()
Write-Verbose "Connecting to SMTP server: $emailSmtpServer on port: $emailSmtpPort (using SecureSocketOption=$emailSecureSocketOption)"
$SMTP.Connect($emailSmtpServer, $emailSmtpPort, $secureSocketOption)
Write-Verbose "Authenticating..."
$SMTP.Authenticate($emailCredentialsUsername, $emailCredentialsPassword)
Write-Output "Sending email..."
$SMTP.Send($Message)
Write-Output "Email sent."
$SMTP.Disconnect($true)
$SMTP.Dispose()