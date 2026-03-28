$shell_app=new-object -com shell.application

$FOF_SILENT_FLAG = 4
$FOF_NOCONFIRMATION_FLAG = 16

if (Test-Path $filename)
{
   Write-Host Unzipping $filename
   $zip_file = $shell_app.namespace("$filename")
   $destination = $shell_app.namespace("$dest")
   $destination.Copyhere($zip_file.items(), $FOF_SILENT_FLAG + $FOF_NOCONFIRMATION_FLAG)
}
else
{
    Write-Host File $filename does not exist
}
