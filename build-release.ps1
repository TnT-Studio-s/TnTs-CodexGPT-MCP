param(
    [string]$Version = "1.10",
    [string]$ReleaseRepo = "nexus382/codex-buddy-releases",
    [switch]$Publish
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$artifactsRoot = Join-Path $root ".artifacts\release"
$publishDir = Join-Path $artifactsRoot "CodexBuddy-$Version-win-x64"
$zipPath = Join-Path $artifactsRoot "CodexBuddy-$Version-win-x64.zip"
$tag = "v$Version"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$source = Join-Path $root "release\Program.cs"
$resource = Join-Path $root "CodexBuddy.ps1"
$exePath = Join-Path $publishDir "CodexBuddy.exe"

New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
Remove-Item -Recurse -Force $publishDir -ErrorAction SilentlyContinue
Remove-Item -Force $zipPath -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null

$cscArgs = @(
    "/nologo"
    "/optimize+"
    "/debug-"
    "/target:winexe"
    "/platform:x64"
    "/out:$exePath"
    "/resource:$resource,CodexBuddy.ps1"
    "/reference:System.Core.dll"
    $source
)

& $csc @cscArgs

if ($LASTEXITCODE -ne 0) {
    throw "C# build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Build output not found: $exePath"
}

Copy-Item -LiteralPath (Join-Path $root "README.md") -Destination (Join-Path $publishDir "README.md") -Force
Copy-Item -LiteralPath (Join-Path $root "PUBLISHING.md") -Destination (Join-Path $publishDir "PUBLISHING.md") -Force
Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $zipPath -Force

Write-Host "Built release zip: $zipPath"

if ($Publish) {
    gh release create $tag --repo $ReleaseRepo --title $tag --notes "Codex Buddy $tag compiled release" $zipPath
}
