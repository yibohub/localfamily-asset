# Rust Core Multi-Platform Build Script for Windows
# Used for CI/CD automated builds

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

function Write-ColorOutput {
    param(
        [string]$Color,
        [string]$Message
    )
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $Color
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Info {
    Write-ColorOutput "Green" "[INFO] $args"
}

function Write-Warn {
    Write-ColorOutput "Yellow" "[WARN] $args"
}

function Write-Error {
    Write-ColorOutput "Red" "[ERROR] $args"
}

function Show-Help {
    Write-Output "Rust Core Multi-Platform Build Script (Windows)"
    Write-Output ""
    Write-Output "Usage: .\build_all.ps1 [Target...]"
    Write-Output ""
    Write-Output "Targets:"
    Write-Output "  windows-x64      Windows 64-bit"
    Write-Output "  linux-x64        Linux 64-bit (cross-compile)"
    Write-Output "  macos-x64        macOS 64-bit (cross-compile)"
    Write-Output "  android-arm64    Android ARM64"
    Write-Output "  android-armv7    Android ARMv7"
    Write-Output "  all              All platforms"
    Write-Output ""
    Write-Output "Environment Variables:"
    Write-Output "  PROFILE          Build profile (debug/release, default: release)"
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  .\build_all.ps1 windows-x64"
    Write-Output "  .\build_all.ps1 android-arm64 android-armv7"
    Write-Output "  `$env:PROFILE=debug; .\build_all.ps1 windows-x64"
}

function Test-Rustup {
    if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
        Write-Error "rustup not found. Install Rust from: https://rustup.rs/"
        exit 1
    }
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Write-Error "cargo not found"
        exit 1
    }
    Write-Info "Rust toolchain detected"
}

function Install-Target {
    param([string]$Target)
    $installed = rustup target list --installed 2>$null | Select-String -Pattern $Target
    if (-not $installed) {
        Write-Info "Installing Rust target: $Target"
        rustup target add $Target
    } else {
        Write-Info "Rust target already installed: $Target"
    }
}

function Build-Windows {
    Write-Info "Building Windows x64..."
    Install-Target "x86_64-pc-windows-msvc"
    Push-Location "$ProjectRoot\rust_core"
    cargo build --release --target x86_64-pc-windows-msvc
    Pop-Location
    Write-Info "✓ Windows build completed"
}

function Build-Linux {
    Write-Info "Building Linux x64 (cross-compile)..."
    Write-Warn "Linux cross-compilation on Windows may require additional setup"
    Write-Info "See: https://doc.rust-lang.org/rust/cross-compilation"
    Install-Target "x86_64-unknown-linux-gnu"
    Push-Location "$ProjectRoot\rust_core"
    cargo build --release --target x86_64-unknown-linux-gnu
    Pop-Location
    Write-Info "✓ Linux build completed"
}

function Build-macOS {
    Write-Info "Building macOS x64 (cross-compile)..."
    Write-Warn "macOS cross-compilation on Windows is not officially supported"
    Write-Info "Consider building on macOS hardware"
    Install-Target "x86_64-apple-darwin"
    Push-Location "$ProjectRoot\rust_core"
    cargo build --release --target x86_64-apple-darwin
    Pop-Location
    Write-Info "✓ macOS build completed"
}

function Build-Android-ARM64 {
    Write-Info "Building Android ARM64..."

    # Check NDK
    $ndkPath = "$env:LOCALAPPDATA\Android\Sdk\ndk"
    $ndkVersion = if (Test-Path "$ndkPath\27.0.12077973") { "27.0.12077973" }
                elseif (Test-Path "$ndkPath\26.1.10909125") { "26.1.10909125" }
                elseif (Test-Path "$ndkPath\25.2.9519653") { "25.2.9519653" }
                else { $null }

    if (-not $ndkVersion) {
        Write-Error "Android NDK not found. Please install Android NDK 25/26/27"
        exit 1
    }

    $env:ANDROID_NDK_ROOT = "$ndkPath\$ndkVersion"
    Write-Info "Using NDK: $env:ANDROID_NDK_ROOT"

    Install-Target "aarch64-linux-android"

    $toolchainBin = Join-Path $env:ANDROID_NDK_ROOT "toolchains\llvm\prebuilt\windows-x86_64\bin"
    $clangPath = Join-Path $toolchainBin "aarch64-linux-android21-clang.cmd"

    if (-not (Test-Path $clangPath)) {
        Write-Error "Clang not found: $clangPath"
        exit 1
    }

    # Set environment variables for cc crate
    $env:CC_AARCH64_LINUX_ANDROID = $clangPath
    $env:CXX_AARCH64_LINUX_ANDROID = "$clangPath.cmd"
    $env:AR_AARCH64_LINUX_ANDROID = Join-Path $toolchainBin "llvm-ar.exe"
    $env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $clangPath

    $env:CC = $clangPath
    $env:CXX = "$clangPath.cmd"
    $env:AR = Join-Path $toolchainBin "llvm-ar.exe"

    Push-Location "$ProjectRoot\rust_core"
    cargo build --release --target aarch64-linux-android
    Pop-Location

    # Clean environment variables
    Remove-Item Env:CC -ErrorAction SilentlyContinue
    Remove-Item Env:CXX -ErrorAction SilentlyContinue
    Remove-Item Env:AR -ErrorAction SilentlyContinue

    Write-Info "✓ Android ARM64 build completed"
}

function Build-Android-ARMv7 {
    Write-Info "Building Android ARMv7..."

    # Check NDK (same as ARM64)
    $ndkPath = "$env:LOCALAPPDATA\Android\Sdk\ndk"
    $ndkVersion = if (Test-Path "$ndkPath\27.0.12077973") { "27.0.12077973" }
                elseif (Test-Path "$ndkPath\26.1.10909125") { "26.1.10909125" }
                elseif (Test-Path "$ndkPath\25.2.9519653") { "25.2.9519653" }
                else { $null }

    if (-not $ndkVersion) {
        Write-Error "Android NDK not found. Please install Android NDK 25/26/27"
        exit 1
    }

    $env:ANDROID_NDK_ROOT = "$ndkPath\$ndkVersion"
    Write-Info "Using NDK: $env:ANDROID_NDK_ROOT"

    Install-Target "armv7-linux-androideabi"

    $toolchainBin = Join-Path $env:ANDROID_NDK_ROOT "toolchains\llvm\prebuilt\windows-x86_64\bin"
    $clangPath = Join-Path $toolchainBin "armv7a-linux-androideabi21-clang.cmd"

    if (-not (Test-Path $clangPath)) {
        Write-Error "Clang not found: $clangPath"
        exit 1
    }

    # Set environment variables for cc crate
    $env:CC_ARMV7_LINUX_ANDEROID_EABI = $clangPath
    $env:CXX_ARMV7_LINUX_ANDEROID_EABI = "$clangPath.cmd"
    $env:AR_ARMV7_LINUX_ANDEROID_EABI = Join-Path $toolchainBin "llvm-ar.exe"
    $env:CARGO_TARGET_ARMV7_LINUX_ANDEABI_EABI_LINKER = $clangPath

    $env:CC = $clangPath
    $env:CXX = "$clangPath.cmd"
    $env:AR = Join-Path $toolchainBin "llvm-ar.exe"

    Push-Location "$ProjectRoot\rust_core"
    cargo build --release --target armv7-linux-androideabi
    Pop-Location

    # Clean environment variables
    Remove-Item Env:CC -ErrorAction SilentlyContinue
    Remove-Item Env:CXX -ErrorAction SilentlyContinue
    Remove-Item Env:AR -ErrorAction SilentlyContinue

    Write-Info "✓ Android ARMv7 build completed"
}

# Main script
$targets = $args
if ($targets.Count -eq 0) {
    Show-Help
    exit 0
}

Test-Rustup

foreach ($target in $targets) {
    switch ($target) {
        "windows-x64" {
            Build-Windows
        }
        "linux-x64" {
            Build-Linux
        }
        "macos-x64" {
            Build-macOS
        }
        "android-arm64" {
            Build-Android-ARM64
        }
        "android-armv7" {
            Build-Android-ARMv7
        }
        "android" {
            Build-Android-ARM64
            Build-Android-ARMv7
        }
        "all" {
            Build-Windows
            Build-Linux
            Build-macOS
            Build-Android-ARM64
            Build-Android-ARMv7
        }
        default {
            Write-Error "Unknown target: $target"
            exit 1
        }
    }
}

Write-Info "All build tasks completed!"
