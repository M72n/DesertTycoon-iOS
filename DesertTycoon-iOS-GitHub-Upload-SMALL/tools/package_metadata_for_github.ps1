param(
    [string]$OutputPath = "$PSScriptRoot\..\DesertTycoon-iOS-Metadata-Upload.zip"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path "$PSScriptRoot\.."
$legacyRoot = Join-Path $projectRoot "ios-scaffold\Resources\LegacyAssets"

if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
}

if (-not (Test-Path -LiteralPath $legacyRoot)) {
    throw "LegacyAssets not found: $legacyRoot"
}

$tempRoot = Join-Path $env:TEMP ("desert-tycoon-metadata-upload-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$projectRootFull = [System.IO.Path]::GetFullPath($projectRoot)
$projectRootPrefix = $projectRootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

$extensions = @(".plist", ".tmx", ".srt", ".fnt", ".pem")
$files = Get-ChildItem -Recurse -LiteralPath $legacyRoot -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }

foreach ($file in $files) {
    $fileFullPath = [System.IO.Path]::GetFullPath($file.FullName)
    if (-not $fileFullPath.StartsWith($projectRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to package file outside project root: $fileFullPath"
    }

    $relativePath = $fileFullPath.Substring($projectRootPrefix.Length)
    $destination = Join-Path $tempRoot $relativePath
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
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
Write-Host "Metadata files packaged: $($files.Count)"
Write-Host "This package excludes large images, videos, and audio."
