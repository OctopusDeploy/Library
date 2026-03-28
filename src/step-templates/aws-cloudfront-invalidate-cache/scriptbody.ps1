Write-Host "Setting up AWS profile environment"
aws configure set aws_access_key_id $AccessKey --profile $CredentialsProfileName
aws configure set aws_secret_access_key $SecretKey --profile $CredentialsProfileName
aws configure set default.region $Region --profile $CredentialsProfileName
aws configure set preview.cloudfront true --profile $CredentialsProfileName

Write-Host "Initiating AWS cloudfront invalidation of the following paths:"
Write-Host $InvalidationPaths
aws cloudfront create-invalidation --profile $CredentialsProfileName --distribution-id $DistributionId --paths $InvalidationPaths

Write-Host "Please note that it may take up to 15-20 minutes for AWS to complete the cloudfront cache invalidation"