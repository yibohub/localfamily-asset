#!/bin/bash
# Rust Core 多平台编译脚本
# 用于 CI/CD 自动化构建

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助
show_help() {
    echo "Rust Core 多平台编译脚本"
    echo ""
    echo "用法: $0 [target...]"
    echo ""
    echo "目标:"
    echo "  windows-x64      Windows 64位"
    echo "  linux-x64        Linux 64位"
    echo "  macos-x64        macOS 64位"
    echo "  android-arm64    Android ARM64"
    echo "  android-armv7    Android ARMv7"
    echo "  all              所有平台"
    echo ""
    echo "环境变量:"
    echo "  PROFILE          编译配置 (debug/release, 默认: release)"
    echo ""
    echo "示例:"
    echo "  $0 windows-x64"
    echo "  $0 android-arm64 android-armv7"
    echo "  PROFILE=debug $0 linux-x64"
}

# 检测工具
check_tools() {
    if ! command -v rustup &> /dev/null; then
        log_error "未找到 rustup，请先安装 Rust: https://rustup.rs/"
        exit 1
    fi

    if ! command -v cargo &> /dev/null; then
        log_error "未找到 cargo"
        exit 1
    fi
}

# 安装 Rust target
install_target() {
    local target=$1
    if ! rustup target list --installed | grep -q "$target"; then
        log_info "安装 Rust target: $target"
        rustup target add "$target"
    else
        log_info "Rust target 已安装: $target"
    fi
}

# 编译 Windows 版本
build_windows() {
    log_info "编译 Windows x64 版本..."
    install_target "x86_64-pc-windows-msvc"
    cd "$PROJECT_ROOT/rust_core"
    cargo build --profile "${PROFILE:-release}" --target x86_64-pc-windows-msvc
    log_info "✓ Windows 版本编译完成"
}

# 编译 Linux 版本
build_linux() {
    log_info "编译 Linux x64 版本..."
    install_target "x86_64-unknown-linux-gnu"
    cd "$PROJECT_ROOT/rust_core"
    cargo build --profile "${PROFILE:-release}" --target x86_64-unknown-linux-gnu
    log_info "✓ Linux 版本编译完成"
}

# 编译 macOS 版本
build_macos() {
    log_info "编译 macOS x64 版本..."
    install_target "x86_64-apple-darwin"
    cd "$PROJECT_ROOT/rust_core"
    cargo build --profile "${PROFILE:-release}" --target x86_64-apple-darwin
    log_info "✓ macOS 版本编译完成"
}

# 编译 Android ARM64
build_android_arm64() {
    log_info "编译 Android ARM64 版本..."

    # 检查 NDK
    if [ -z "$ANDROID_NDK_ROOT" ]; then
        # 尝试常见 NDK 路径
        for ndk_path in \
            "$ANDROID_SDK_ROOT/ndk" \
            "$HOME/Android/Sdk/ndk" \
            "/usr/local/lib/android-sdk/ndk"; do
            if [ -d "$ndk_path" ]; then
                export ANDROID_NDK_ROOT="$ndk_path"
                break
            fi
        done

        if [ -z "$ANDROID_NDK_ROOT" ]; then
            log_error "未找到 Android NDK，请设置 ANDROID_NDK_ROOT 环境变量"
            exit 1
        fi
    fi

    log_info "使用 NDK: $ANDROID_NDK_ROOT"

    install_target "aarch64-linux-android"

    # 设置编译器环境变量
    TOOLCHAIN_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
    export CC="$TOOLCHAIN_BIN/aarch64-linux-android21-clang"
    export CXX="$TOOLCHAIN_BIN/aarch64-linux-android21-clang++"
    export AR="$TOOLCHAIN_BIN/llvm-ar"

    cd "$PROJECT_ROOT/rust_core"
    cargo build --profile "${PROFILE:-release}" --target aarch64-linux-android
    log_info "✓ Android ARM64 版本编译完成"
}

# 编译 Android ARMv7
build_android_armv7() {
    log_info "编译 Android ARMv7 版本..."

    # 检查 NDK (同上)
    if [ -z "$ANDROID_NDK_ROOT" ]; then
        for ndk_path in \
            "$ANDROID_SDK_ROOT/ndk" \
            "$HOME/Android/Sdk/ndk" \
            "/usr/local/lib/android-sdk/ndk"; do
            if [ -d "$ndk_path" ]; then
                export ANDROID_NDK_ROOT="$ndk_path"
                break
            fi
        done

        if [ -z "$ANDROID_NDK_ROOT" ]; then
            log_error "未找到 Android NDK，请设置 ANDROID_NDK_ROOT 环境变量"
            exit 1
        fi
    fi

    log_info "使用 NDK: $ANDROID_NDK_ROOT"

    install_target "armv7-linux-androideabi"

    # 设置编译器环境变量
    TOOLCHAIN_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
    export CC="$TOOLCHAIN_BIN/armv7a-linux-androideabi21-clang"
    export CXX="$TOOLCHAIN_BIN/armv7a-linux-androideabi21-clang++"
    export AR="$TOOLCHAIN_BIN/llvm-ar"

    cd "$PROJECT_ROOT/rust_core"
    cargo build --profile "${PROFILE:-release}" --target armv7-linux-androideabi
    log_info "✓ Android ARMv7 版本编译完成"
}

# 主函数
main() {
    PROFILE=${PROFILE:-release}

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    check_tools

    cd "$PROJECT_ROOT"

    for target in "$@"; do
        case $target in
            windows-x64)
                build_windows
                ;;
            linux-x64)
                build_linux
                ;;
            macos-x64)
                build_macos
                ;;
            android-arm64)
                build_android_arm64
                ;;
            android-armv7)
                build_android_armv7
                ;;
            android)
                build_android_arm64
                build_android_armv7
                ;;
            all)
                build_windows
                build_linux
                build_macos
                build_android_arm64
                build_android_armv7
                ;;
            *)
                log_error "未知目标: $target"
                exit 1
                ;;
        esac
    done

    log_info "所有编译任务完成！"
}

main "$@"
