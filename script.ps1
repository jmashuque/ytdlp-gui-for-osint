param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$CaseName,

    [Parameter(Mandatory = $false)]
    [string]$CookiesFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputRoot = "D:\Investigations",

    [Parameter(Mandatory = $false)]
    [string]$YtDlpPath = "yt-dlp",

    [Parameter(Mandatory = $false)]
    [string]$FFmpegFolder,

    [Parameter(Mandatory = $false)]
    [string]$ImpersonateTarget,

    [switch]$PreferMp4,

    [switch]$UpdateYtDlp
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "========== $Text =========="
}

function New-SafeName {
    param([string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_').Trim()
}

function Resolve-Executable {
    param([string]$PathOrCommand)

    if (Test-Path $PathOrCommand) {
        return (Resolve-Path $PathOrCommand).Path
    }

    $cmd = Get-Command $PathOrCommand -ErrorAction Stop
    return $cmd.Source
}

function Get-Sha256HashString {
    param([string]$Path)

    $stream = $null
    $sha256 = $null

    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($Path)
        $bytes = $sha256.ComputeHash($stream)
        return (($bytes | ForEach-Object { $_.ToString("x2") }) -join "").ToUpperInvariant()
    }
    finally {
        if ($stream) { $stream.Dispose() }
        if ($sha256) { $sha256.Dispose() }
    }
}

function Export-Sha256Manifest {
    param(
        [string]$RootPath,
        [string]$OutputCsv
    )

    $outputCsvFull = [System.IO.Path]::GetFullPath($OutputCsv)

    Get-ChildItem $RootPath -Recurse -File |
        Where-Object {
            [System.IO.Path]::GetFullPath($_.FullName) -ne $outputCsvFull
        } |
        ForEach-Object {
            try {
                [pscustomobject]@{
                    Algorithm = "SHA256"
                    Hash      = Get-Sha256HashString -Path $_.FullName
                    Path      = $_.FullName
                }
            }
            catch {
                [pscustomobject]@{
                    Algorithm = "SHA256"
                    Hash      = "ERROR: $($_.Exception.Message)"
                    Path      = $_.FullName
                }
            }
        } |
        Export-Csv $OutputCsv -NoTypeInformation
}

function Invoke-YtDlpLogged {
    param(
        [string]$ExePath,
        [string[]]$Arguments,
        [string]$RunLog
    )

    $tempLog = Join-Path $env:TEMP ("yt-dlp-temp-{0}.log" -f ([guid]::NewGuid()))
    $previousErrorActionPreference = $ErrorActionPreference

    try {
        # yt-dlp writes normal verbose/debug output to stderr.
        # Do not let PowerShell treat that output as a terminating script error.
        $ErrorActionPreference = "Continue"

        & $ExePath @Arguments *> $tempLog
        $exitCode = $LASTEXITCODE

        if (Test-Path $tempLog) {
            Get-Content $tempLog | Tee-Object -FilePath $RunLog -Append
        }

        return $exitCode
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Remove-Item $tempLog -Force -ErrorAction SilentlyContinue
    }
}

$SafeCaseName = New-SafeName $CaseName
$CaseDir = Join-Path $OutputRoot $SafeCaseName
$MediaDir = Join-Path $CaseDir "media"
$LogDir = Join-Path $CaseDir "logs"
$ManifestDir = Join-Path $CaseDir "manifests"

$ArchiveFile = Join-Path $CaseDir "download-archive.txt"
$RunLog = Join-Path $LogDir ("yt-dlp-run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$HashManifest = Join-Path $ManifestDir ("sha256-manifest_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

New-Item -ItemType Directory -Path $CaseDir, $MediaDir, $LogDir, $ManifestDir -Force | Out-Null

Write-Section "Preflight checks"

if (-not (Test-Path $InputFile)) {
    throw "Input file not found: $InputFile"
}

if ($CookiesFile -and -not (Test-Path $CookiesFile)) {
    throw "Cookies file not found: $CookiesFile"
}

$ResolvedYtDlpPath = Resolve-Executable $YtDlpPath
$ToolsDir = Split-Path -Parent $ResolvedYtDlpPath

$DenoPath = Join-Path $ToolsDir "deno.exe"
if (-not (Test-Path $DenoPath)) {
    throw "deno.exe was not found beside yt-dlp.exe: $ToolsDir"
}

if ($FFmpegFolder) {
    if (-not (Test-Path $FFmpegFolder -PathType Container)) {
        throw "FFmpeg folder not found: $FFmpegFolder"
    }

    $ResolvedFFmpegFolder = (Resolve-Path $FFmpegFolder).Path
}
else {
    $ResolvedFFmpegFolder = $ToolsDir
}

$FFmpegPath = Join-Path $ResolvedFFmpegFolder "ffmpeg.exe"
$FFprobePath = Join-Path $ResolvedFFmpegFolder "ffprobe.exe"

if (-not (Test-Path $FFmpegPath)) {
    throw "ffmpeg.exe was not found in: $ResolvedFFmpegFolder"
}

if (-not (Test-Path $FFprobePath)) {
    throw "ffprobe.exe was not found in: $ResolvedFFmpegFolder"
}

Write-Host "yt-dlp:      $ResolvedYtDlpPath"
Write-Host "Deno:        $DenoPath"
Write-Host "FFmpeg dir:  $ResolvedFFmpegFolder"
Write-Host "Case:        $CaseDir"
Write-Host "Impersonate: $(if ($ImpersonateTarget) { $ImpersonateTarget } else { 'Not specified' })"
Write-Host "Prefer MP4:  $PreferMp4"

Add-Content -Path $RunLog -Value "yt-dlp: $ResolvedYtDlpPath"
Add-Content -Path $RunLog -Value "Deno: $DenoPath"
Add-Content -Path $RunLog -Value "FFmpeg folder: $ResolvedFFmpegFolder"
Add-Content -Path $RunLog -Value "ImpersonateTarget: $ImpersonateTarget"
Add-Content -Path $RunLog -Value "PreferMp4: $PreferMp4"

if ($UpdateYtDlp) {
    Write-Section "Updating yt-dlp"

    $updateExitCode = Invoke-YtDlpLogged `
        -ExePath $ResolvedYtDlpPath `
        -Arguments @("--update-to", "nightly") `
        -RunLog $RunLog

    Add-Content -Path $RunLog -Value "yt-dlp update exit code: $updateExitCode"

    if ($updateExitCode -ne 0) {
        Write-Warning "yt-dlp update exited with code $updateExitCode. Continuing with the current binary."
    }
}

Write-Section "Loading URLs"

$Urls = @(
    Get-Content $InputFile |
        ForEach-Object { $_.Trim() } |
        Where-Object {
            $_ -and
            -not $_.StartsWith("#") -and
            ($_ -match '^https?://')
        }
)

if (-not $Urls -or $Urls.Count -eq 0) {
    throw "No valid URLs found in input file. Use one http/https URL per line."
}

Write-Host "Found $($Urls.Count) URL(s)."

Write-Section "Starting video-only capture"

$CommonArgs = @(
    "--ignore-errors",
    "--no-overwrites",
    "--continue",
    "--no-playlist",
    "--restrict-filenames",
    "--trim-filenames", "180",

    "--js-runtimes", "deno:$DenoPath",

    "--ffmpeg-location", $ResolvedFFmpegFolder,

    "--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "--add-header", "Accept-Language: en-US,en;q=0.9",

    "--no-write-info-json",
    "--no-write-description",
    "--no-write-thumbnail",
    "--no-write-subs",
    "--no-write-auto-subs",

    "--no-embed-metadata",
    "--no-embed-thumbnail",
    "--no-embed-subs",

    "--sleep-requests", "5",
    "--sleep-interval", "30",
    "--max-sleep-interval", "90",

    "--retries", "5",
    "--fragment-retries", "5",
    "--retry-sleep", "exp=10:120",

    "--download-archive", $ArchiveFile,

    "--paths", $MediaDir,

    "--output", "%(extractor)s/%(uploader|unknown)s/%(upload_date|unknown)s_%(id)s_%(title).180B.%(ext)s",

    "--verbose"
)

if ($PreferMp4) {
    $CommonArgs += @(
        "--format", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best",
        "--merge-output-format", "mp4"
    )
}

if ($ImpersonateTarget) {
    $CommonArgs += @("--impersonate", $ImpersonateTarget)
}

if ($CookiesFile) {
    $CommonArgs += @("--cookies", $CookiesFile)
}

for ($i = 0; $i -lt $Urls.Count; $i++) {
    $Url = $Urls[$i]
    $IsLastUrl = ($i -eq ($Urls.Count - 1))

    Write-Host ""
    Write-Host "Capturing: $Url"

    $YtDlpArgs = @()
    $YtDlpArgs += $CommonArgs
    $YtDlpArgs += $Url

    $ExitCode = Invoke-YtDlpLogged `
        -ExePath $ResolvedYtDlpPath `
        -Arguments $YtDlpArgs `
        -RunLog $RunLog

    Add-Content -Path $RunLog -Value "yt-dlp exit code for URL [$Url]: $ExitCode"

    if ($ExitCode -eq 0) {
        Write-Host "yt-dlp completed successfully for this URL."
    }
    else {
        Write-Warning "yt-dlp exited with code $ExitCode for this URL. Check the run log. Output may still have been created."
    }

    if (-not $IsLastUrl) {
        $PauseSeconds = 30 + (Get-Random -Minimum 0 -Maximum 31)
        Write-Host "Pausing $PauseSeconds seconds before next URL..."
        Start-Sleep -Seconds $PauseSeconds
    }
}

Write-Section "Hashing captured files"

Export-Sha256Manifest -RootPath $CaseDir -OutputCsv $HashManifest

Write-Host "Hash manifest written to: $HashManifest"

Write-Section "Done"

Write-Host "Case folder:      $CaseDir"
Write-Host "Run log:          $RunLog"
Write-Host "Download archive: $ArchiveFile"
Write-Host "SHA256 manifest:  $HashManifest"