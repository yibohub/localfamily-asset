# Rust Core Android Build Script
# 用于编译 Rust Core 到 Android 各架构

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "  Rust Core Android Build Script"
Write-ColorOutput Green "=========================================="
Write-Output ""

# 检查 NDK 路径
$ndkPath = "$env:LOCALAPPDATA\Android\Sdk\ndk"
if (Test-Path "$ndkPath\27.0.12077973") {
    $ndkVersion = "27.0.12077973"
} elseif (Test-Path "$ndkPath\26.1.10909125") {
    $ndkVersion = "26.1.10909125"
} elseif (Test-Path "$ndkPath\25.2.9519653") {
    $ndkVersion = "25.2.9519653"
} else {
    Write-ColorOutput Red "未找到 Android NDK"
    Write-Output "请安装 Android NDK (版本 25/26/27)"
    Write-Output "下载地址: https://developer.android.com/ndk/downloads"
    exit 1
}

$ndkPath = "$ndkPath\$ndkVersion"
Write-ColorOutput Cyan "使用 NDK: $ndkPath"

# NDK 工具链路径
$toolchainBin = Join-Path $ndkPath "toolchains\llvm\prebuilt\windows-x86_64\bin"
Write-ColorOutput Cyan "工具链路径: $toolchainBin"

# Android 架构配置
$architectures = @(
    @{ Name = "arm64-v8a"; RustTarget = "aarch64-linux-android"; ApiLevel = "21"; Clang = "aarch64-linux-android21-clang"; Enable = $true },
    @{ Name = "armeabi-v7a"; RustTarget = "armv7-linux-androideabi"; ApiLevel = "21"; Clang = "armv7a-linux-androideabi21-clang"; Enable = $true },
    @{ Name = "x86_64"; RustTarget = "x86_64-linux-android"; ApiLevel = "21"; Clang = "x86_64-linux-android21-clang"; Enable = $false },
    @{ Name = "x86"; RustTarget = "i686-linux-android"; ApiLevel = "21"; Clang = "i686-linux-android21-clang"; Enable = $false }
)

# 输出目录
$outputDir = Join-Path $PSScriptRoot "target\android"
Write-Output ""
Write-ColorOutput Cyan "输出目录: $outputDir"

# 创建输出目录
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# 编译计数器
$successCount = 0
$totalCount = 0

# 编译各架构
foreach ($arch in $architectures) {
    if (-not $arch.Enable) {
        Write-Output "跳过架构: $($arch.Name)"
        continue
    }

    $totalCount++
    Write-Output ""
    Write-ColorOutput Yellow "=========================================="
    Write-ColorOutput Yellow "编译架构: $($arch.Name)"
    Write-ColorOutput Yellow "Rust 目标: $($arch.RustTarget)"
    Write-ColorOutput Yellow "API Level: $($arch.ApiLevel)"
    Write-ColorOutput Yellow "=========================================="

    try {
        # 安装 Rust target（如果尚未安装）
        $targetInstalled = rustup target list --installed | Select-String -Pattern $arch.RustTarget
        if (-not $targetInstalled) {
            Write-Output "安装 Rust target: $($arch.RustTarget)"
            rustup target add $arch.RustTarget
        }

        # 设置 clang 路径
        $clangPath = Join-Path $toolchainBin "$($arch.Clang).cmd"
        $clangxxPath = Join-Path $toolchainBin "$($arch.Clang)++.cmd"
        $arPath = Join-Path $toolchainBin "llvm-ar.exe"

        if (-not (Test-Path $clangPath)) {
            Write-ColorOutput Red "✗ 找不到 clang: $clangPath"
            continue
        }

        Write-Output "使用 clang: $clangPath"

        # 设置 C/C++ 编译器和链接器环境变量（供 cc crate 使用）
        $targetUpper = $arch.RustTarget.Replace("-", "_").ToUpper()
        $ccEnvName = "CC_$targetUpper"
        $cxxEnvName = "CXX_$targetUpper"
        $arEnvName = "AR_$targetUpper"
        $linkerEnvName = "CARGO_TARGET_${targetUpper}_LINKER"
        $cflagsEnvName = "CFLAGS_$targetUpper"
        $cxxflagsEnvName = "CXXFLAGS_$targetUpper"

        [System.Environment]::SetEnvironmentVariable($ccEnvName, $clangPath, "Process")
        [System.Environment]::SetEnvironmentVariable($cxxEnvName, $clangxxPath, "Process")
        [System.Environment]::SetEnvironmentVariable($arEnvName, $arPath, "Process")
        [System.Environment]::SetEnvironmentVariable($linkerEnvName, $clangPath, "Process")

        # 设置通用的 CC/CXX/AR（cc crate 会检查这些）
        $env:CC = $clangPath
        $env:CXX = $clangxxPath
        $env:AR = $arPath

        # 设置 CFLAGS 添加 Android API level
        $cflagsValue = "--target=$($arch.RustTarget) -DANDROID_API_LEVEL=$($arch.ApiLevel)"
        [System.Environment]::SetEnvironmentVariable($cflagsEnvName, $cflagsValue, "Process")
        [System.Environment]::SetEnvironmentVariable($cxxflagsEnvName, $cflagsValue, "Process")

        Write-Output "开始编译..."
        cargo build --release --target $arch.RustTarget

        # 复制输出文件
        $libName = "liblocalfamily_asset_core.so"
        $sourceLib = Join-Path $PSScriptRoot "target\$($arch.RustTarget)\release\$libName"
        $destLib = Join-Path $outputDir "$($arch.Name)\$libName"
        $destDir = Split-Path $destLib -Parent

        if (Test-Path $sourceLib) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            Copy-Item $sourceLib $destLib -Force
            $successCount++
            Write-ColorOutput Green "✓ 编译成功: $($arch.Name)"
        } else {
            Write-ColorOutput Red "✗ 未找到输出文件: $sourceLib"
        }
    }
    catch {
        Write-ColorOutput Red "✗ 编译失败: $($arch.Name)"
        Write-ColorOutput Red $_.Exception.Message
    }
}

# 清理环境变量
Remove-Item Env:CC -ErrorAction SilentlyContinue
Remove-Item Env:CXX -ErrorAction SilentlyContinue
Remove-Item Env:AR -ErrorAction SilentlyContinue

# 总结
Write-Output ""
Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "编译完成"
Write-ColorOutput Green "成功: $successCount / $totalCount"
Write-ColorOutput Green "=========================================="

if ($successCount -gt 0) {
    Write-Output ""
    Write-ColorOutput Cyan "输出文件位置:"
    Get-ChildItem -Path (Join-Path $outputDir "*") -Directory | ForEach-Object {
        Write-Output "  $($_.FullName)"
    }

    Write-Output ""
    Write-ColorOutput Yellow "下一步: 将 .so 文件复制到 Flutter 项目"
    Write-Output "  flutter_app\android\app\src\main\jniLibs\"
}

exit 0
