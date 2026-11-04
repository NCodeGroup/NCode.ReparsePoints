<#
.SYNOPSIS
    Update this project to the newest version of the project template it was created from, and commit it.

.DESCRIPTION
    Every project carries this script as .template\Update-Project.ps1. The template owns it, so an update replaces
    it like the template's other files. It updates the project it sits in, or -Path.

    It clones the template from the address in .copier-answers.yml, so no template clone is needed. When the
    target version's copy of this script differs from this one, it hands the update over to that copy: the
    newest update logic always does the update, including replacing this file.

    Every file in the project has one of three owners (copier.yml, and the template README's "What a Project Gets"):

      Template-owned  Replaced by the new version. A local edit to one is discarded and a deleted one is
                      restored; the script lists both. A template-owned file that an earlier version's
                      _skip_if_exists kept from updates, such as docs/decisions/project-template/README.md, is
                      reset first, discarding a local edit, and listed as refreshed.
      Merged          Files whose tools can't include a second file (copier.yml's _merged_files). The template's
                      changes are merged with the project's edits, like a Git merge; the same lines changed on
                      both sides conflict. An adopted project's own lines at the end of .gitignore,
                      .gitattributes and .editorconfig are set aside while Copier merges, so they never
                      conflict.
      Project-owned   Written once, never touched again (copier.yml's _skip_if_exists). When the template changed
                      one since the project's version, the script shows the template's change, rendered with
                      the project's answers, leaving out what the project's file already has.
                      A merged or template-owned file that the project's project_owned_files answer names
                      is project-owned too; a project that replaced one sets it with -Data @{ project_owned_files
                      = '.github/workflows/ci.yml', 'build/dod.ps1' }. The answer can name any file the version
                      the update moves to renders, except .copier-answers.yml, .template-version and the files in
                      .template/; any other name stops the update before it changes anything.
                      When the template changed a merged file that shares less than half its lines with the
                      template's version, the script suggests that answer, with the -Data to run;
                      it doesn't stop the update. When Copier can't render the project's version, it warns
                      with Copier's error and says it skipped the suggestion.
                      When the update stops on a conflict in a file the version it moves to owns, such
                      as a build/dod.ps1 of the project's own that the template now adds, it suggests
                      the answer the same way, naming that file too.

    The update runs `copier recopy` at the project's current template version, which resets the template-owned
    files and shows any local edits, then `copier update --defaults` to the newest version (or -Ref), which merges
    the merged files and adds and deletes template files as the template did. Copier runs from PATH or through uvx.

    Without conflicts the result is one commit, "Update from project-template <version>"; -NoCommit stages it
    instead. Either way it exits 0, as it does when there is nothing to update. With a conflict it commits nothing,
    says how to finish or abandon the update, and exits 1; each file without a conflict is then either unstaged or
    staged as it is in the working tree. On any other failure the project is reset to where it was.

    On the default branch (the branch origin/HEAD names) it refuses to run unless -NoCommit is given, because it
    commits. It enables the template's hooks (core.hooksPath .githooks) unless the clone already has a hooks path,
    hooks in .git/hooks, or uses pre-commit; then it leaves them as they are and warns, naming the command that runs
    the template's hooks, or says nothing when core.hooksPath names a .githooks folder, or when
    .pre-commit-config.yaml runs .githooks/commit-msg. With protect: hook in AGENTS.md's Landing section, it also says
    how to run .githooks/pre-push there.

    When the project has version tags merged into HEAD that the changelog (AGENTS.md's Landing changelog key,
    CHANGELOG.md by default) has no section for, it ends with a /plan-migration request to backfill them.

    Every version of this script accepts -Path, -Ref, -Data, -NoCommit, -TemplateClone and -HandedOff, so any
    version can hand over to any later one.

.EXAMPLE
    .\.template\Update-Project.ps1
    .\.template\Update-Project.ps1 -NoCommit
    .\.template\Update-Project.ps1 -Ref v0.3.0
#>
[CmdletBinding()]
param(
    [string]$Path = (Split-Path $PSScriptRoot),
    [string]$Ref,
    [hashtable]$Data = @{},
    [switch]$NoCommit,
    # Set by the version that hands the update over; not for direct use.
    [string]$TemplateClone,
    [switch]$HandedOff
)
$ErrorActionPreference = 'Stop'

# Copier says "Make sure Git >= 2.24 is installed" whenever Git rejects `diff-tree --inter-hunk-context=-1`,
# which Git 2.55 and later always do (copier-org/copier#2759), so the filter swaps in an accurate note.
function Invoke-Copier {
    $gitNote = 'Copier''s "Make sure Git >= 2.24 is installed" is a false alarm: Git 2.55 and later reject an option its update uses, so Copier falls back, and nearby changes to a merged file may conflict as one block (copier-org/copier#2759).'
    $ErrorActionPreference = 'Continue'   # Copier's stderr lines arrive as error records through 2>&1
    $prefix = @()
    $command = if (Get-Command copier -ErrorAction SilentlyContinue) { 'copier' }
    elseif (Get-Command uvx -ErrorAction SilentlyContinue) { $prefix = '--from', 'copier', 'copier'; 'uvx' }
    else { throw 'Copier not found. Install it with: uv tool install copier' }
    & $command @prefix @args 2>&1 | ForEach-Object { if ("$_" -match 'Make sure Git >= 2\.24 is installed') { $gitNote } else { "$_" } }
    if ($LASTEXITCODE) { throw "copier $($args[0]) exited with code $LASTEXITCODE." }
}

# Copier reads --data values as YAML, so a list answer goes as a flow sequence: [claude, copilot].
function ConvertTo-CopierValue($Value) {
    if ($Value -is [Collections.IList]) { '[' + ($Value -join ', ') + ']' } else { "$Value" }
}

# Render the template at a version into a folder with the project's answers;
# false, with a warning that says why, when Copier can't.
function Invoke-TemplateRender([string]$Version, [string]$Folder) {
    $renderArgs = @('copy', '--defaults', '--quiet', '--vcs-ref', $Version, '--data-file', (Join-Path $project '.copier-answers.yml'))
    foreach ($k in $Data.Keys) { $renderArgs += '--data', "$k=$(ConvertTo-CopierValue $Data[$k])" }
    $copierOutput = [Collections.Generic.List[string]]::new()
    try { Invoke-Copier @renderArgs $TemplateClone $Folder | ForEach-Object { $copierOutput.Add("$_") }; $true }
    catch { Write-Warning ((@("Copier couldn't render template $Version with this project's answers: $_") + $copierOutput) -join "`n"); $false }
}

function Get-Answer([string]$Key) {
    $match = Select-String -LiteralPath .copier-answers.yml -Pattern "^${Key}:\s*(.+?)\s*$" | Select-Object -First 1
    if ($match) { $match.Matches[0].Groups[1].Value.Trim("'", '"') }
}

# A list answer from .copier-answers.yml, which Copier writes as "key:" and then one "- item" line each.
function Get-AnswerList([string]$Key) {
    $inList = $false
    foreach ($line in Get-Content -LiteralPath .copier-answers.yml) {
        if ($line -match "^${Key}:\s*$") { $inList = $true; continue }
        if ($inList -and $line -match '^\s*-\s+(.+?)\s*$') { $Matches[1].Trim("'", '"') }
        elseif ($inList) { break }
    }
}

# A file list from the template's copier.yml at a version, or at the clone's HEAD when that version isn't in it.
function Get-TemplateList([string]$Repo, [string]$Version, [string]$Key) {
    $yaml = git -C $Repo show "${Version}:copier.yml" 2>$null
    if ($LASTEXITCODE) { $yaml = git -C $Repo show HEAD:copier.yml }
    $inList = $false
    foreach ($line in $yaml) {
        if ($line -match "^${Key}:") { $inList = $true; continue }
        if ($inList -and $line -match '^\s+-\s+(.+?)\s*$') { $Matches[1].Trim("'", '"') }
        elseif ($inList -and $line -match '^\S') { break }
    }
}

# Whether a project file matches one of Copier's file patterns, which Copier reads like .gitignore. A pattern with a / names the file from the project root, and one without names a file of that name in any folder.
function Test-CopierPattern([string]$File, [string[]]$Pattern) {
    foreach ($p in $Pattern) {
        if ($p.Contains('/')) { if ($File -ceq $p.TrimStart('/')) { return $true } }
        elseif (($File -split '/')[-1] -ceq $p) { return $true }
    }
    $false
}

# A template source's name as in a project: without template/, each Jinja tag and the .jinja suffix.
function ConvertTo-ProjectName([string]$Source) {
    $Source -replace '^template/' -replace ('\{' + '%.*?%' + '\}') -replace '\.jinja$'
}

# Whether a project can own a file the template renders: any but the update's own files. tests/Test-Adoption.ps1 checks that Get-OwnableFile in tools/adopt/Adoption.psm1 follows the same rule.
function Test-OwnableName([string]$Name) {
    $Name -notmatch '^\.template/' -and -not $Name.Contains('{') -and $Name -notin '.copier-answers.yml', '.template-version'
}

# The files the template renders at a version, named as in a project. A file whose name holds a condition is listed whatever the answers.
function Get-RenderedFile([string]$Repo, [string]$Version) {
    foreach ($source in git -C $Repo ls-tree -r --name-only $Version -- template/) { ConvertTo-ProjectName $source }
}

# The newest version tag, as Copier picks it: v1.2.3 or 1.2.3, prereleases ignored.
function Get-NewestTag([string]$Repo) {
    git -C $Repo tag --list | Where-Object { $_ -match '^v?\d+(\.\d+){0,3}$' } |
        Sort-Object { $v = $_ -replace '^v'; if ($v -notmatch '\.') { $v += '.0' }; [version]$v } | Select-Object -Last 1
}

function Get-Change {
    foreach ($line in git status --porcelain --untracked-files=all) {
        $code = $line.Substring(0, 2)
        $file = $line.Substring(3)
        if ($file -eq '.copier-answers.yml') { continue }
        $kind = if ($code -match 'U' -or $code -in 'AA', 'DD') { 'conflict' }
        elseif ($code -eq '??' -or $code[0] -eq 'A') { 'added' }
        elseif ($code -match 'D') { 'deleted' }
        elseif ($code -match 'R') { 'renamed' }
        else { 'modified' }
        [pscustomobject]@{ Kind = $kind; File = $file }
    }
}

# True when the project's file already has a hunk of the template's change: the hunk applies to it in reverse.
function Test-HunkApplied([string]$File, [string[]]$Hunk, [string]$Folder) {
    $patch = Join-Path $Folder 'hunk.patch'
    [IO.File]::WriteAllText($patch, ((@("--- a/$File", "+++ b/$File") + $Hunk) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    git apply --check --reverse -- $patch 2>$null
    -not $LASTEXITCODE
}

# The fraction of the project file's distinct, trimmed, non-blank lines that the template's file also has; 1 for a file with none.
function Get-SharedLineFraction([string]$Project, [string]$Template) {
    $templateLines = [Collections.Generic.HashSet[string]]::new([string[]]@($Template -split '\r?\n' | ForEach-Object Trim | Where-Object { $_ }))
    $projectLines = @($Project -split '\r?\n' | ForEach-Object Trim | Where-Object { $_ } | Select-Object -Unique)
    if (-not $projectLines.Count) { return 1.0 }
    [double]@($projectLines | Where-Object { $templateLines.Contains($_) }).Count / $projectLines.Count
}

# The files, of those given, that share less than half their lines with the template's render of them in $Folder, leaving out the lines an adopted file keeps under its "# Kept from" comment.
function Get-RewrittenFile([string[]]$Files, [string]$Folder) {
    foreach ($file in $Files) {
        $rendered = Join-Path $Folder $file
        if (-not (Test-Path -LiteralPath $rendered -PathType Leaf)) { continue }
        $text = [regex]::Split([IO.File]::ReadAllText((Join-Path $project $file)), "(?m)^# Kept from this repository's own \S+ when it adopted the project template\r?$")[0]
        if ((Get-SharedLineFraction $text ([IO.File]::ReadAllText($rendered))) -lt 0.5) { $file }
    }
}

# How to run the template's .githooks in this clone: HooksPath when core.hooksPath can point at it, otherwise the
# Note to warn with. A hooks path turns off the hooks in .git/hooks, and pre-commit won't install while one is set, so
# a clone that uses pre-commit gets a local pre-commit hook to add instead, and no note once its config runs it.
# A hooks path the clone already has, from any Git config, is never changed: one that names a .githooks folder runs the
# template's hooks, and any other, such as husky's or a global hooks folder, gets a note naming the command to run.
# With "- protect: hook" in AGENTS.md's Landing section, it also says how to run .githooks/pre-push until something does.
# This is a deliberate copy of Get-GitHooksSetup in the template's tools/adopt/Adoption.psm1, not shared code: this
# script runs on its own, from an older template's copy. Change both together, or Update and Adopt can decide
# differently for the same clone; tests/Test-GitHooks.ps1 runs both copies through the same cases.
function Get-GitHooksSetup {
    $config = '.pre-commit-config.yaml'
    $hooksDir = git rev-parse --path-format=absolute --git-path hooks
    $hooksRel = git rev-parse --git-path hooks
    $ownHooks = @(Get-ChildItem -LiteralPath $hooksDir -File -ErrorAction SilentlyContinue | Where-Object Extension -NE '.sample')
    $preCommit = (Test-Path -LiteralPath $config) -or [bool]($ownHooks | Select-String -SimpleMatch 'File generated by pre-commit' -List)

    # The value of the "- protect:" line in AGENTS.md's Landing section, when it has one.
    $protect = $null
    if (Test-Path -LiteralPath AGENTS.md) {
        $inLanding = $false
        foreach ($line in Get-Content -LiteralPath AGENTS.md) {
            if ($line -match '^## Landing\s*$') { $inLanding = $true; continue }
            if ($inLanding -and $line -match '^## ') { break }
            if ($inLanding -and $line -match '^- protect:\s*(\S+)') { $protect = $Matches[1]; break }
        }
    }

    $current = git config --get core.hooksPath
    if ($current) {
        if ((Split-Path -Leaf $current.TrimEnd('\', '/')) -eq '.githooks') { return [pscustomobject]@{ HooksPath = $false; Note = $null } }
        $push = if ($protect -eq 'hook') { ', or .githooks/pre-push, which refuses a push to the default branch as AGENTS.md''s Landing section says (protect: hook)' } else { '' }
        $call = if ($protect -eq 'hook') { "call .githooks/commit-msg from $current/commit-msg and .githooks/pre-push from $current/pre-push" } else { "call .githooks/commit-msg from $current/commit-msg" }
        return [pscustomobject]@{ HooksPath = $false; Note = "Git hooks: .githooks not enabled. core.hooksPath is already $current (git config --show-origin core.hooksPath says where it's set), so Git never runs .githooks/commit-msg, which strips AI agent attribution from commit messages$push. To run both, $call. To run the template's hooks instead, run: git config core.hooksPath .githooks" }
    }

    # True when the clone's pre-push hook, or the pre-push.legacy that pre-commit runs first, calls .githooks/pre-push.
    $pushRuns = $false
    foreach ($name in 'pre-push', 'pre-push.legacy') {
        $file = Join-Path $hooksDir $name
        if ((Test-Path -LiteralPath $file) -and (Select-String -LiteralPath $file -SimpleMatch '.githooks/pre-push' -Quiet)) { $pushRuns = $true }
    }

    $parts = @()
    if ($preCommit -and -not ((Test-Path -LiteralPath $config) -and (Select-String -LiteralPath $config -SimpleMatch '.githooks/commit-msg' -Quiet))) {
        $parts += @('Git hooks: .githooks not enabled. This clone uses pre-commit, which won''t install its hooks while core.hooksPath is set. To run .githooks/commit-msg through pre-commit, add this hook to the repos list in .pre-commit-config.yaml, then run: pre-commit install --hook-type commit-msg',
            '  - repo: local', '    hooks:', '      - id: strip-agent-attribution', '        name: strip agent attribution', '        entry: .githooks/commit-msg', '        language: script', '        stages: [commit-msg]') -join "`n"
    }
    elseif (-not $preCommit -and $ownHooks) {
        $parts += "Git hooks: .githooks not enabled. This clone has hooks of its own in .git/hooks ($(($ownHooks | ForEach-Object Name) -join ', ')), and core.hooksPath would turn them off. To run both, call .githooks/commit-msg from your commit-msg hook, or move your hooks into .githooks and run: git config core.hooksPath .githooks"
    }
    if (($preCommit -or $ownHooks) -and $protect -eq 'hook' -and -not $pushRuns) {
        $pushHook = Join-Path $hooksDir 'pre-push'
        $lead = 'Git hooks: AGENTS.md''s Landing section says protect: hook, but nothing runs .githooks/pre-push in this clone.'
        if ((Test-Path -LiteralPath $pushHook) -and -not (Select-String -LiteralPath $pushHook -SimpleMatch 'File generated by pre-commit' -Quiet)) {
            $parts += "$lead Call .githooks/pre-push from $hooksRel/pre-push with the same arguments and standard input, and refuse the push when it fails."
        }
        elseif ((Test-Path -LiteralPath $pushHook) -and (Test-Path -LiteralPath (Join-Path $hooksDir 'pre-push.legacy'))) {
            # pre-commit moved a hook of the clone's own aside as pre-push.legacy, so the wrapper must not replace it.
            $parts += "$lead Call .githooks/pre-push from $hooksRel/pre-push.legacy with the same arguments and standard input, and refuse the push when it fails."
        }
        else {
            $legacy = Test-Path -LiteralPath $pushHook
            $target = if ($legacy) { "$hooksRel/pre-push.legacy" } else { "$hooksRel/pre-push" }
            $aside = if ($legacy) { ' (pre-commit''s own pre-push hook runs it first, with the same arguments and refs)' } else { '' }
            $parts += @("$lead pre-commit's pre-push stage checks only one of the refs a push updates, so run the hook from Git: save these two lines as $target$aside and, on Linux or macOS, run: chmod +x $target",
                '#!/usr/bin/env sh', 'exec .githooks/pre-push "$@"') -join "`n"
        }
    }
    [pscustomobject]@{ HooksPath = -not $preCommit -and -not $ownHooks; Note = if ($parts) { $parts -join "`n" } else { $null } }
}

# The changelog AGENTS.md's Landing section names (CHANGELOG.md by default) as File, and as Range the version tags merged into HEAD
# that have no release heading in it: <oldest>..<newest>, the tag alone, or -. .template/Get-PlanState.ps1 prints Range as changelog-backfill.
# This is a deliberate copy of that logic, not shared code: Update-Project.ps1 runs on its own, from an older template's copy, before any workflow script exists to dot-source.
# Change the release-heading pattern and the merged-tag filter in both places, or the request printed here can disagree with changelog-backfill.
function Get-ChangelogBackfill {
    $file = 'CHANGELOG.md'
    if (Test-Path -LiteralPath AGENTS.md) {
        $inLanding = $false
        foreach ($line in Get-Content -LiteralPath AGENTS.md) {
            if ($line -match '^## Landing\s*$') { $inLanding = $true; continue }
            if ($inLanding -and $line -match '^## ') { break }
            if ($inLanding -and $line -match '^- changelog:\s*`?([^`\s]+)') { $file = $Matches[1]; break }
        }
    }
    $listed = @(if (Test-Path -LiteralPath $file -PathType Leaf) { foreach ($line in Get-Content -LiteralPath $file) { if ($line -match '^## \[?v?(\d+\.\d+\.\d+)\]?(?: - \d{4}-\d{2}-\d{2})?(?: \[YANKED\])?\s*$') { [version]$Matches[1] } } })
    $missing = @(git tag --list --merged HEAD 2>$null | Where-Object { $_ -match '^v?(\d+\.\d+\.\d+)$' -and [version]$Matches[1] -notin $listed } | Sort-Object { [version]($_ -replace '^v') })
    $range = if ($missing.Count -eq 0) { '-' } elseif ($missing.Count -eq 1) { $missing[0] } else { "$($missing[0])..$($missing[-1])" }
    [pscustomobject]@{ File = $file; Range = $range }
}

$project = (Resolve-Path -LiteralPath $Path).Path
$ownClone = -not $TemplateClone
$scratch = Join-Path ([IO.Path]::GetTempPath()) "project-template-update-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$outputEncoding = [Console]::OutputEncoding
Push-Location -LiteralPath $project
try {
    # Read Git's output as UTF-8, so file contents and diffs keep their characters.
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { Write-Verbose "Couldn't set the console's output encoding: $_" }
    if (-not (Test-Path -LiteralPath .copier-answers.yml)) { throw "$project has no .copier-answers.yml, so it wasn't created from the template." }
    if (git status --porcelain) { throw "$project has uncommitted changes. Commit or stash them first." }
    $head = git rev-parse HEAD
    $from = Get-Answer '_commit'
    $src = Get-Answer '_src_path'
    # The template moved from polewskm/project-template to NCodeGroup/project-template. A project whose answers still name the old
    # address moves over with this update, so it stops depending on GitHub's redirect. Only the _src_path line changes, and the
    # update commits it with everything else. Get-TemplateUpdate.ps1 reads the same old address for the weekly notice;
    # change both together.
    $movedSource = 'https://github.com/NCodeGroup/project-template.git'
    if ($src -match '^https://github\.com/polewskm/project-template(?:\.git)?/?$') {
        $answersFile = Join-Path $project '.copier-answers.yml'
        $answersText = [IO.File]::ReadAllText($answersFile)
        [IO.File]::WriteAllText($answersFile, [regex]::Replace($answersText, '(?m)^_src_path:[^\r\n]*', "_src_path: $movedSource"), [Text.UTF8Encoding]::new($false))
        $src = $movedSource
        "The template moved to $movedSource; .copier-answers.yml now names it."
    }

    if ($ownClone) {
        $TemplateClone = Join-Path ([IO.Path]::GetTempPath()) "project-template-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        # A full clone: Copier renders versions from it and can't clone a blob-filtered clone; the template is small.
        git clone --quiet --no-checkout -- $src $TemplateClone 2>$null
        if ($LASTEXITCODE) { throw "Can't read the project template at $src. Updating needs read access to it; for its owner, Git's credentials (gh auth setup-git). Without access the project still works as it is: only template updates are unavailable." }
    }
    $to = if ($Ref) { $Ref } else { Get-NewestTag $TemplateClone }
    if (-not $to) { throw "The template at $src has no version tags." }

    # The update commits, and the default branch may accept changes only through pull requests.
    $branch = git branch --show-current
    $defaultRef = git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null
    $originBranch = if ($branch -in 'main', 'master') { git rev-parse --quiet --verify "refs/remotes/origin/$branch" 2>$null }
    $default = if ($defaultRef) { $defaultRef -replace '^origin/' } elseif ($originBranch) { $branch }
    if ($branch -and $branch -eq $default -and -not $NoCommit) { throw "$project is on $branch, its default branch, and the update commits. Update on a branch of its own: git switch -c build/project-template-$to — or stage the update here with -NoCommit." }

    # Hand over to the target version's copy of this script when it differs, so the newest update logic runs.
    # git show, not git checkout: checkout doesn't fetch the file in a blob-filtered clone, but show does.
    if (-not $HandedOff) {
        $nextText = (git -C $TemplateClone show "${to}:template/.template/Update-Project.ps1" 2>$null) -join "`n"
        if (-not $LASTEXITCODE -and $nextText -and $nextText.TrimEnd() -ne [IO.File]::ReadAllText($PSCommandPath).Replace("`r`n", "`n").TrimEnd()) {
            New-Item -ItemType Directory -Force $scratch | Out-Null
            $next = Join-Path $scratch 'Update-Project.ps1'
            [IO.File]::WriteAllText($next, "$nextText`n", [Text.UTF8Encoding]::new($false))
            "Handing the update over to the $to version of Update-Project.ps1."
            & $next -Path $project -Ref $to -Data $Data -NoCommit:$NoCommit -TemplateClone $TemplateClone -HandedOff
            exit $LASTEXITCODE
        }
    }

    $skipFrom = @(Get-TemplateList $TemplateClone $from '_skip_if_exists')
    $projectOwned = @($skipFrom | ForEach-Object { $_.TrimStart('/') })
    $skipTo = @(Get-TemplateList $TemplateClone $to '_skip_if_exists')
    $merged = @(Get-TemplateList $TemplateClone $from '_merged_files')
    # Files the project owns (its project_owned_files answer), merged or template-owned: updates leave them alone and show the template's change, as for project-owned files.
    # -Data wins, because this update records it, and a single file becomes the list the answer must be.
    if ($Data.ContainsKey('project_owned_files')) { $Data['project_owned_files'] = @($Data['project_owned_files'] | Where-Object { $_ } | Select-Object -Unique) }
    $ownedFiles = @(if ($Data.ContainsKey('project_owned_files')) { $Data['project_owned_files'] } else { Get-AnswerList 'project_owned_files' })
    # Checked against the version the update moves to, so a file that version first adds or merges can be owned from this update on; the update's own files can't be.
    $ownable = @(Get-RenderedFile $TemplateClone $to | Where-Object { Test-OwnableName $_ })
    $notOwnable = @($ownedFiles | Where-Object { $_ -notin $ownable })
    if ($notOwnable) { throw "project_owned_files names $($notOwnable -join ', '), which template $to doesn't render or the update itself needs. It can name any file template $to renders except .copier-answers.yml, .template-version and the files in .template/." }
    # A merged file the project rewrote shares few lines with the template's render of it, so the template's changes to it conflict in unrelated places (copier-org/copier#2759): suggest the project_owned_files answer. Only a file the template changed can conflict.
    $rewritten = @()
    $fromRendered = $null
    $renderedFrom = Join-Path $scratch 'rendered\from'
    if ($from -ne $to) {
        try {
            $changedMerged = @(foreach ($source in git -C $TemplateClone diff --name-only $from $to -- template/ 2>$null) {
                    $file = ConvertTo-ProjectName $source
                    if ($file -in $merged -and $file -notin $ownedFiles -and (Test-Path -LiteralPath $file -PathType Leaf)) { $file }
                })
            # A renamed template source, such as one that gained .jinja, lists its file under both names: keep each file once.
            $changedMerged = @($changedMerged | Select-Object -Unique)
            if ($changedMerged) { $fromRendered = Invoke-TemplateRender $from $renderedFrom }
            if ($fromRendered) { $rewritten = @(Get-RewrittenFile $changedMerged $renderedFrom) }
            elseif ($changedMerged) { Write-Warning "Skipped the rewritten-file suggestion: without template $from rendered, the update can't tell which merged files this project rewrote." }
        }
        catch {
            Write-Warning "Skipped the rewritten-file suggestion: checking for merged files this project rewrote failed: $_"
            $rewritten = @()
        }
    }
    try {
        # Reset the template-owned files to the project's current version; what changes was edited or deleted here. A file the project owns is left out, so its copy is never overwritten.
        $exclude = foreach ($file in $projectOwned + $merged + $ownedFiles) { '--exclude', "/$file" }
        Invoke-Copier recopy --force --quiet --vcs-ref :current: @exclude
        $reset = @(Get-Change)
        # A template-owned file that the project's version skips only through a name without a /, which Copier matches in every folder,
        # and that the target version doesn't skip, was never updated, such as docs/decisions/project-template/README.md. Reset it to the
        # project's version, as the recopy does the other template-owned files; after $reset, so it is listed as refreshed, not as an edit.
        $stale = @(Get-RenderedFile $TemplateClone $from | Select-Object -Unique | Where-Object { (Test-CopierPattern $_ $skipFrom) -and $_ -notin $projectOwned -and -not (Test-CopierPattern $_ $skipTo) -and $_ -notin $merged -and $_ -notin $ownedFiles -and (Test-Path -LiteralPath $_ -PathType Leaf) })
        $refreshed = @()
        if ($stale) {
            if ($null -eq $fromRendered) { $fromRendered = Invoke-TemplateRender $from $renderedFrom }
            if ($fromRendered) {
                $refreshed = @(foreach ($file in $stale) {
                        $src = Join-Path $renderedFrom $file
                        $dst = Join-Path $project $file
                        if ((Test-Path -LiteralPath $src -PathType Leaf) -and [IO.File]::ReadAllText($src) -ne [IO.File]::ReadAllText($dst)) { Copy-Item -LiteralPath $src -Destination $dst -Force; $file }
                    })
            }
            else { Write-Warning "Skipped refreshing $($stale -join ', '): without template $from rendered, the update can't reset them." }
        }
        # The template's Adopt-Project.ps1 ends these files with the repository's own lines under a "# Kept from …" comment. Set them aside while
        # Copier merges, so a template change to the file's last lines can't conflict with them or take them into its conflict.
        $keptLines = @{}
        foreach ($file in '.gitignore', '.gitattributes', '.editorconfig') {
            if ($file -notin $merged -or $file -in $ownedFiles -or -not (Test-Path -LiteralPath $file)) { continue }
            $text = [IO.File]::ReadAllText((Join-Path $project $file))
            $match = [regex]::Match($text, "(?m)^# Kept from this repository's own \S+ when it adopted the project template\r?$")
            if (-not $match.Success) { continue }
            $templatePart = $text.Substring(0, $match.Index).TrimEnd("`r", "`n")
            $keptLines[$file] = $text.Substring($templatePart.Length)
            [IO.File]::WriteAllText((Join-Path $project $file), "$templatePart`n")
        }
        $resetFiles = @()
        $resetCommitted = [bool](git status --porcelain)
        if ($resetCommitted) { git add -A; git commit -q --no-verify -m 'Reset template-owned files'; if ($LASTEXITCODE) { throw 'Committing the reset failed.' } }

        $copierArgs = @('update', '--defaults', '--quiet', '--vcs-ref', $to)
        foreach ($k in $Data.Keys) { $copierArgs += '--data', "$k=$(ConvertTo-CopierValue $Data[$k])" }
        # A project-owned file the project deleted stays deleted; Copier would otherwise create it again.
        $deleted = $projectOwned | Where-Object { -not (Test-Path -LiteralPath $_) -and (git log --diff-filter=D --format=%h -1 -- $_) }
        foreach ($file in $deleted) { $copierArgs += '--exclude', "/$file" }
        # A file the project owns, merged or template-owned, stays as it is; its template change is shown below.
        foreach ($file in $ownedFiles) { $copierArgs += '--exclude', "/$file" }
        # Copier writes the template's .gitignore over the project's before merging the project's edits back, then passes
        # every path Git reports as ignored to one `git apply` command. Keep the project's rules in force meanwhile, or a
        # folder only they ignore, such as node_modules/, is listed file by file and overflows Windows' command line.
        # The copy sits between marker lines, so a run that was killed before restoring info/exclude is cleaned up here.
        $infoExclude = git rev-parse --path-format=absolute --git-path info/exclude
        $beginCopy = '# Update-Project.ps1: the project''s .gitignore, in force while Copier updates'
        $endCopy = '# Update-Project.ps1: end of the .gitignore copy'
        $excludeBefore = if (Test-Path -LiteralPath $infoExclude) {
            [regex]::Replace([IO.File]::ReadAllText($infoExclude), "(?s)\n$([regex]::Escape($beginCopy))\n.*?\n$([regex]::Escape($endCopy))\n", '')
        }
        $projectIgnore = Join-Path $project '.gitignore'
        try {
            if (Test-Path -LiteralPath $projectIgnore) {
                New-Item -ItemType Directory -Force (Split-Path $infoExclude) | Out-Null
                [IO.File]::WriteAllText($infoExclude, "$excludeBefore`n$beginCopy`n$([IO.File]::ReadAllText($projectIgnore))$($keptLines['.gitignore'])`n$endCopy`n")
            }
            Invoke-Copier @copierArgs
        }
        finally {
            if ($null -eq $excludeBefore) { Remove-Item -LiteralPath $infoExclude -Force -ErrorAction SilentlyContinue }
            else { [IO.File]::WriteAllText($infoExclude, $excludeBefore) }
        }

        # Put the kept lines back at the end, after any conflict.
        foreach ($file in $keptLines.Keys) {
            $full = Join-Path $project $file
            if (Test-Path -LiteralPath $full) { [IO.File]::WriteAllText($full, [IO.File]::ReadAllText($full).TrimEnd("`r", "`n") + $keptLines[$file]) }
        }

        # Drop the reset commit but keep its changes, and any conflict, in the index and the working tree. The index keeps the reset's version of each file it changed, such as a .gitignore without its kept lines, so note them.
        if ($resetCommitted) {
            $resetFiles = @(git -c core.quotePath=false diff --name-only --no-renames $head HEAD)
            git update-ref HEAD $head; if ($LASTEXITCODE) { throw 'Removing the reset commit failed.' }
        }
    }
    catch {
        git reset -q --hard $head; git clean -fdq
        throw
    }

    $conflicts = @(git diff --name-only --diff-filter=U)
    if (-not $conflicts) {
        git add -A
        # Executable on Linux and macOS; Windows doesn't record the bit on its own.
        if (Test-Path -LiteralPath .githooks/commit-msg) { git update-index --chmod=+x .githooks/commit-msg }
        if (Test-Path -LiteralPath .githooks/pre-push) { git update-index --chmod=+x .githooks/pre-push }
    }
    else {
        # git add -A would mark the conflicted files resolved, conflict markers and all, so stage only each file the reset changed that doesn't conflict, as the update left it. Otherwise the index keeps the reset's version: a file the update left as it was is listed as modified, and a commit that doesn't stage it again takes that version.
        $unmerged = @(git -c core.quotePath=false diff --name-only --diff-filter=U)
        $restage = @($resetFiles | Where-Object { $_ -notin $unmerged })
        if ($restage) { git --literal-pathspecs add -A -- $restage }
    }
    # Enable the template's versioned hooks in this clone, unless it already has a hooks path or runs hooks another way
    # (Get-GitHooksSetup): then warn, because without them nothing strips AI agent attribution before a push.
    if (Test-Path -LiteralPath .githooks) {
        $hooksSetup = Get-GitHooksSetup
        if ($hooksSetup.HooksPath) { git config core.hooksPath .githooks }
        elseif ($hooksSetup.Note) { Write-Warning $hooksSetup.Note }
    }
    $changes = @(Get-Change)
    $projectOwnedChanged = @(if ($from -ne $to) {
            $changedOwned = @(foreach ($source in git -C $TemplateClone diff --name-only $from $to -- template/ 2>$null) {
                    $file = ConvertTo-ProjectName $source
                    if (((Test-CopierPattern $file $skipTo) -or $file -in $ownedFiles) -and (Test-Path -LiteralPath $file)) { [pscustomobject]@{ File = $file; Source = $source } }
                })
            # A renamed template source lists its file twice: show the file once, with every source.
            foreach ($group in $changedOwned | Group-Object File) { [pscustomobject]@{ File = $group.Name; Source = @($group.Group | ForEach-Object Source) } }
        })

    # A success ends with exit 0, not return, which would hand a caller that runs this with & the exit code of the last git command, such as git apply --check's 1 for a hunk the project lacks.
    if (-not (git status --porcelain)) { "Already up to date: template $to."; exit 0 }
    "Template $from -> ${to}:"
    $changes | Sort-Object Kind, File | ForEach-Object { '  {0,-9} {1}' -f $_.Kind, $_.File }
    $edited = @($reset | Where-Object Kind -NE 'added' | ForEach-Object File)
    $restored = @($reset | Where-Object Kind -EQ 'added' | ForEach-Object File)
    if ($edited) { ''; 'Local edits discarded — these files are the template''s; make the change in a project file instead:'; $edited | ForEach-Object { "  $_" } }
    if ($restored) { ''; 'Restored — these files are the template''s, so the project can''t delete them:'; $restored | ForEach-Object { "  $_" } }
    if ($refreshed) { ''; 'Refreshed — these files are the template''s, but earlier template versions never updated them; a local edit to one is discarded, so make the change in a project file instead:'; $refreshed | ForEach-Object { "  $_" } }
    if ($projectOwnedChanged) {
        # Render both versions with the project's answers, so the diffs show what the project would get, not Jinja.
        New-Item -ItemType Directory -Force $scratch | Out-Null
        $renderedTo = Join-Path $scratch 'rendered\to'
        $rendered = $(if ($null -ne $fromRendered) { $fromRendered } else { Invoke-TemplateRender $from $renderedFrom }) -and (Invoke-TemplateRender $to $renderedTo)
        $empty = Join-Path $scratch 'empty'
        [IO.File]::WriteAllText($empty, '')
        $shown = foreach ($changed in $projectOwnedChanged) {
            if ($rendered) {
                $old = Join-Path $renderedFrom $changed.File
                $new = Join-Path $renderedTo $changed.File
                $diff = git diff --no-index --no-color --unified=1 -- $(if (Test-Path -LiteralPath $old) { $old } else { $empty }) $(if (Test-Path -LiteralPath $new) { $new } else { $empty })
                $title = "  $($changed.File):"
            }
            else {
                $diff = git -C $TemplateClone diff --no-color --unified=1 $from $to -- $changed.Source
                $title = "  $($changed.File), from the template source $($changed.Source -join ', '), which Copier couldn't render with this project's answers:"
            }
            # Leave out a hunk the project's file already has; a file left with none isn't shown.
            $hunk = @(
                $current = @()
                foreach ($line in @($diff | Where-Object { $_ -is [string] }) + '@@') {
                    if ($line.StartsWith('@@')) {
                        if ($current -and -not ($rendered -and (Test-HunkApplied $changed.File $current $scratch))) { $current | ForEach-Object { "    $_" } }
                        $current = @()
                    }
                    if ($current -or $line.StartsWith('@@')) { $current += $line }
                }
            )
            if ($hunk) { [pscustomobject]@{ Title = $title; Lines = $hunk } }
        }
        if ($shown) {
            ''
            "The template changed these project-owned files since ${from}. They weren't touched; copy over what you want:"
            foreach ($file in $shown) { ''; $file.Title; $file.Lines }
        }
    }

    # A conflict in a file the target version owns, neither merged nor project-owned there, comes from the project's own copy of it, such as a build/dod.ps1 the template now adds: the project_owned_files answer keeps that copy.
    $ownedConflicts = @()
    if ($conflicts) {
        $mergedTo = @(Get-TemplateList $TemplateClone $to '_merged_files')
        $ownedConflicts = @($conflicts | Where-Object { $_ -in $ownable -and $_ -notin $mergedTo -and -not (Test-CopierPattern $_ $skipTo) })
    }
    $ownedCommand = "  .\.template\Update-Project.ps1 -Data @{ project_owned_files = $((@($ownedFiles) + $rewritten + $ownedConflicts | Select-Object -Unique | ForEach-Object { "'$_'" }) -join ', ') }"
    if ($rewritten) {
        ''
        "These merged files share less than half their lines with the template's version, so the project seems to have replaced them, and the template's changes to them can conflict in unrelated places:"
        $rewritten | ForEach-Object { "  $_" }
        if (-not $ownedConflicts) { "To make them project-owned, so updates leave them alone and show the template's changes instead, run the update with (after abandoning it with git reset --hard; git clean -fd if it stops with a conflict below):"; $ownedCommand }
    }
    if ($ownedConflicts) {
        ''
        "These files are template-owned in ${to}, and this project has its own version of each, so they conflict:"
        $ownedConflicts | ForEach-Object { "  $_" }
        "To keep the project's versions, make them project-owned$(if ($rewritten) { ', with the merged files above,' }) so updates leave them alone and show the template's changes instead. Abandon this update with git reset --hard; git clean -fd, then run:"
        $ownedCommand
    }

    # Version tags the changelog has no section for, such as releases from before it started (Get-ChangelogBackfill).
    $backfill = Get-ChangelogBackfill
    if ($backfill.Range -ne '-') {
        ''
        "Version tags without a section in $($backfill.File): $($backfill.Range). To give the changelog the project's full release history, in the repository, run:"
        "  /plan-migration Backfill $($backfill.File) from the releases $($backfill.Range)"
    }
    $message = "Update from project-template $to"
    if ($conflicts) {
        ''
        "$($conflicts.Count) file(s) conflict: the template and this project changed the same lines. In each, keep the right lines and delete the <<<<<<<, ======= and >>>>>>> marker lines. Then:"
        '  git add -A'
        '  git diff --cached --check     # prints any marker you missed'
        "  git commit -m `"$message`""
        'To abandon the update instead: git reset --hard; git clean -fd'
        exit 1
    }
    if ($NoCommit) { ''; "Staged for review: git diff --cached, then git commit -m `"$message`""; exit 0 }
    git commit -q -m $message
    if ($LASTEXITCODE) { throw 'The commit failed.' }
    ''
    "Committed `"$message`". Review it with: git show --stat"
    exit 0
}
finally {
    Pop-Location
    try { [Console]::OutputEncoding = $outputEncoding } catch { Write-Verbose "Couldn't restore the console's output encoding: $_" }
    if ($ownClone -and $TemplateClone -and (Test-Path -LiteralPath $TemplateClone)) { Remove-Item -LiteralPath $TemplateClone -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
}
