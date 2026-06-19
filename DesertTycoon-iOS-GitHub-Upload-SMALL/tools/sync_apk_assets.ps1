param(
    [string]$ApkPath = "C:\Users\USER\Downloads\desert-tycoon.apk",
    [string]$OutputPath = "$PSScriptRoot\..\ios-scaffold\Resources\LegacyAssets",
    [string]$ExtractPath = "$PSScriptRoot\..\apk-extracted"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found: $ApkPath"
}

$extractFullPath = [System.IO.Path]::GetFullPath($ExtractPath)
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

function Assert-PathInsideProject {
    param(
        [Parameter(Mandatory=$true)][string]$PathToCheck,
        [Parameter(Mandatory=$true)][string]$Label
    )

    $projectRootWithSeparator = $projectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $PathToCheck.StartsWith($projectRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must stay inside project root. Refusing path: $PathToCheck"
    }
}

Assert-PathInsideProject -PathToCheck $extractFullPath -Label "Extract path"
Assert-PathInsideProject -PathToCheck $outputFullPath -Label "Output path"

if (Test-Path -LiteralPath $extractFullPath) {
    Remove-Item -LiteralPath $extractFullPath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $extractFullPath | Out-Null
New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ApkPath, $extractFullPath)

$assetsPath = Join-Path $extractFullPath "assets"
if (-not (Test-Path -LiteralPath $assetsPath)) {
    throw "APK does not contain an assets directory."
}

Copy-Item -Path (Join-Path $assetsPath "*") -Destination $outputFullPath -Recurse -Force

$assetStats = Get-ChildItem -Recurse -LiteralPath $outputFullPath -File | Measure-Object -Property Length -Sum
$metadataCount = Get-ChildItem -Recurse -LiteralPath $outputFullPath -File |
    Where-Object { $_.Extension -in ".plist", ".tmx", ".srt", ".fnt" } |
    Measure-Object

Write-Host "Synced APK assets into:"
Write-Host $outputFullPath
Write-Host ""
Write-Host "Files: $($assetStats.Count)"
Write-Host "Bytes: $($assetStats.Sum)"
Write-Host "Metadata files (.plist/.tmx/.srt/.fnt): $($metadataCount.Count)"
