#requires -Version 5.1
<#
.SYNOPSIS
  Seeds a fully offline, deterministic, fabricated demo dataset for OJ Float.

.DESCRIPTION
  Reproducible demo data for README screenshots and the loopback-import demo.
  Everything written here is fake: account names are "DemoCoder" and
  "demo_learner", problem titles/URLs are public OJ examples with made-up ids,
  and notes/reflections contain no personal information. No network access is
  performed.

  The script writes the same files the application itself uses, so the data is
  read back through the real persistence code paths:

    shared_preferences.json   -> app config (fake accounts, light theme)
    snapshots_v1.json         -> solved-count snapshots driving the heatmap/streak
    training_v1.json          -> training lists, attempts and daily tasks
    contests_v1.json          -> contest records
    refresh_logs_v1.json      -> a couple of successful refresh entries
    problems_v1.json          -> legacy problem file that the app migrates into SQLite
    window_state.json         -> opens on the summary page

  After writing the JSON files the script deletes any existing problem book
  SQLite file and (when the release exe is available) runs the headless
  migration so `problem_book.sqlite3` is rebuilt from `problems_v1.json` by the
  application's own migration code.

.PARAMETER DataDir
  Target application data directory. Defaults to the installed app data path
  "%APPDATA%\ZuesHans\OJ Float".

.PARAMETER Today
  Training day used as "now" for the generated snapshots. Defaults to today.
  Pass a fixed date (e.g. 2026-10-24) to reproduce a specific dataset.

.PARAMETER ExePath
  Path to the release oj_float.exe. If present, the script runs the headless
  problem-database migration so the SQLite file is created deterministically.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\showcase\seed_demo_data.ps1
#>
[CmdletBinding()]
param(
    [string]$DataDir = (Join-Path $env:APPDATA 'ZuesHans\OJ Float'),
    [string]$Today = ((Get-Date).Date.ToString('yyyy-MM-dd')),
    [string]$ExePath = ''
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Convert-ToJsonUtf8 {
    param($Value)
    return $Value | ConvertTo-Json -Depth 30
}

$anchorDate = [datetime]::ParseExact($Today, 'yyyy-MM-dd', $null)
$start = [datetime]'2026-06-01'
$anchorKey = $anchorDate.ToString('yyyy-MM-dd')

Write-Host "Seeding demo data into: $DataDir"
Write-Host "Anchor date (today):   $anchorKey"

if (Get-Process oj_float -ErrorAction SilentlyContinue) {
    Write-Warning 'oj_float.exe appears to be running. Close it before seeding so files are not overwritten.'
}

# ---------------------------------------------------------------------------
# 1. App config (shared_preferences.json)
# ---------------------------------------------------------------------------
$accounts = [ordered]@{
    codeforces = [ordered]@{ usernames = @('DemoCoder');    enabled = $true }
    leetcode   = [ordered]@{ usernames = @('demo_learner'); enabled = $true }
    atcoder    = [ordered]@{ usernames = @(); enabled = $false }
    luogu      = [ordered]@{ usernames = @(); enabled = $false }
    nowcoder   = [ordered]@{ usernames = @(); enabled = $false }
}

# The ojAccounts module is intentionally disabled: refresh() is a no-op when it is
# off, so capturing stays fully offline and deterministic even though the fake
# accounts below are configured/enabled (they still drive the summary totals).
$dashboardModules = @(
    'summary', 'training', 'heatmap', 'problems', 'refreshLogs',
    'contests', 'teammates', 'daily'
)

$config = [ordered]@{
    configVersion         = 4
    refreshIntervalMinutes = 60
    launchAtStartup       = $false
    closeToTray           = $false
    quickEntryHotkey      = 'Ctrl+Shift+O'
    onboardingComplete    = $true
    dashboardModules      = $dashboardModules
    dashboardOrder        = $dashboardModules
    wideDashboardModules  = @('training', 'daily')
    colorTheme            = 'classic'
    appearanceMode        = 'light'
    compactDensity        = $false
    sync = [ordered]@{
        enabled               = $false
        endpointUrl           = ''
        syncDailyStats        = $true
        syncProblems          = $true
        includeProblemNote    = $false
        includeProblemAnalysis = $false
        autoSyncAfterRefresh  = $true
    }
    automaticBackup = [ordered]@{
        enabled       = $false
        timeMinutes   = 1320
        directoryPath = ''
    }
    accounts = $accounts
}

$configJson = Convert-ToJsonUtf8 $config
$prefs = [ordered]@{ 'flutter.app_config_v1' = $configJson }
Write-Utf8NoBom -Path (Join-Path $DataDir 'shared_preferences.json') -Content (Convert-ToJsonUtf8 $prefs)
Write-Host '  wrote shared_preferences.json'

# ---------------------------------------------------------------------------
# 2. Solved snapshots (snapshots_v1.json) -> heatmap / streak / totals
# ---------------------------------------------------------------------------
function New-Snapshots {
    param(
        [string]$OjId,
        [string]$Username,
        [int]$Seed,
        [int]$BaseSolved
    )
    $rng = New-Object System.Random($Seed)
    $result = New-Object System.Collections.Generic.List[object]
    $solved = $BaseSolved
    $days = @()
    for ($d = $start; $d -le $anchorDate; $d = $d.AddDays(1)) {
        $days += $d
    }
    # The last 14 days (including today) are guaranteed active so the current
    # streak renders; the day right before that is forced to zero.
    for ($i = 0; $i -lt $days.Count; $i++) {
        $day = $days[$i]
        $daysFromToday = $days.Count - 1 - $i
        if ($daysFromToday -lt 14) {
            $count = $rng.Next(1, 6)
        } elseif ($daysFromToday -eq 14) {
            $count = 0
        } else {
            $count = $rng.Next(0, 6)
        }
        $solved += $count
        $dateKey = $day.ToString('yyyy-MM-dd')
        $result.Add([ordered]@{
            date                  = $dateKey
            fetchedAt             = "$dateKey" + 'T08:30:00'
            ojId                  = $OjId
            username              = $Username
            status                = 'success'
            solvedCount           = $solved
            dailyAcceptedCount    = $count
            dailyActivityAccuracy = 'exact'
        }) | Out-Null
    }
    return ,$result
}

$cfSnapshots = New-Snapshots -OjId 'codeforces' -Username 'DemoCoder' -Seed 20261001 -BaseSolved 96
$lcSnapshots = New-Snapshots -OjId 'leetcode'   -Username 'demo_learner' -Seed 20261002 -BaseSolved 28

$allSnapshots = New-Object System.Collections.Generic.List[object]
foreach ($s in $cfSnapshots) { $allSnapshots.Add($s) }
foreach ($s in $lcSnapshots) { $allSnapshots.Add($s) }

Write-Utf8NoBom -Path (Join-Path $DataDir 'snapshots_v1.json') -Content (Convert-ToJsonUtf8 $allSnapshots)
Write-Host ('  wrote snapshots_v1.json ({0} snapshots)' -f $allSnapshots.Count)

$cfFinalSolved = $cfSnapshots[$cfSnapshots.Count - 1].solvedCount
$lcFinalSolved = $lcSnapshots[$lcSnapshots.Count - 1].solvedCount

# ---------------------------------------------------------------------------
# 3. Refresh logs (refresh_logs_v1.json)
# ---------------------------------------------------------------------------
$refreshLogs = @(
    [ordered]@{
        id = 'rlog-cf-demo'
        fetchedAt = "$anchorKey" + 'T08:30:00'
        ojId = 'codeforces'
        username = 'DemoCoder'
        status = 'success'
        source = 'api'
        solvedCount = $cfFinalSolved
        previousSolvedCount = ($cfFinalSolved - 3)
        message = ''
    },
    [ordered]@{
        id = 'rlog-lc-demo'
        fetchedAt = "$anchorKey" + 'T08:30:00'
        ojId = 'leetcode'
        username = 'demo_learner'
        status = 'success'
        source = 'api'
        solvedCount = $lcFinalSolved
        previousSolvedCount = ($lcFinalSolved - 2)
        message = ''
    }
)
Write-Utf8NoBom -Path (Join-Path $DataDir 'refresh_logs_v1.json') -Content (Convert-ToJsonUtf8 $refreshLogs)
Write-Host '  wrote refresh_logs_v1.json'

# ---------------------------------------------------------------------------
# 4. Problems (problems_v1.json) -> migrated into problem_book.sqlite3
# ---------------------------------------------------------------------------
function New-Problem {
    param(
        [string]$Id, [string]$Title, [string]$Url, [string]$Platform,
        [string]$Workflow, [string[]]$Tags, [string]$DateKey,
        [string]$Note, [string]$Difficulty, [string]$ExternalId,
        [string]$Folder
    )
    return [ordered]@{
        id             = $Id
        title          = $Title
        url            = $Url
        platform       = $Platform
        workflowStatus = $Workflow
        tags           = $Tags
        date           = $DateKey
        note           = $Note
        analysis       = ''
        difficulty     = $Difficulty
        externalId     = $ExternalId
        folder         = $Folder
        created_at     = "$DateKey" + 'T09:00:00'
        updated_at     = "$DateKey" + 'T09:00:00'
    }
}

$problems = @(
    (New-Problem 'demo-cf-a' 'A. Watermelon' 'https://codeforces.com/problemset/problem/4/A' 'codeforces' 'backlog' @('构造','数学') '2026-10-20' '' '800' '4A' '入门'),
    (New-Problem 'demo-cf-b' 'B. Prefix Sum Queries' 'https://codeforces.com/problemset/problem/1730/B' 'codeforces' 'backlog' @('前缀和') '2026-10-21' '' '1200' '1730B' ''),
    (New-Problem 'demo-lg-a' 'P1001 A+B Problem' 'https://www.luogu.com.cn/problem/P1001' 'luogu' 'backlog' @('入门') '2026-10-22' '' '入门' 'P1001' '入门'),
    (New-Problem 'demo-lc-a' '两数之和' 'https://leetcode.cn/problems/two-sum/' 'leetcode' 'backlog' @('数组','哈希表') '2026-10-23' '' '简单' '1' ''),

    (New-Problem 'demo-cf-c' 'C. Knapsack' 'https://codeforces.com/problemset/problem/1446/A' 'codeforces' 'active' @('动态规划','背包') '2026-10-18' '注意 n=1 的边界条件' '1600' '1446A' '动态规划'),
    (New-Problem 'demo-cf-d' 'D. Binary Search' 'https://codeforces.com/problemset/problem/1620/B' 'codeforces' 'active' @('二分') '2026-10-19' '' '1400' '1620B' ''),
    (New-Problem 'demo-lc-b' '爬楼梯' 'https://leetcode.cn/problems/climbing-stairs/' 'leetcode' 'active' @('动态规划') '2026-10-17' '经典递推' '简单' '70' '动态规划'),
    (New-Problem 'demo-at-a' 'ABC 101 A - Eating Symbols Easy' 'https://atcoder.jp/contests/abc101/tasks/abc101_a' 'atcoder' 'active' @('模拟') '2026-10-20' '' '100' 'abc101_a' ''),

    (New-Problem 'demo-cf-e' 'E. Two Pointers' 'https://codeforces.com/problemset/problem/1006/C' 'codeforces' 'mastered' @('双指针') '2026-10-05' '' '1500' '1006C' '每日训练'),
    (New-Problem 'demo-lc-c' '最长回文子串' 'https://leetcode.cn/problems/longest-palindromic-substring/' 'leetcode' 'mastered' @('字符串','动态规划') '2026-10-08' '' '中等' '5' '每日训练'),
    (New-Problem 'demo-lg-b' 'P1048 采药' 'https://www.luogu.com.cn/problem/P1048' 'luogu' 'mastered' @('背包','动态规划') '2026-10-10' '' '普及-' 'P1048' '动态规划'),

    (New-Problem 'demo-cf-f' 'F. Theatre Square' 'https://codeforces.com/problemset/problem/1/A' 'codeforces' 'archived' @('数学') '2026-06-15' '已完成归档' '1000' '1A' '')
)

Write-Utf8NoBom -Path (Join-Path $DataDir 'problems_v1.json') -Content (Convert-ToJsonUtf8 $problems)
Write-Host ('  wrote problems_v1.json ({0} problems)' -f $problems.Count)

# ---------------------------------------------------------------------------
# 5. Training data (training_v1.json)
# ---------------------------------------------------------------------------
$training = [ordered]@{
    schemaVersion = 2
    attempts = @(
        [ordered]@{
            id = 'attempt-demo-1'
            problemId = 'demo-cf-e'
            origin = 'manual'
            startedAt = '2026-10-05T19:00:00'
            endedAt = '2026-10-05T19:45:00'
            durationSeconds = 2700
            result = 'ac'
            assistance = 'none'
            mistakes = @()
            reflection = '一遍过，思路清晰'
        },
        [ordered]@{
            id = 'attempt-demo-2'
            problemId = 'demo-cf-c'
            origin = 'manual'
            startedAt = '2026-10-18T20:00:00'
            endedAt = '2026-10-18T20:52:00'
            durationSeconds = 3120
            result = 'wa'
            assistance = 'hint'
            mistakes = @('edgeCase', 'implementation')
            reflection = '漏了 n=1 的边界条件'
        },
        [ordered]@{
            id = 'attempt-demo-3'
            problemId = 'demo-lc-b'
            origin = 'manual'
            startedAt = '2026-10-17T21:00:00'
            endedAt = '2026-10-17T21:25:00'
            durationSeconds = 1500
            result = 'ac'
            assistance = 'none'
            mistakes = @()
            reflection = '经典递推'
        },
        [ordered]@{
            id = 'attempt-demo-4'
            problemId = 'demo-lc-c'
            origin = 'manual'
            startedAt = '2026-10-08T19:30:00'
            endedAt = '2026-10-08T20:10:00'
            durationSeconds = 2400
            result = 'ac'
            assistance = 'editorial'
            mistakes = @('idea')
            reflection = '中心扩展法'
        },
        [ordered]@{
            id = 'attempt-demo-5'
            problemId = 'demo-cf-d'
            origin = 'manual'
            startedAt = '2026-10-19T20:00:00'
            endedAt = '2026-10-19T20:40:00'
            durationSeconds = 2400
            result = 'tle'
            assistance = 'hint'
            mistakes = @('complexity')
            reflection = '优化到 O(n log n)'
        },
        [ordered]@{
            id = 'attempt-demo-6'
            problemId = 'demo-at-a'
            origin = 'manual'
            startedAt = '2026-10-20T19:00:00'
            endedAt = '2026-10-20T19:12:00'
            durationSeconds = 720
            result = 'ac'
            assistance = 'none'
            mistakes = @()
            reflection = ''
        }
    )
    lists = @(
        [ordered]@{
            id = 'default-favorites'
            title = '默认收藏夹'
            type = 'custom'
            problemIds = @()
            contestId = $null
            createdAt = '2026-10-01T09:00:00'
            updatedAt = '2026-10-01T09:00:00'
            archived = $false
            isDefault = $true
        },
        [ordered]@{
            id = 'list-demo-dp'
            title = '动态规划专题'
            type = 'custom'
            problemIds = @('demo-cf-c', 'demo-lc-b', 'demo-lg-b')
            contestId = $null
            createdAt = '2026-10-06T09:00:00'
            updatedAt = '2026-10-18T09:00:00'
            archived = $false
            isDefault = $false
        },
        [ordered]@{
            id = 'list-demo-daily'
            title = '每日训练'
            type = 'custom'
            problemIds = @('demo-cf-e', 'demo-lc-c')
            contestId = $null
            createdAt = '2026-10-01T09:00:00'
            updatedAt = '2026-10-08T09:00:00'
            archived = $false
            isDefault = $false
        }
    )
    tasks = @(
        [ordered]@{
            id = 'task-demo-1'
            problemId = 'demo-cf-c'
            trainingDate = $anchorKey
            source = 'manual'
            status = 'planned'
            sortOrder = 0
            createdAt = "$anchorKey" + 'T08:00:00'
            completedAt = $null
        },
        [ordered]@{
            id = 'task-demo-2'
            problemId = 'demo-lc-a'
            trainingDate = $anchorKey
            source = 'manual'
            status = 'planned'
            sortOrder = 1
            createdAt = "$anchorKey" + 'T08:00:00'
            completedAt = $null
        },
        [ordered]@{
            id = 'task-demo-3'
            problemId = 'demo-cf-d'
            trainingDate = $anchorKey
            source = 'manual'
            status = 'done'
            sortOrder = 2
            createdAt = "$anchorKey" + 'T08:00:00'
            completedAt = "$anchorKey" + 'T09:20:00'
        }
    )
    activeAttempt = $null
}
Write-Utf8NoBom -Path (Join-Path $DataDir 'training_v1.json') -Content (Convert-ToJsonUtf8 $training)
Write-Host '  wrote training_v1.json'

# ---------------------------------------------------------------------------
# 6. Contest records (contests_v1.json)
# ---------------------------------------------------------------------------
$contests = @(
    [ordered]@{
        id = 'contest-demo-1'
        title = '周末训练赛 (Div. 2)'
        date = '2026-10-18'
        rank = 2345
        totalParticipants = 12000
        solvedCount = 3
        penalty = 145
        note = 'C 题读题失误，D 题思路正确但没写完。'
        created_at = '2026-10-18T22:00:00'
        updated_at = '2026-10-18T22:00:00'
    },
    [ordered]@{
        id = 'contest-demo-2'
        title = '个人排位赛'
        date = '2026-10-11'
        rank = 567
        totalParticipants = 4000
        solvedCount = 4
        penalty = 98
        note = '状态不错，罚时控制住了。'
        created_at = '2026-10-11T21:00:00'
        updated_at = '2026-10-11T21:00:00'
    }
)
Write-Utf8NoBom -Path (Join-Path $DataDir 'contests_v1.json') -Content (Convert-ToJsonUtf8 $contests)
Write-Host '  wrote contests_v1.json'

# ---------------------------------------------------------------------------
# 7. Window state (window_state.json) -> opens on summary page
# ---------------------------------------------------------------------------
$windowState = [ordered]@{
    version = 1
    maximized = $false
    section = 'summary'
}
Write-Utf8NoBom -Path (Join-Path $DataDir 'window_state.json') -Content (Convert-ToJsonUtf8 $windowState)
Write-Host '  wrote window_state.json'

# ---------------------------------------------------------------------------
# 8. Rebuild the problem book SQLite from problems_v1.json
# ---------------------------------------------------------------------------
foreach ($suffix in @('', '-wal', '-shm', '-journal')) {
    $sqlitePath = Join-Path $DataDir ('problem_book.sqlite3' + $suffix)
    if (Test-Path $sqlitePath) {
        Remove-Item -Force $sqlitePath
        Write-Host "  removed $sqlitePath"
    }
}

if ($ExePath -and (Test-Path $ExePath)) {
    Write-Host '  running headless problem-database migration...'
    $proc = Start-Process -FilePath $ExePath `
        -ArgumentList '--migrate-problem-database-and-exit', '--migration-directory', $DataDir `
        -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Headless migration failed with exit code $($proc.ExitCode)"
    }
    Write-Host '  problem_book.sqlite3 rebuilt by the application.'
} else {
    Write-Warning '  ExePath not provided or not found; the app will migrate problems_v1.json on first launch.'
}

Write-Host ''
Write-Host 'Demo data seeding complete.'
