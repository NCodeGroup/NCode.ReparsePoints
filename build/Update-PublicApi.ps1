<#
.SYNOPSIS
    Records each packable project's public API in its PublicAPI.Shipped.txt and PublicAPI.Unshipped.txt.

.DESCRIPTION
    From the project template; template updates replace this file. The build fails on a public symbol that neither file
    lists (RS0016) and on a listed symbol that no longer exists (RS0017), so a change to the public API is a reviewed
    line in the pull request. For each packable project in the repository, or the ones -Project names:

    - creates PublicAPI.Shipped.txt and PublicAPI.Unshipped.txt beside the project file when they are missing, each
      starting with "#nullable enable", so a new project starts tracking its API;
    - runs `dotnet format analyzers --diagnostics RS0016` to add the public symbols the files don't list yet to
      PublicAPI.Unshipped.txt;
    - lists the symbols the build says no longer exist (RS0017), which dotnet format doesn't reliably remove: delete
      an unshipped line, or mark a shipped symbol removed with a "*REMOVED*" line in PublicAPI.Unshipped.txt.

    With -Release, moves every PublicAPI.Unshipped.txt entry into PublicAPI.Shipped.txt instead, applying its
    "*REMOVED*" lines, so the next release's changes start from an empty PublicAPI.Unshipped.txt. Run it in the change
    that releases a version.

    A project is packable unless its name ends in .Tests or it sets IsPackable to false.

.PARAMETER Project
    The project files to update, instead of every packable project in the repository.

.PARAMETER Release
    Move the unshipped entries into PublicAPI.Shipped.txt.

.EXAMPLE
    ./build/Update-PublicApi.ps1

.EXAMPLE
    ./build/Update-PublicApi.ps1 -Release
#>
[CmdletBinding()]
param(
    [string[]]$Project,
    [switch]$Release
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
$header = '#nullable enable'

function Get-ApiLine([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @([IO.File]::ReadAllLines($Path) | Where-Object { $_.Trim() -and $_.Trim() -ne $header })
}

function Write-ApiFile([string]$Path, [string[]]$Lines) {
    $sorted = @($Lines | Sort-Object -Unique -CaseSensitive)
    [IO.File]::WriteAllText($Path, (@($header) + $sorted -join "`n") + "`n", $utf8)
}

$projects = if ($Project) { @($Project | ForEach-Object { (Resolve-Path -LiteralPath $_).Path }) }
else {
    @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.csproj' |
            Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|\.git|\.claude)[\\/]' } |
            ForEach-Object FullName)
}
$packable = @(foreach ($p in $projects) {
        if ([IO.Path]::GetFileNameWithoutExtension($p).EndsWith('.Tests')) { continue }
        $value = (dotnet msbuild $p -getProperty:IsPackable -nologo 2>$null | Out-String).Trim()
        if ($LASTEXITCODE) { throw "Couldn't read IsPackable from $p." }
        if ($value -ne 'false') { $p }
    })
if (-not $packable) { 'No packable project found.'; exit 0 }

foreach ($p in $packable) {
    $dir = Split-Path -Parent $p
    $name = [IO.Path]::GetRelativePath($root, $p).Replace('\', '/')
    $shipped = Join-Path $dir 'PublicAPI.Shipped.txt'
    $unshipped = Join-Path $dir 'PublicAPI.Unshipped.txt'

    if ($Release) {
        $removed = @(Get-ApiLine $unshipped | Where-Object { $_.StartsWith('*REMOVED*') } | ForEach-Object { $_.Substring('*REMOVED*'.Length) })
        $added = @(Get-ApiLine $unshipped | Where-Object { -not $_.StartsWith('*REMOVED*') })
        $kept = @(Get-ApiLine $shipped | Where-Object { $_ -notin $removed })
        Write-ApiFile $shipped ($kept + $added)
        Write-ApiFile $unshipped @()
        "${name}: moved $($added.Count) entries into PublicAPI.Shipped.txt and removed $($removed.Count)."
        continue
    }

    foreach ($file in $shipped, $unshipped) {
        if (-not (Test-Path -LiteralPath $file)) { Write-ApiFile $file @(); "${name}: created $(Split-Path -Leaf $file)." }
    }
    $before = (Get-ApiLine $unshipped).Count
    dotnet format analyzers $p --diagnostics RS0016 2>&1 | Out-Null
    if ($LASTEXITCODE) { throw "dotnet format failed for $name." }
    # dotnet format can rewrite the file with CRLF line endings; keep the repository's LF.
    Write-ApiFile $unshipped (Get-ApiLine $unshipped)
    "${name}: added $((Get-ApiLine $unshipped).Count - $before) entries to PublicAPI.Unshipped.txt."
    $stale = @(dotnet build $p --nologo 2>&1 | Select-String -Pattern "error RS0017: Symbol '([^']+)'" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique)
    foreach ($symbol in $stale) { "${name}: listed but no longer public, remove it or mark it *REMOVED*: $symbol" }
}
