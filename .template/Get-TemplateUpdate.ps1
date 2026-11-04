<#
.SYNOPSIS
    Keep one open GitHub issue that says a newer project template version is out, with its release notes.

.DESCRIPTION
    The template-update workflow (.github/workflows/template-update.yml) runs this script every week. It compares the
    project's template version, from .template-version (or _commit in .copier-answers.yml), with the newest vX.Y.Z tag
    of the template that _src_path in .copier-answers.yml names, read with git ls-remote.

    When the project is behind, it reads CHANGELOG.md at the newest tag, takes the sections after the project's
    version up to and including that tag, and keeps one open issue labeled template-update, titled
    "Update to project-template <newest tag>", with those sections: it opens the issue when there is none, and
    otherwise edits the open one (the oldest, when there are several), retitling it to the newest version. It creates
    the label when the repository lacks it. A run that would change nothing leaves the issue alone. When the newest tag
    has no CHANGELOG.md, the issue links to that release instead of listing its changes; a failure to read the template
    fails the run with Git's message.

    When the project is on the newest version, it closes the open template-update issue with a comment, and does
    nothing when there is none.

    It talks to GitHub through gh, which needs GH_TOKEN (the workflow passes GITHUB_TOKEN, with issues: write) and
    reads the repository from GH_REPO or the clone's remote. Reading the template needs no token for a public
    template.

    This file comes from the project template. Template updates replace it, so a local edit is lost.

.PARAMETER Path
    The project root. Defaults to the parent of the .template folder.

.EXAMPLE
    ./.template/Get-TemplateUpdate.ps1
#>
[CmdletBinding()]
param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$label = 'template-update'
# GitHub refuses an issue body over 65,536 characters; older sections that don't fit are left out with a link.
$bodyLimit = 60000

function ConvertTo-TemplateVersion([string]$Text) {
    if ($Text -notmatch '^v?(\d+(?:\.\d+){0,3})$') { return $null }
    $parts = @($Matches[1] -split '\.')
    while ($parts.Count -lt 3) { $parts += '0' }
    [version]($parts -join '.')
}

function Get-Answer([string]$File, [string]$Key) {
    $match = Select-String -LiteralPath $File -Pattern "^${Key}:\s*(.+?)\s*$" | Select-Object -First 1
    if ($match) { $match.Matches[0].Groups[1].Value.Trim("'", '"') }
}

# Runs git and returns what it prints; when it fails, the error says what failed and what git said, so the run's log
# tells an authentication failure from a missing tag.
function Invoke-Git([string[]]$Arguments, [string]$Failure) {
    $output = & git @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code) {
        $said = @($output | Where-Object { $_ -is [Management.Automation.ErrorRecord] } | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        throw "$Failure $(if ($said) { "Git says: $($said -join ' ')" } else { "Git exited with code $code." })"
    }
    @($output | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
}

function Invoke-Gh {
    $output = & gh @args
    if ($LASTEXITCODE) { throw "gh $($args[0]) $($args[1]) exited with code $LASTEXITCODE." }
    $output
}

# The changelog's release sections, newest first as the file has them: each heading's version and its text up to the
# next heading. The link definitions that end a Keep a Changelog file are left out.
function Get-ChangelogSection([string]$Changelog) {
    $sections = [Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $Changelog.Replace("`r`n", "`n") -split "`n") {
        if ($line -match '^## ') {
            $current = $null
            if ($line -match '^## \[?v?(\d+\.\d+\.\d+)\]?(?:\s.*)?$') {
                $current = [pscustomobject]@{ Version = [version]$Matches[1]; Lines = [Collections.Generic.List[string]]::new() }
                $sections.Add($current)
            }
        }
        elseif ($line -match '^\[[^\]]+\]:\s*\S') { $current = $null }
        if ($current) { $current.Lines.Add($line) }
    }
    foreach ($section in $sections) { [pscustomobject]@{ Version = $section.Version; Text = ($section.Lines -join "`n").Trim() } }
}

$project = (Resolve-Path -LiteralPath $Path).Path
$answersFile = Join-Path $project '.copier-answers.yml'
if (-not (Test-Path -LiteralPath $answersFile)) { throw "$project has no .copier-answers.yml, so it wasn't created from the template." }
$versionFile = Join-Path $project '.template-version'
$currentText = if (Test-Path -LiteralPath $versionFile) { "$(Get-Content -LiteralPath $versionFile -TotalCount 1)".Trim() } else { Get-Answer $answersFile '_commit' }
# A version between tags, such as v0.12.0-3-gabc1234, is the tag before the first dash.
$currentTag = "$currentText" -replace '-.*$'
$current = ConvertTo-TemplateVersion $currentTag
if (-not $current) { throw "Can't read the project's template version from .template-version ('$currentText')." }

$src = Get-Answer $answersFile '_src_path'
if (-not $src) { throw '.copier-answers.yml has no _src_path, the address of the template.' }
# Copier's shorthands, and the template's old address, which GitHub only redirects. Update-Project.ps1 moves a project
# off the same old address; change both together.
if ($src -match '^gh:(.+)$') { $src = "https://github.com/$($Matches[1])" }
elseif ($src -match '^gl:(.+)$') { $src = "https://gitlab.com/$($Matches[1])" }
if ($src -match '^https://github\.com/polewskm/project-template(?:\.git)?/?$') { $src = 'https://github.com/NCodeGroup/project-template.git' }
$web = if ($src -match '^https://github\.com/([^/]+/[^/]+?)(?:\.git)?/?$') { "https://github.com/$($Matches[1])" }

$outputEncoding = [Console]::OutputEncoding
$scratch = Join-Path ([IO.Path]::GetTempPath()) "template-update-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    # Read Git's output as UTF-8, so the release notes keep their characters.
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { Write-Verbose "Couldn't set the console's output encoding: $_" }

    $refs = Invoke-Git ('ls-remote', '--tags', '--refs', '--', $src) "Can't read the project template's tags at $src."
    $tags = @(foreach ($ref in $refs) {
            if ($ref -match 'refs/tags/(.+)$') {
                $version = ConvertTo-TemplateVersion $Matches[1]
                if ($version) { [pscustomobject]@{ Tag = $Matches[1]; Version = $version } }
            }
        })
    if (-not $tags) { throw "The template at $src has no version tags." }
    $newest = $tags | Sort-Object Version | Select-Object -Last 1
    $open = @(Invoke-Gh issue list --label $label --state open --json 'number,title,body' --limit 100 | ConvertFrom-Json | Sort-Object number)
    $issue = $open | Select-Object -First 1

    if ($newest.Version -le $current) {
        if (-not $issue) { "The project is on project-template $currentTag, the newest version."; return }
        Invoke-Gh issue close $issue.number --comment "The project is on project-template $currentTag, the newest version, so this issue is done. The template-update workflow opens a new one when a newer version comes out." | Out-Null
        "Closed #$($issue.number): the project is on project-template $currentTag, the newest version."
        return
    }

    New-Item -ItemType Directory -Force $scratch | Out-Null
    Invoke-Git ('-C', $scratch, 'init', '--quiet') "Can't create a scratch repository in $scratch." | Out-Null
    Invoke-Git ('-C', $scratch, 'fetch', '--quiet', '--depth', '1', '--', $src, "refs/tags/$($newest.Tag)") "Can't fetch $($newest.Tag) from the project template at $src." | Out-Null
    # A tag without CHANGELOG.md gets an issue that links to the release; any other failure to read it fails the run,
    # so a transient error never replaces a good issue body.
    $hasChangelog = [bool](Invoke-Git ('-C', $scratch, 'ls-tree', '--name-only', 'FETCH_HEAD', '--', 'CHANGELOG.md') "Can't list the files of $($newest.Tag) from the project template at $src.")
    $changelog = ''
    if ($hasChangelog) {
        $changelog = (Invoke-Git ('-C', $scratch, 'show', 'FETCH_HEAD:CHANGELOG.md') "Can't read CHANGELOG.md at $($newest.Tag) from the project template at $src.") -join "`n"
    }
    else { Write-Warning "The project template has no CHANGELOG.md at $($newest.Tag), so the issue links to the release instead of listing its changes." }

    $behind = @($tags | Where-Object { $_.Version -gt $current -and $_.Version -le $newest.Version }).Count
    $sections = @(Get-ChangelogSection $changelog | Where-Object { $_.Version -gt $current -and $_.Version -le $newest.Version })
    $notes = if ($web) { "[CHANGELOG.md]($web/blob/$($newest.Tag)/CHANGELOG.md)" } else { "CHANGELOG.md at $($newest.Tag) in $src" }
    $versions = if ($behind -eq 1) { 'one version' } else { "$behind versions" }
    $title = "Update to project-template $($newest.Tag)"
    $head = @(
        "This project is on project-template $currentTag. The newest version is $($newest.Tag), $versions later."
        ''
        "Plan the update with ``/plan-issue`` and this issue's number, which plans it as ``/plan-template-update $($newest.Tag)`` does, or run ``.\.template\Update-Project.ps1`` on a branch of its own."
        ''
        "The template-update workflow keeps this issue current every week: it retitles it and rewrites this text when a newer version comes out, and closes it once the project is on the newest version."
        ''
        "## Changes since $currentTag"
        ''
        ''
    ) -join "`n"
    $body = $head
    if (-not $hasChangelog) {
        $release = if ($web) { "[the $($newest.Tag) release]($web/releases/tag/$($newest.Tag))" } else { "the $($newest.Tag) release of $src" }
        $body += "The project template has no CHANGELOG.md at $($newest.Tag); read $release."
    }
    elseif (-not $sections) { $body += "The release notes have no section for these versions; read $notes." }
    for ($i = 0; $i -lt $sections.Count; $i++) {
        $text = "$($sections[$i].Text)`n`n"
        if ($body.Length + $text.Length -gt $bodyLimit) {
            $body += if ($i -eq 0) { "The release notes for these versions don't fit in an issue; read them in $notes." }
            else { "The $($sections.Count - $i) older section(s) don't fit in an issue; read them in $notes." }
            break
        }
        $body += $text
    }
    $body = $body.TrimEnd() + "`n"

    if ($issue -and $issue.title -eq $title -and "$($issue.body)".Replace("`r`n", "`n").TrimEnd() -eq $body.TrimEnd()) {
        "#$($issue.number) already says: $title."
        return
    }
    $bodyFile = Join-Path $scratch 'issue.md'
    [IO.File]::WriteAllText($bodyFile, $body, [Text.UTF8Encoding]::new($false))
    if ($issue) {
        Invoke-Gh issue edit $issue.number --title $title --body-file $bodyFile | Out-Null
        "Updated #$($issue.number): $title."
        return
    }
    $labels = @(Invoke-Gh label list --search $label --json name --limit 100 | ConvertFrom-Json | ForEach-Object name)
    if ($label -notin $labels) {
        Invoke-Gh label create $label --description 'A newer version of the project template is out' --color 1D76DB | Out-Null
    }
    $url = Invoke-Gh issue create --title $title --label $label --body-file $bodyFile
    "Opened $(@($url)[-1]): $title."
}
finally {
    try { [Console]::OutputEncoding = $outputEncoding } catch { Write-Verbose "Couldn't restore the console's output encoding: $_" }
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
