param(
    [string]$OutputPath = "$PSScriptRoot\..\DesertTycoon-iOS-GitHub-Upload-SMALL.zip"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path "$PSScriptRoot\.."
if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
}

$tempRoot = Join-Path $env:TEMP ("desert-tycoon-small-upload-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

function Copy-ProjectItem {
    param(
        [Parameter(Mandatory=$true)][string]$RelativePath
    )

    $source = Join-Path $projectRoot $RelativePath
    $destination = Join-Path $tempRoot $RelativePath
    $destinationParent = Split-Path $destination -Parent
    New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

Write-Host "Preparing small GitHub upload package..."
Write-Host "Project: $projectRoot"

$items = @(
    ".github",
    "ios-scaffold\App",
    "ios-scaffold\build_ipa.sh",
    "ios-scaffold\ExportOptions.plist",
    "ios-scaffold\project.yml",
    "README_AR.md",
    "PROJECT_STATUS_AR.md",
    "FASTEST_IPHONE_INSTALL_WINDOWS_AR.md",
    "BUILD_WITHOUT_MAC_AR.md",
    "MIGRATION_REPORT.md",
    "analysis",
    "tools"
)

foreach ($item in $items) {
    Copy-ProjectItem -RelativePath $item
}

$resourcesDestination = Join-Path $tempRoot "ios-scaffold\Resources"
New-Item -ItemType Directory -Force -Path $resourcesDestination | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot "ios-scaffold\Resources") -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $resourcesDestination $_.Name) -Force
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
Write-Host "This package excludes portable-assets and LegacyAssets so GitHub web upload stays below 25MB."
Write-Host "Extract it, then upload the extracted files and folders to GitHub."
