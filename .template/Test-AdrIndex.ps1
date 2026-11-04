<#
.SYNOPSIS
    Checks that docs/decisions/README.md indexes every decision record in docs/decisions/, and nothing else.

.DESCRIPTION
    From the project template; template updates replace this file. A decision record is a file named NNNN-<title>.md
    directly in docs/decisions/, other than 0000-template.md; the template's own records in docs/decisions/project-template/
    have an index of their own, which template updates keep. Fails, naming each one, on a record the README's index
    doesn't link, on a link in it to a record that doesn't exist, on two records that share a number (as when two
    branches each took the next free one), and on an index row whose link text shows another number than its record's.
    Also fails on a new record numbered below 1000, the template's range: one whose number no record in docs/decisions/
    had at the merge base of HEAD and the default branch (origin/HEAD, else origin/main or origin/master), or of HEAD and
    -Base. A project's older records below 1000 still pass, also under a new title. Without a merge base, as in a shallow
    clone, a clone without origin, or a folder that isn't a repository's root, it skips that check and says so.
    Passes when the repository has no docs/decisions/.

.PARAMETER Path
    The repository root. Defaults to the folder above this script's.

.PARAMETER Base
    A commit to compare with instead of the default branch, such as a merge request's base; the check takes the merge
    base of it and HEAD. Empty means the default branch.

.EXAMPLE
    ./.template/Test-AdrIndex.ps1

.EXAMPLE
    ./.template/Test-AdrIndex.ps1 -Base $env:CI_MERGE_REQUEST_DIFF_BASE_SHA
#>
[CmdletBinding()]
param([string]$Path = (Split-Path -Parent $PSScriptRoot), [string]$Base)
$ErrorActionPreference = 'Stop'
$folder = Join-Path $Path 'docs/decisions'
if (-not (Test-Path -LiteralPath $folder)) { 'Decision index: no docs/decisions/ folder.'; exit 0 }
$readme = Join-Path $folder 'README.md'
$index = if (Test-Path -LiteralPath $readme) { [IO.File]::ReadAllText($readme) } else { '' }

$records = @(Get-ChildItem -LiteralPath $folder -File -Filter '*.md' | Where-Object { $_.Name -match '^\d{4}-.+\.md$' -and $_.Name -ne '0000-template.md' } | ForEach-Object Name | Sort-Object)
$linked = @([regex]::Matches($index, '\]\((?:\./)?(\d{4}-[^)/#]+\.md)(?:#[^)]*)?\)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne '0000-template.md' } | Sort-Object -Unique)
$missing = @($records | Where-Object { $_ -notin $linked })
$dangling = @($linked | Where-Object { $_ -notin $records })
# Two branches or worktrees can each take the next free number; both records then pass every other check.
$duplicates = @($records | Group-Object { $_.Substring(0, 4) } | Where-Object Count -GT 1 | ForEach-Object { "$($_.Name): $($_.Group -join ', ')" })
# An index row shows a number as its link text; it must be its record's.
$mismatched = @([regex]::Matches($index, '\[(?:ADR-)?(\d{4})\]\((?:\./)?(\d{4})-[^)/#]+\.md') | Where-Object { $_.Groups[1].Value -ne $_.Groups[2].Value } | ForEach-Object { $_.Value })
# A project numbers its records from 1000 (template ADR-0012). One below 1000 is new when no record at the merge base with the default branch had its number, so older records, also under a new title, still pass.
$belowRange = @($records | Where-Object { [int]$_.Substring(0, 4) -lt 1000 })
$newBelow = @()
if ($belowRange) {
    $mergeBase = $null
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $reason = "Git isn't installed" }
    else {
        $prefix = git -C $Path rev-parse --show-prefix 2>$null
        if ($LASTEXITCODE -or $prefix) { $reason = "$Path isn't the root of a Git repository" }
        else {
            $candidates = if ($Base) { @($Base) } else { @('origin/HEAD', 'origin/main', 'origin/master') }
            $target = $candidates | Where-Object { $null = git -C $Path rev-parse --quiet --verify "$_^{commit}" 2>$null; -not $LASTEXITCODE } | Select-Object -First 1
            if (-not $target) { $reason = "there is no $($candidates -join ' or ') to compare with" }
            else {
                $mergeBase = git -C $Path merge-base HEAD $target 2>$null
                if ($LASTEXITCODE -or -not $mergeBase) { $mergeBase = $null; $reason = "HEAD has no merge base with $target, as in a shallow clone" }
            }
        }
    }
    if ($mergeBase) {
        $baseNumbers = @(git -C $Path ls-tree --name-only $mergeBase -- docs/decisions/ | ForEach-Object { if ($_ -match '^"?docs/decisions/(\d{4})-') { $Matches[1] } })
        $newBelow = @($belowRange | Where-Object { $_.Substring(0, 4) -notin $baseNumbers })
    }
    else { "Decision numbers: didn't check for new records numbered below 1000: $reason." }
}

foreach ($name in $missing) { "Not in docs/decisions/README.md's index: $name" }
foreach ($name in $dangling) { "docs/decisions/README.md links a record that doesn't exist: $name" }
foreach ($entry in $duplicates) { "Two records share the number $entry; renumber the later one" }
foreach ($link in $mismatched) { "docs/decisions/README.md shows another number than its record's: $link" }
foreach ($name in $newBelow) { "New record numbered below 1000, the template's range: $name; number it from 1000, and change its title, index row and links to match" }
$problems = $missing.Count + $dangling.Count + $duplicates.Count + $mismatched.Count + $newBelow.Count
if ($problems) { "Decision index: FAILED ($problems)"; exit 1 }
"Decision index: $($records.Count) records, all indexed."
exit 0
