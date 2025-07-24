# printVersion.ps1
$newVersion = "1.0.0"
Write-Host "Generated version: $version"

# Set pipeline output variable
Write-Host "##vso[task.setvariable variable=version;isOutput=true]1.2.3"
