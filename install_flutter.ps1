# Flutter Windows Auto Install Script
# Based on: https://docs.flutter.cn/community/china/

param(
    [ValidateSet('cfug', 'sjtu', 'tuna')]
    [string]$Mirror = 'cfug',
    [string]$InstallPath = "$env:USERPROFILE\dev"
)

$MirrorConfig = @{
    cfug = @{
        PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
        FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
    }
    sjtu = @{
        PUB_HOSTED_URL = 'https://mirror.sjtu.edu.cn/dart-pub'
        FLUTTER_STORAGE_BASE_URL = 'https://mirror.sjtu.edu.cn'
    }
    tuna = @{
        PUB_HOSTED_URL = 'https://mirrors.tuna.tsinghua.edu.cn/dart-pub'
        FLUTTER_STORAGE_BASE_URL = 'https://mirrors.tuna.tsinghua.edu.cn/flutter'
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

$env:PUB_HOSTED_URL = $MirrorConfig[$Mirror].PUB_HOSTED_URL
$env:FLUTTER_STORAGE_BASE_URL = $MirrorConfig[$Mirror].FLUTTER_STORAGE_BASE_URL

Write-Step "Flutter Auto Install (Mirror: $Mirror)"
Write-Info "Mirror Config:"
Write-Info "  PUB_HOSTED_URL: $($env:PUB_HOSTED_URL)"
Write-Info "  FLUTTER_STORAGE_BASE_URL: $($env:FLUTTER_STORAGE_BASE_URL)"

Write-Step "Step 1: Create install directory"
if (-not (Test-Path $InstallPath)) {
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    Write-Success "Created: $InstallPath"
} else {
    Write-Info "Directory exists: $InstallPath"
}

Write-Step "Step 2: Get latest Flutter version"
try {
    $releasesUrl = "$($env:FLUTTER_STORAGE_BASE_URL)/flutter_infra_release/releases/releases_windows.json"
    Write-Info "Fetching version info..."
    $releasesJson = Invoke-RestMethod -Uri $releasesUrl -TimeoutSec 30
    $latestStable = $releasesJson.releases | Where-Object { $_.channel -eq 'stable' } | Select-Object -First 1
    $version = $latestStable.version
    $archiveUrl = "$($env:FLUTTER_STORAGE_BASE_URL)/flutter_infra_release/releases/stable/windows/flutter_windows_${version}-stable.zip"
    $zipPath = Join-Path $InstallPath "flutter_windows_${version}-stable.zip"
    Write-Success "Latest stable: $version"
    Write-Info "Download: $archiveUrl"
} catch {
    Write-Info "Failed to get version, using fallback..."
    $version = "3.24.5"
    $archiveUrl = "$($env:FLUTTER_STORAGE_BASE_URL)/flutter_infra_release/releases/stable/windows/flutter_windows_${version}-stable.zip"
    $zipPath = Join-Path $InstallPath "flutter_windows_${version}-stable.zip"
    Write-Info "Using version: $version"
}

Write-Step "Step 3: Download Flutter SDK"
if (Test-Path $zipPath) {
    Write-Info "Zip exists, skipping download"
} else {
    Write-Info "Downloading (large file, please wait)..."
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFileAsync($archiveUrl, $zipPath)
        while ($webClient.IsBusy) {
            if (Test-Path $zipPath) {
                $fileSize = (Get-Item $zipPath).Length / 1MB
                Write-Host "`rDownloaded: $([math]::Round($fileSize, 2)) MB" -NoNewline
            }
            Start-Sleep -Milliseconds 500
        }
        Write-Host ""
        Write-Success "Download complete"
    } catch {
        Write-Info "Download failed, please download manually:"
        Write-Info "  URL: $archiveUrl"
        Write-Info "  Save to: $zipPath"
        exit 1
    }
}

Write-Step "Step 4: Extract Flutter SDK"
$flutterPath = Join-Path $InstallPath "flutter"
if (Test-Path $flutterPath) {
    $backupPath = "$flutterPath.old"
    Write-Info "Existing install, backup to: $backupPath"
    Move-Item -Path $flutterPath -Destination $backupPath -Force
}

Write-Info "Extracting (this may take a few minutes)..."
try {
    Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force
    Write-Success "Extraction complete"
} catch {
    Write-Info "Extraction failed, please extract manually"
    exit 1
}

Write-Step "Step 5: Set environment variables"
$binPath = "$flutterPath\bin"
$currentPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($currentPath -notlike "*$binPath*") {
    $newPath = "$binPath;$currentPath"
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Success "Added Flutter to PATH"
} else {
    Write-Info "Flutter already in PATH"
}

[System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', $env:PUB_HOSTED_URL, 'User')
[System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', $env:FLUTTER_STORAGE_BASE_URL, 'User')
Write-Success "Mirror environment variables set (permanent)"

Write-Step "Step 6: Verify installation"
Write-Info "First run downloads Dart SDK, please wait..."

& "$binPath\flutter.bat" doctor -v

Write-Step "Installation Complete!"
Write-Success "Flutter installed to: $flutterPath"
Write-Info "Close terminal and reopen, then run:"
Write-Info "  flutter doctor"
Write-Info "`nFor Android development, also install:"
Write-Info "  - Android Studio"
Write-Info "  - Android SDK"
