param(
    [string]$OutputPath = "$PSScriptRoot\..\DesertTycoon-iOS-GitHub-Upload.zip"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path "$PSScriptRoot\.."
if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
}
$tempRoot = Join-Path $env:TEMP ("desert-tycoon-upload-" + [guid]::NewGuid().ToString("N"))

Write-Host "Preparing upload package..."
Write-Host "Project: $projectRoot"

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$excludeTopLevel = @(
    ".git",
    "build",
    "DerivedData"
)

Get-ChildItem -LiteralPath $projectRoot -Force | ForEach-Object {
    if ($excludeTopLevel -contains $_.Name) {
        return
    }

    $destination = Join-Path $tempRoot $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
}

if (Test-Path -LiteralPath $outputFullPath) {
    Remove-Item -LiteralPath $outputFullPath -Force
}

Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $outputFullPath -Force
Remove-Item -LiteralPath $tempRoot -Recurse -Force

Write-Host ""
Write-Host "Done:"
Write-Host $outputFullPath
Write-Host ""
Write-Host "Upload the extracted contents of this package to a GitHub repository, then run:"
Write-Host "Actions -> Build Unsigned IPA for Sideloadly -> Run workflow"
