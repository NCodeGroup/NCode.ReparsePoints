<#
.SYNOPSIS
    Print where the plan in a folder stands, and the workflow command to run next.

.DESCRIPTION
    Reads the Git repository that contains the folder and prints one "key: value" line per fact, in a fixed order:
    folder, worktree, branch, default, host, plan, issue, refs, release, steps, reviewed, landing, protected, ahead, behind, landed,
    pr, merge, tag, renumber, conflicts, changelog-format, changelog-version, changelog-backfill, changelog-duplicates, published, issue-state, issue-states, unfiled, dirty, plans and next. A fact that does not apply prints
    "-". With an origin remote, the script fetches it, ignoring a failure, unless -NoFetch is given. The calls that wait on the network start together, each in a runspace of its own: the fetch, git ls-remote for origin's tags, and, through gh's REST API (gh api, which works where GitHub's GraphQL API is refused, as in a Claude Code cloud session) or glab, the pull request or merge request list, the branch protection, each issue's state and the release. The release check starts with them only when the clone already has the Release: tag, and otherwise once the fetch shows origin has it. The script waits for the fetch before it reads origin's refs, and for each other call where it uses the answer. landed is
    yes when HEAD is on the default branch, or when any of the branch's merged pull requests or merge requests has its
    merge commit there and its head holds HEAD or has HEAD's tree. pr names that request, or else the newest one.
    merge is the commit that request merged as, when it merged. issue is the plan's Issue: line, which names one
    issue or up to three separated by spaces; issue-states gives each one's state as <reference>=<state>, and
    issue-state is OPEN while any of them is open, CLOSED when all are closed, and unknown otherwise. refs is the plan's Refs: line, the issues it relates to without resolving them; the script reads no state for them.
    landing gives each key of AGENTS.md's Landing section that the workflow reads as key=value, with its default when
    the section leaves it out; a value may be written in backticks, and a value with a space is printed in double quotes.
    gate is the command /ship-plan runs before it pushes, or none.
    prelude is the PowerShell command that sets up the shell, such as putting a tool on PATH, before the gate and each Done-when command, or none. It is invalid unless it is one command on one line, with no ;, |, &, &&, || or # comment: a script in the repository, written as ./<path>.ps1, that exists, or another command with its arguments.
    pr-format is <file>#<heading>, the section that sets a pull request's title and description, or none.
    review-bots names the review bots whose findings /run-issues and /address-feedback may act on, by login without
    the [bot] suffix GitHub's REST API adds, joined by commas: ncode-review by default, or none.
    max-review-rounds is the number of rounds of pull request feedback after which /run-issues recommends the merge
    and stops adding steps for the bots' findings, 3 by default; a value that isn't a whole number from 1 to 999 reads as 3.
    renumber is the version the plan moves to when another plan has landed its Release: version, or a later one, first: the newest version tag on origin (the clone's tags when origin's can't be read) or newest release heading of the changelog, ## [<version>] - <date> or ## <version>, on origin's default branch, raised as the plan's version was raised (patch, else minor, else major). It is - when that version is older, release is none, or the plan has landed. next is ship-plan rather than wait while a pull request is open and renumber isn't -, so /ship-plan renumbers the plan.
    tag is present when origin has the plan's Release: version tag, local when only this clone has it, such as one a failed push left, absent when neither has it, and unknown when git ls-remote can't read origin's tags. Without an origin remote, it reads the clone's tags: present or absent.
    conflicts names the files that conflict when origin's default branch merges into HEAD, joined by ", ", from git merge-tree --write-tree, which changes neither the index nor the working tree; none when the merge is clean, unknown when Git can't say, such as Git older than 2.38, and - on the default branch or once the plan has landed. next is ship-plan rather than wait while a pull request is open and conflicts names files, so /ship-plan adds a step that merges the default branch in.
    changelog-format is keep-a-changelog when the changelog has a ## [Unreleased] or ## [<version>] heading, other when it has neither, and missing without the file; changelog-version is its newest release, with a leading v when the plan's Release: version has one, or -. changelog-backfill names the version tags merged into HEAD, shaped like v1.2.3 or 1.2.3, that have no release heading in the changelog, as <oldest>..<newest>, the tag alone when there is one, or - when there is none. changelog-duplicates names each Keep a Changelog heading (### Added, Changed, Deprecated, Removed, Fixed or Security) that a section of the changelog has more than once, as <section> <heading> joined by ", ", such as [Unreleased] Changed, or - when every section has at most one of each; two pull requests that each add the same heading to a section leave it twice once both merge.
    unfiled counts the lines of PLAN.md's ## Follow-ups section, up to the next ## heading, that start with "- " or "* " and don't end with a mark /ship-plan appends: an em dash, then "filed as #<number>" or "already tracked as #<number>", either with <owner/repo> before the #, or "dropped". A line that says only None or Nothing doesn't count. It is 0 without the section and - without a plan. next is ship-plan rather than finish-plan for a landed plan while unfiled is above 0 and the Landing section's follow-ups isn't none, so /ship-plan files them.
    protected is hook when protect is hook and Git runs .githooks/pre-push, host when GitHub or GitLab requires pull
    requests into the default branch, no when it does not, unknown when the host or its CLI cannot say, and - without
    a default branch.

.PARAMETER Path
    A folder inside the repository. Defaults to the current folder.

.PARAMETER NoFetch
    Skip the fetch of origin, and read ahead, behind and landed from the remote refs the last fetch left. Every
    worktree of a repository shares those refs, so a second call for another worktree needs no fetch of its own.

.EXAMPLE
    .\Get-PlanState.ps1

.EXAMPLE
    .\Get-PlanState.ps1 -Path .claude/worktrees/csv-export -NoFetch
#>
[CmdletBinding()]
param([string]$Path = '.', [switch]$NoFetch)
$ErrorActionPreference = 'Stop'

function Read-Lines([string]$File) {
    ([IO.File]::ReadAllText($File) -split "`r?`n")
}

function Get-LandingValue([string]$Text, [switch]$Spaced) {
    $value = $Text.Trim()
    if ($value -match '^`(.+)`$' -or $value -match '^"(.+)"$') { $value = $Matches[1].Trim() }
    if (-not $Spaced) { $value = ($value -split '\s+')[0] }
    $value
}

# Whether a Landing section's prelude is one command the workflow can dot-source: a script in the repository, as
# ./<path>.ps1, that exists, or another command with its arguments, and nothing that chains or pipes commands.
# Invoke-PlanSteps.ps1 loads this function from this file to check a plan's - Prelude: line by the same rule.
function Test-Prelude([string]$Command, [string]$Root) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Command, [ref]$tokens, [ref]$errors)
    # A comment would hide the rest of the one-line command the workflow wraps the prelude in.
    if ($errors.Count -or ($tokens | Where-Object Kind -EQ 'Comment') -or $ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or $ast.DynamicParamBlock -or -not $ast.EndBlock -or $ast.EndBlock.Traps) { return $false }
    $statements = @($ast.EndBlock.Statements)
    if ($statements.Count -ne 1 -or $statements[0] -isnot [Management.Automation.Language.PipelineAst] -or $statements[0].Background) { return $false }
    $elements = @($statements[0].PipelineElements)
    if ($elements.Count -ne 1 -or $elements[0] -isnot [Management.Automation.Language.CommandAst] -or $elements[0].InvocationOperator -ne 'Unknown') { return $false }
    $name = $elements[0].GetCommandName()
    if (-not $name) { return $false }
    if ($name -notmatch '\.ps1$') { return $true }
    if ($name -notmatch '^\.[\\/]' -or ($name -split '[\\/]') -contains '..') { return $false }
    Test-Path -LiteralPath (Join-Path $Root ($name.Substring(2) -replace '\\', '/')) -PathType Leaf
}

function ConvertTo-PlanVersion([string]$Text) {
    if ($Text -match '^v?(\d+)\.(\d+)\.(\d+)$') { return [version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3]) }
    $null
}

# The version of the first release heading in a changelog, as ## [1.2.3] - 2026-01-31 or ## 1.2.3, or $null.
function Get-ChangelogVersion([string[]]$Lines) {
    foreach ($line in $Lines) {
        if ("$line" -match '^## \[?(v?\d+\.\d+\.\d+)\]?(?: - \d{4}-\d{2}-\d{2})?(?: \[YANKED\])?\s*$') { return ConvertTo-PlanVersion $Matches[1] }
    }
    $null
}

# keep-a-changelog when a changelog has a ## [Unreleased] or ## [<version>] heading, else other.
function Get-ChangelogFormat([string[]]$Lines) {
    foreach ($line in $Lines) {
        if ("$line" -match '^## \[(Unreleased|v?\d+\.\d+\.\d+)\]') { return 'keep-a-changelog' }
    }
    'other'
}

# The version tags merged into HEAD that have no release heading in a changelog: <oldest>..<newest>, the tag alone, or -.
function Get-ChangelogBackfill([string[]]$Lines) {
    $listed = @(foreach ($line in $Lines) { if ("$line" -match '^## \[?(v?\d+\.\d+\.\d+)\]?(?: - \d{4}-\d{2}-\d{2})?(?: \[YANKED\])?\s*$') { ConvertTo-PlanVersion $Matches[1] } })
    $missing = @(foreach ($t in @(& git tag --list --merged HEAD 2>$null)) { $v = ConvertTo-PlanVersion "$t"; if ($null -ne $v -and $v -notin $listed) { [pscustomobject]@{ Tag = "$t"; Version = $v } } })
    $missing = @($missing | Sort-Object Version)
    if ($missing.Count -eq 0) { '-' } elseif ($missing.Count -eq 1) { $missing[0].Tag } else { "$($missing[0].Tag)..$($missing[-1].Tag)" }
}

# The Keep a Changelog headings that a changelog section has more than once, as "<section> <heading>" joined by ", ", or -.
function Get-ChangelogDuplicate([string[]]$Lines) {
    $found = [Collections.Generic.List[string]]::new()
    $section = $null; $seen = @{}; $fence = $null
    foreach ($line in $Lines) {
        # As in Markdown, a fence closes only on a bare run of its own character at least as long as the one that opened it,
        # and a fence that never closes runs to the end of the file.
        if ($null -ne $fence) {
            if ("$line" -match '^\s*(`{3,}|~{3,})\s*$' -and $Matches[1][0] -eq $fence[0] -and $Matches[1].Length -ge $fence.Length) { $fence = $null }
            continue
        }
        if ("$line" -match '^\s*(`{3,}|~{3,})') { $fence = $Matches[1]; continue }
        if ("$line" -match '^## +(\[[^\]]+\]|\S+)') { $section = $Matches[1]; $seen = @{}; continue }
        if ($null -ne $section -and "$line" -cmatch '^### +(Added|Changed|Deprecated|Removed|Fixed|Security)\s*$') {
            $heading = $Matches[1]
            $seen[$heading] = 1 + [int]$seen[$heading]
            if ($seen[$heading] -eq 2) { $found.Add("$section $heading") }
        }
    }
    if ($found.Count) { $found -join ', ' } else { '-' }
}

# The number of follow-ups in a plan's ## Follow-ups section that /ship-plan has not filed, tracked or dropped.
function Get-UnfiledFollowUps([string[]]$Lines) {
    $count = 0; $inSection = $false
    foreach ($line in $Lines) {
        if ("$line" -match '^## ') { $inSection = ("$line" -match '^## Follow-ups\s*$'); continue }
        if ($inSection -and "$line" -match '^[-*] \S' -and "$line" -notmatch '^[-*] (?:none|nothing)\.?\s*$' -and "$line" -notmatch '\s\u2014\s(?:(?:filed as|already tracked as)\s+\S*#\d+|dropped)\s*$') { $count++ }
    }
    $count
}

# The tag names origin has, from git ls-remote, or $null when origin can't be read.
function Get-OriginTags {
    $out = @(& git ls-remote --tags --refs origin 2>$null)
    if ($LASTEXITCODE) { return $null }
    , [string[]]@(foreach ($line in $out) { if ("$line" -match '\trefs/tags/(.+)$') { $Matches[1] } })
}

function Get-IssueState([string]$Ref, [string]$HostName) {
    $issueState = 'unknown'
    $numbers = [regex]::Matches($Ref, '\d+')
    if ($HostName -in 'github', 'gitlab' -and $numbers.Count -gt 0) {
        $issueNumber = $numbers[$numbers.Count - 1].Value
        $repoArgs = @()
        $apiRepo = '{owner}/{repo}'
        if ($Ref -match '^(?<r>[^\s/#:]+/[^\s/#:]+)#\d+') { $repoArgs = @('--repo', $Matches['r']); $apiRepo = $Matches['r'] }
        elseif ($Ref -match '^https?://[^/\s]+/(?<r>.+?)/(?:-/)?issues/\d+') { $repoArgs = @('--repo', $Matches['r']); $apiRepo = $Matches['r'] }
        $cli = if ($HostName -eq 'github') { 'gh' } else { 'glab' }
        if (Get-Command $cli -ErrorAction SilentlyContinue) {
            if ($HostName -eq 'github') {
                $out = & gh api "repos/$apiRepo/issues/$issueNumber" 2>$null | Out-String
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $s = "$(($out | ConvertFrom-Json -ErrorAction Stop).state)"
                        if ($s) { $issueState = $s.ToUpperInvariant() }
                    }
                    catch { $issueState = 'unknown' }
                }
            }
            else {
                $out = & glab issue view $issueNumber @repoArgs --output json 2>$null | Out-String
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $issueState = switch ("$(($out | ConvertFrom-Json -ErrorAction Stop).state)") { 'opened' { 'OPEN' } 'closed' { 'CLOSED' } default { 'unknown' } }
                    }
                    catch { $issueState = 'unknown' }
                }
            }
        }
    }
    $issueState
}

function Test-RequestLanded([string]$Merge, [string]$Head, [string]$Default) {
    & git merge-base --is-ancestor $Merge "origin/$Default" 2>$null | Out-Null
    $mergeOnDefault = ($LASTEXITCODE -eq 0)
    & git merge-base --is-ancestor HEAD $Head 2>$null | Out-Null
    $headInPr = ($LASTEXITCODE -eq 0)
    $prTree = (& git rev-parse -q --verify "${Head}^{tree}" 2>$null | Out-String).Trim()
    $headTreeNow = (& git rev-parse -q --verify 'HEAD^{tree}' 2>$null | Out-String).Trim()
    $mergeOnDefault -and ($headInPr -or ($prTree -and $headTreeNow -and $prTree -eq $headTreeNow))
}

# Calls the host's API and returns the HTTP status and the body. The status comes from the response's own status line
# (--include), never from the CLI's wording, and stderr stays out of the body, so a warning can't spoil the JSON. A call
# that got no response at all (no network, no login) has no status.
function Invoke-HostApi([string]$Cli, [string]$Path) {
    $lines = @(& $Cli api --include $Path 2>$null)
    $status = $null
    if ($lines.Count -and $lines[0] -match '^HTTP/\S+\s+(\d{3})\b') { $status = [int]$Matches[1] }
    $blank = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if (-not $lines[$i].Trim()) { $blank = $i; break } }
    $body = if ($blank -ge 0 -and $blank -lt $lines.Count - 1) { $lines[($blank + 1)..($lines.Count - 1)] -join "`n" } else { '' }
    [pscustomobject]@{ Status = $status; Body = $body }
}

function Get-Protected([string]$HostName, [string]$Default, [string]$Protect) {
    if ($Protect -eq 'hook') {
        $h = (& git rev-parse --git-path hooks 2>$null | Out-String).Trim()
        if ($h -and ((((Split-Path -Leaf $h) -eq '.githooks') -and (Test-Path -LiteralPath "$h/pre-push")) -or [bool]('pre-push', 'pre-push.legacy' | Where-Object { Select-String -LiteralPath "$h/$_" -SimpleMatch '.githooks/pre-push' -Quiet -ErrorAction Ignore }))) { return 'hook' }
    }
    if ($Default -eq '-') { return '-' }
    if ($HostName -notin 'github', 'gitlab') { return 'unknown' }
    $cli = if ($HostName -eq 'github') { 'gh' } else { 'glab' }
    if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) { return 'unknown' }
    # The answer is no only when the host says so: rules without a pull request rule, or "not found" (HTTP 404). Any
    # other status, no response at all, or a body that can't be read may hide a rule that requires pull requests, so that
    # is unknown.
    if ($HostName -eq 'github') {
        $unknown = $false
        $rules = Invoke-HostApi gh "repos/{owner}/{repo}/rules/branches/$Default"
        if ($rules.Status -eq 200) {
            try {
                if (@($rules.Body | ConvertFrom-Json -ErrorAction Stop | Where-Object { $_.type -eq 'pull_request' }).Count -gt 0) { return 'host' }
            }
            catch { $unknown = $true }
        }
        elseif ($rules.Status -ne 404) { $unknown = $true }
        $protection = Invoke-HostApi gh "repos/{owner}/{repo}/branches/$Default/protection/required_pull_request_reviews"
        if ($protection.Status -eq 200) { return 'host' }
        if ($protection.Status -ne 404) { $unknown = $true }
        if ($unknown) { return 'unknown' }
        return 'no'
    }
    $protection = Invoke-HostApi glab "projects/:id/protected_branches/$Default"
    if ($protection.Status -eq 404) { return 'no' }
    if ($protection.Status -ne 200) { return 'unknown' }
    try {
        if (@(($protection.Body | ConvertFrom-Json -ErrorAction Stop).push_access_levels | Where-Object { $_.access_level -ne 0 }).Count -eq 0) { return 'host' }
    }
    catch { return 'unknown' }
    'no'
}

# The files that conflict when origin/<Default> merges into HEAD, from git merge-tree, which changes no file: their
# paths joined by ', ', none when the merge is clean, or unknown when Git can't say (such as Git older than 2.38).
function Get-Conflicts([string]$Default) {
    $out = @(& git -c core.quotePath=false merge-tree --write-tree --name-only --no-messages "origin/$Default" HEAD 2>$null)
    $code = $LASTEXITCODE
    if ($code -eq 0) { return 'none' }
    if ($code -eq 1 -and $out.Count -gt 1 -and "$($out[0])" -match '^[0-9a-f]{40,64}$') {
        $files = @($out | Select-Object -Skip 1 | ForEach-Object { "$_" } | Where-Object { $_ })
        if ($files.Count) { return ($files -join ', ') }
    }
    'unknown'
}

# The calls Start-Concurrent started, so the script's finally can stop any that a step never received.
$concurrentCalls = [Collections.Generic.List[object]]::new()

# Starts Command, a native command or one of this script's functions, in a runspace of its own whose current folder is
# Folder, and returns the call without waiting for it, so the calls that wait on the network run at the same time.
# Functions names the script's functions the runspace needs: Command, when it is one, and each function it calls.
function Start-Concurrent([string]$Folder, [string]$Command, [object[]]$Arguments = @(), [string[]]$Functions = @()) {
    $state = [initialsessionstate]::CreateDefault()
    foreach ($name in $Functions) { $state.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new($name, (Get-Item -LiteralPath "function:$name").Definition)) }
    $shell = [powershell]::Create($state)
    $null = $shell.AddScript({
            param($Folder, $Command, $Arguments)
            $ErrorActionPreference = 'Stop'
            Set-Location -LiteralPath $Folder
            $value = & $Command @Arguments 2>$null
            [pscustomobject]@{ Value = $value; ExitCode = $LASTEXITCODE }
        }.ToString()).AddArgument($Folder).AddArgument($Command).AddArgument($Arguments)
    $call = [pscustomobject]@{ Shell = $shell; Handle = $shell.BeginInvoke(); Done = $false }
    $concurrentCalls.Add($call)
    $call
}

# Closes a call Start-Concurrent started: disposing of the call alone leaves its runspace open.
function Close-Concurrent([object]$Call) {
    $runspace = $Call.Shell.Runspace
    try { $Call.Shell.Dispose() }
    finally { $runspace.Dispose() }
}

# Waits for a call Start-Concurrent started, closes it, and returns what Command returned, as Value,
# and its exit code, as ExitCode.
function Receive-Concurrent([object]$Call) {
    $Call.Done = $true
    try { @($Call.Shell.EndInvoke($Call.Handle))[0] }
    finally { Close-Concurrent $Call }
}

Push-Location -LiteralPath $Path
try {
    $folder = (& git rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -or -not $folder) { throw "Not a Git repository: $Path" }
    $folder = $folder -replace '\\', '/'

    $worktree = if ($folder -match '/\.claude/worktrees/([^/]+)$') { $Matches[1] } else { '-' }

    $branch = (& git branch --show-current 2>$null | Out-String).Trim()
    if (-not $branch) { $branch = '-' }

    $originUrl = (& git remote get-url origin 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -or -not $originUrl) {
        $hostName = 'none'
    }
    else {
        $hostName = if ($originUrl -match 'gitlab') { 'gitlab' } elseif ($originUrl -match 'github\.com') { 'github' } else { 'other' }
    }

    if ($hostName -eq 'none') { $default = '-' }
    else {
        $ref = (& git symbolic-ref --short refs/remotes/origin/HEAD 2>$null | Out-String).Trim()
        $default = if ($LASTEXITCODE -or -not $ref) { 'main' } else { $ref -replace '^origin/', '' }
    }

    # PLAN.md
    $plan = '-'; $issue = '-'; $related = '-'; $release = '-'; $steps = '-'; $reviewed = '-'; $unfiled = '-'
    $done = 0; $total = 0; $open = 0; $escalated = @(); $failed = @()
    $planFile = Join-Path $folder 'PLAN.md'
    if (Test-Path -LiteralPath $planFile) {
        $lines = Read-Lines $planFile
        foreach ($line in $lines) { if ($line -match '^# Plan:\s*(.+)$') { $plan = $Matches[1].Trim(); break } }
        foreach ($line in $lines) { if ($line -match '^Issue:\s*(\S.*)$') { $issue = $Matches[1].Trim(); break } }
        foreach ($line in $lines) { if ($line -match '^Refs:\s*(\S.*)$') { $related = $Matches[1].Trim(); break } }
        foreach ($line in $lines) { if ($line -match '^Release:\s*(\S+)') { $release = $Matches[1]; break } }
        $unfiled = Get-UnfiledFollowUps $lines

        $done = 0; $total = 0; $open = 0; $escalated = @(); $failed = @()
        foreach ($line in $lines) {
            if ($line -match '^### \[([ xX!?])\] (\d+)\.') {
                $total++
                switch -CaseSensitive ($Matches[1]) {
                    { $_ -in 'x', 'X' } { $done++ }
                    ' ' { $open++ }
                    '?' { $escalated += $Matches[2] }
                    '!' { $failed += $Matches[2] }
                }
            }
        }
        $escText = if ($escalated) { $escalated -join ',' } else { '-' }
        $failText = if ($failed) { $failed -join ',' } else { '-' }
        $steps = "$done/$total open=$open escalated=$escText failed=$failText"

        foreach ($line in $lines) {
            if ($line -match '^Reviewed:\s*([0-9a-f]{7,40})\s*$') {
                $sha = $Matches[1]
                $reviewTree = (& git rev-parse "${sha}^{tree}" 2>$null | Out-String).Trim()
                $reviewOk = -not $LASTEXITCODE
                $headTree = (& git rev-parse 'HEAD^{tree}' 2>$null | Out-String).Trim()
                $reviewed = if ($reviewOk -and $reviewTree -eq $headTree) { 'current' } else { 'stale' }
                break
            }
        }
    }

    # Landing policy from AGENTS.md
    # Each key the workflow reads, with its default, in the order the landing line prints them.
    $policy = [ordered]@{ integrate = 'pull-request'; release = 'none'; changelog = 'CHANGELOG.md'; draft = 'no'; 'follow-ups' = 'issues'; 'follow-up-label' = 'follow-up'; gate = 'none'; protect = 'none'; 'pr-format' = 'none'; 'review-bots' = 'ncode-review'; 'max-review-rounds' = '3'; prelude = 'none' }
    $spacedKeys = @('follow-up-label', 'gate', 'pr-format', 'review-bots', 'prelude')   # keys whose value keeps its spaces
    $agents = Join-Path $folder 'AGENTS.md'
    if (Test-Path -LiteralPath $agents) {
        $inLanding = $false
        foreach ($line in (Read-Lines $agents)) {
            if ($line -match '^## Landing\s*$') { $inLanding = $true; continue }
            if ($inLanding -and $line -match '^## ') { break }
            if ($inLanding -and $line -match '^- ([a-z-]+):\s*(\S.*)$' -and $policy.Contains($Matches[1])) {
                $key = $Matches[1]; $policy[$key] = Get-LandingValue $Matches[2] -Spaced:($key -in $spacedKeys)
            }
        }
    }
    if ($policy['prelude'] -ne 'none' -and -not (Test-Prelude $policy['prelude'] $folder)) { $policy['prelude'] = 'invalid' }
    # review-bots lists logins without the [bot] suffix REST adds, joined by commas.
    $bots = @($policy['review-bots'] -split '[\s,]+' | ForEach-Object { $_ -replace '\[bot\]\z', '' } | Where-Object { $_ })
    $policy['review-bots'] = if ($bots.Count) { $bots -join ',' } else { 'none' }
    if ($policy['max-review-rounds'] -notmatch '^[1-9]\d{0,2}\z') { $policy['max-review-rounds'] = '3' }
    $integrate = $policy['integrate']; $releasePolicy = $policy['release']
    $landing = @(foreach ($key in $policy.Keys) { if ($policy[$key] -match '\s') { "$key=`"$($policy[$key])`"" } else { "$key=$($policy[$key])" } }) -join ' '

    # Start the calls that wait on the network at the same time; each part below receives its own.
    $fetchCall = $null; $tagsCall = $null
    $cli = if ($hostName -eq 'github') { 'gh' } elseif ($hostName -eq 'gitlab') { 'glab' } else { '' }
    $hasCli = $cli -and [bool](Get-Command $cli -ErrorAction SilentlyContinue)
    $requestsCall = $null; $releaseCall = $null
    if ($hostName -ne 'none' -and -not $NoFetch) { $fetchCall = Start-Concurrent $folder 'git' @('fetch', 'origin', '--prune', '--tags', '--quiet') }
    if ($hostName -ne 'none' -and $release -ne '-') { $tagsCall = Start-Concurrent $folder 'Get-OriginTags' -Functions 'Get-OriginTags' }
    $protectedCall = Start-Concurrent $folder 'Get-Protected' @($hostName, $default, $policy['protect']) -Functions 'Get-Protected', 'Invoke-HostApi'
    if ($hasCli -and $branch -ne '-' -and $branch -ne $default) {
        # The colon is written %3A: gh api fills :owner, :repo and :branch as well as {owner}, so a branch such as repo-x would lose its name.
        # One page of 100, as gh pr list --limit 100 read before: a branch's own pull requests are far fewer.
        $requestsCall = if ($hostName -eq 'github') { Start-Concurrent $folder 'gh' @('api', "repos/{owner}/{repo}/pulls?head={owner}%3A$([uri]::EscapeDataString($branch))&state=all&per_page=100") }
        else { Start-Concurrent $folder 'glab' @('mr', 'list', '--source-branch', $branch, '--all', '--output', 'json') }
    }
    $releaseArgs = if ($hostName -eq 'github') { @('api', "repos/{owner}/{repo}/releases/tags/$release") } else { @('release', 'view', $release) }
    if ($hasCli -and $releasePolicy -eq 'tag+release' -and $release -ne '-') {
        & git rev-parse -q --verify "refs/tags/$release" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $releaseCall = Start-Concurrent $folder $cli $releaseArgs }
    }
    $issueRefs = @($issue -split '[\s,]+' | Where-Object { $_ -and $_ -ne '-' })
    $issueCalls = @(foreach ($ref in $issueRefs) { Start-Concurrent $folder 'Get-IssueState' @($ref, $hostName) -Functions 'Get-IssueState' })
    if ($fetchCall) { $null = Receive-Concurrent $fetchCall }

    # The fetch may have brought the release tag in: then start the release check now, alongside the calls still running.
    $localTag = $false
    if ($release -ne '-') {
        & git rev-parse -q --verify "refs/tags/$release" 2>$null | Out-Null
        $localTag = ($LASTEXITCODE -eq 0)
    }
    if (-not $releaseCall -and $localTag -and $hasCli -and $releasePolicy -eq 'tag+release') { $releaseCall = Start-Concurrent $folder $cli $releaseArgs }
    $protected = (Receive-Concurrent $protectedCall).Value

    # Position against the default branch
    $ahead = '-'; $behind = '-'; $landed = '-'
    if ($default -ne '-') {
        $ahead = (& git rev-list --count "origin/$default..HEAD" 2>$null | Out-String).Trim()
        $behind = (& git rev-list --count "HEAD..origin/$default" 2>$null | Out-String).Trim()
        if (-not $ahead) { $ahead = '-' }
        if (-not $behind) { $behind = '-' }
        & git merge-base --is-ancestor HEAD "origin/$default" 2>$null | Out-Null
        $landed = if ($LASTEXITCODE -eq 0) { 'yes' } else { 'no' }
    }

    $tag = '-'
    $originTags = $null
    if ($tagsCall) { $originTags = (Receive-Concurrent $tagsCall).Value }
    if ($release -ne '-') {
        if ($hostName -eq 'none') { $tag = if ($localTag) { 'present' } else { 'absent' } }
        elseif ($null -eq $originTags) { $tag = 'unknown' }
        elseif ($originTags -ccontains $release) { $tag = 'present' }
        elseif ($localTag) { $tag = 'local' }
        else { $tag = 'absent' }
    }

    # Pull request or merge request
    $pr = '-'; $prNumber = ''; $prState = ''; $prMerge = ''; $prBase = ''
    if ($hostName -in 'github', 'gitlab' -and $branch -ne '-' -and $branch -ne $default) {
        $pr = 'unknown'
        if ($requestsCall) {
            $requestsResult = Receive-Concurrent $requestsCall
            $json = $requestsResult.Value | Out-String
            if ($requestsResult.ExitCode -eq 0) {
                try {
                    $items = @($json | ConvertFrom-Json -ErrorAction Stop)
                    $requests = @(foreach ($item in $items) {
                        if ($hostName -eq 'github') {
                            [pscustomobject]@{
                                Number = "$($item.number)"
                                State = if ($item.merged_at) { 'MERGED' } else { "$($item.state)".ToUpperInvariant() }
                                Merge = if ($item.merged_at) { "$($item.merge_commit_sha)" } else { '' }
                                Head = "$($item.head.sha)"; Base = "$($item.base.ref)"
                            }
                        }
                        else {
                            $mergeSha = "$($item.merge_commit_sha)"
                            if (-not $mergeSha) { $mergeSha = "$($item.squash_commit_sha)" }
                            [pscustomobject]@{
                                Number = "$($item.iid)"
                                State = switch ("$($item.state)") { 'opened' { 'OPEN' } 'merged' { 'MERGED' } 'closed' { 'CLOSED' } default { "$($item.state)".ToUpperInvariant() } }
                                Merge = $mergeSha; Head = "$($item.sha)"; Base = "$($item.target_branch)"
                            }
                        }
                    })
                    if ($requests.Count -eq 0) { $pr = '-' }
                    else {
                        $chosen = $requests[0]
                        foreach ($request in $requests) {
                            if ($request.State -eq 'MERGED' -and $request.Merge -and $request.Head -and (Test-RequestLanded $request.Merge $request.Head $default)) { $landed = 'yes'; $chosen = $request; break }
                        }
                        $prNumber = $chosen.Number; $prState = $chosen.State; $prMerge = $chosen.Merge; $prBase = $chosen.Base
                        $pr = "$prNumber $prState"
                    }
                }
                catch { $pr = 'unknown'; $prNumber = ''; $prState = ''; $prMerge = ''; $prBase = '' }
            }
        }
    }
    $merge = if ($prState -eq 'MERGED' -and $prMerge) { $prMerge } else { '-' }

    # Changelog in this checkout
    $changelogFormat = 'missing'; $changelogVersion = '-'
    $changelogFile = Join-Path $folder $policy['changelog']
    $changelogLines = @()
    if (Test-Path -LiteralPath $changelogFile -PathType Leaf) {
        $changelogLines = Read-Lines $changelogFile
        $changelogFormat = Get-ChangelogFormat $changelogLines
        $v = Get-ChangelogVersion $changelogLines
        if ($null -ne $v) {
            $prefix = if ("$release".StartsWith('v')) { 'v' } else { '' }
            $changelogVersion = "$prefix$($v.Major).$($v.Minor).$($v.Build)"
        }
    }
    $changelogBackfill = Get-ChangelogBackfill $changelogLines
    $changelogDuplicates = Get-ChangelogDuplicate $changelogLines

    # Version still free for the plan
    $renumber = '-'
    $planVersion = ConvertTo-PlanVersion $release
    if ($releasePolicy -ne 'none' -and $default -ne '-' -and $landed -ne 'yes' -and $null -ne $planVersion) {
        $found = @()
        $tagNames = if ($null -ne $originTags) { $originTags } else { @(& git tag --list 2>$null) }
        foreach ($tagName in $tagNames) {
            $v = ConvertTo-PlanVersion "$tagName"
            if ($null -ne $v) { $found += $v }
        }
        $headLines = @(& git show "origin/${default}:$($policy['changelog'])" 2>$null)
        if ($LASTEXITCODE -eq 0) {
            $v = Get-ChangelogVersion $headLines
            if ($null -ne $v) { $found += $v }
        }
        if ($found.Count -gt 0) {
            $newest = $found | Sort-Object | Select-Object -Last 1
            if ($newest -ge $planVersion) {
                $raised = if ($planVersion.Build -gt 0) { [version]::new($newest.Major, $newest.Minor, $newest.Build + 1) }
                elseif ($planVersion.Minor -gt 0) { [version]::new($newest.Major, $newest.Minor + 1, 0) }
                else { [version]::new($newest.Major + 1, 0, 0) }
                $prefix = if ($release.StartsWith('v')) { 'v' } else { '' }
                $renumber = "$prefix$($raised.Major).$($raised.Minor).$($raised.Build)"
            }
        }
    }

    # Files that conflict with the default branch
    $conflicts = '-'
    if ($default -ne '-' -and $branch -ne $default -and $landed -eq 'no') { $conflicts = if ($behind -eq '0') { 'none' } else { Get-Conflicts $default } }

    # Release published on the host
    $published = '-'
    $releaseResult = if ($releaseCall) { Receive-Concurrent $releaseCall } else { $null }
    if ($releasePolicy -eq 'tag+release' -and $tag -eq 'present') {
        $published = 'unknown'
        if ($hasCli) {
            if (-not $releaseResult) { $releaseResult = Receive-Concurrent (Start-Concurrent $folder $cli $releaseArgs) }
            $published = if ($releaseResult.ExitCode -eq 0) { 'yes' } else { 'no' }
        }
    }

    # State of the linked issue
    $issueState = '-'; $issueStates = '-'
    if ($issue -ne '-') {
        $refs = $issueRefs
        $states = @(foreach ($call in $issueCalls) { (Receive-Concurrent $call).Value })
        $issueStates = @(for ($i = 0; $i -lt $refs.Count; $i++) { "$($refs[$i])=$($states[$i])" }) -join ' '
        $issueState = if ($states -contains 'OPEN') { 'OPEN' } elseif (@($states | Where-Object { $_ -ne 'CLOSED' }).Count -eq 0) { 'CLOSED' } else { 'unknown' }
    }

    $status = (& git status --porcelain 2>$null | Out-String).Trim()
    $dirty = if ($status) { 'yes' } else { 'no' }

    # Other plan worktrees
    $others = @()
    foreach ($line in (& git worktree list --porcelain 2>$null)) {
        if ("$line" -match '^worktree (.+)$') {
            $wtPath = $Matches[1] -replace '\\', '/'
            if ($wtPath -match '/\.claude/worktrees/([^/]+)$') {
                $name = $Matches[1]
                $wtPlan = Join-Path $wtPath 'PLAN.md'
                if ($name -ne $worktree -and (Test-Path -LiteralPath $wtPlan)) {
                    $title = '-'
                    foreach ($l in (Read-Lines $wtPlan)) { if ($l -match '^# Plan:\s*(.+)$') { $title = $Matches[1].Trim(); break } }
                    $others += "$name=$title"
                }
            }
        }
    }
    $plans = if ($others) { $others -join '; ' } else { '-' }

    # Next command
    $next = $null
    if ($dirty -eq 'yes') { $next = 'none uncommitted changes: commit or discard them first' }
    elseif ($plan -ne '-') {
        if ($escalated.Count -or $failed.Count) {
            $lowest = ($escalated + $failed | ForEach-Object { [int]$_ } | Sort-Object | Select-Object -First 1)
            $next = "replan-step $lowest"
        }
        elseif ($open -gt 0) { $next = 'orchestrate-plan' }
        elseif ($total -eq 0) { $next = 'none the plan has no steps' }
        elseif ($reviewed -ne 'current') { $next = 'review-plan-diff' }
        elseif ($landed -ne 'yes') {
            if ($hostName -eq 'none') { $next = 'none no origin remote to land on' }
            elseif ($prState -eq 'OPEN' -and ($renumber -ne '-' -or $conflicts -notin '-', 'none', 'unknown')) { $next = 'ship-plan' }
            elseif ($prState -eq 'OPEN') { $next = "wait pull request #$prNumber is open: run ship-plan again once it merges" }
            elseif ($prState -eq 'MERGED' -and $integrate -eq 'direct') { $next = 'ship-plan' }
            elseif ($prState -eq 'MERGED' -and $prBase -and $prBase -ne $default) { $next = "none pull request #$prNumber merged into $prBase, not ${default}: this branch lands once $prBase reaches $default; run ship-plan again then" }
            elseif ($prState -eq 'MERGED') { $next = "none pull request #$prNumber merged without this branch's HEAD: land the commits after it from a new branch" }
            else { $next = 'ship-plan' }
        }
        elseif (($releasePolicy -ne 'none' -and $tag -ne 'present') -or $published -eq 'no' -or $issueState -eq 'OPEN' -or ($policy['follow-ups'] -ne 'none' -and $unfiled -gt 0)) { $next = 'ship-plan' }
        else { $next = 'finish-plan' }
    }
    else {
        if ($branch -ne '-' -and $branch -ne $default -and $landed -eq 'yes') { $next = 'finish-plan' }
        elseif ($plans -ne '-') {
            $names = $others | ForEach-Object { ($_ -split '=', 2)[0] }
            $next = "none no plan in this folder; open plans: $($names -join ', ')"
        }
        else { $next = 'none no plan in this folder' }
    }

    Write-Output "folder: $folder"
    Write-Output "worktree: $worktree"
    Write-Output "branch: $branch"
    Write-Output "default: $default"
    Write-Output "host: $hostName"
    Write-Output "plan: $plan"
    Write-Output "issue: $issue"
    Write-Output "refs: $related"
    Write-Output "release: $release"
    Write-Output "steps: $steps"
    Write-Output "reviewed: $reviewed"
    Write-Output "landing: $landing"
    Write-Output "protected: $protected"
    Write-Output "ahead: $ahead"
    Write-Output "behind: $behind"
    Write-Output "landed: $landed"
    Write-Output "pr: $pr"
    Write-Output "merge: $merge"
    Write-Output "tag: $tag"
    Write-Output "renumber: $renumber"
    Write-Output "conflicts: $conflicts"
    Write-Output "changelog-format: $changelogFormat"
    Write-Output "changelog-version: $changelogVersion"
    Write-Output "changelog-backfill: $changelogBackfill"
    Write-Output "changelog-duplicates: $changelogDuplicates"
    Write-Output "published: $published"
    Write-Output "issue-state: $issueState"
    Write-Output "issue-states: $issueStates"
    Write-Output "unfiled: $unfiled"
    Write-Output "dirty: $dirty"
    Write-Output "plans: $plans"
    Write-Output "next: $next"
}
finally {
    # Every call is received on the way to the output, so a call left here means the script stopped with an error.
    # Nothing reads its answer then: stop it instead of waiting for it, and ignore its own error, which the script's
    # error already outranks.
    foreach ($call in $concurrentCalls) {
        if ($call.Done) { continue }
        $call.Done = $true
        try { $call.Shell.Stop() } catch { $null = $_ }
        Close-Concurrent $call
    }
    Pop-Location
}
