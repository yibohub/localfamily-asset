#!/usr/bin/env bash
# =============================================================================
# Rust Core -> OpenHarmony/HarmonyOS NEXT 交叉编译，并复制 .so 到 ohos 工程
#
# 用法（仓库根目录或任意目录执行均可）：
#   scripts/build-ohos.sh                 # DevEco/OHOS SDK clang 交叉编译 arm64
#   scripts/build-ohos.sh --zig           # cargo-zigbuild 编译（无需 DevEco，适合 Linux/CI）
#   OHOS_TARGETS="aarch64-unknown-linux-ohos x86_64-unknown-linux-ohos" scripts/build-ohos.sh
#
# 环境变量：
#   OHOS_NATIVE_HOME  直接指定 OpenHarmony native SDK 目录（含 llvm/bin）
#   DEVECO_SDK_HOME   DevEco Studio 的 sdk 目录（自动探测 default/openharmony/native）
#   OHOS_TARGETS      编译目标列表，默认 aarch64-unknown-linux-ohos（真机 arm64）
#
# 产物：flutter_app/ohos/entry/libs/<abi>/liblocalfamily_asset_core.so
#       （hvigor 打 HAP 时自动打包该目录，Dart 端按 soname 直接 open）
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="sdk"
[ "${1:-}" = "--zig" ] && MODE="zig"

TARGETS="${OHOS_TARGETS:-aarch64-unknown-linux-ohos}"
RUST_CRATE_DIR="$REPO_ROOT/rust_core"
OHOS_LIBS_ROOT="$REPO_ROOT/flutter_app/ohos/entry/libs"

# Rust target -> HAP 中的 ABI 目录名
abi_dir_for() {
  case "$1" in
    aarch64-unknown-linux-ohos) echo "arm64-v8a" ;;
    armv7-unknown-linux-ohos)   echo "armeabi-v7a" ;;
    x86_64-unknown-linux-ohos)  echo "x86_64" ;;
    *) echo ""; return 1 ;;
  esac
}

# Rust target -> OHOS SDK clang 目标前缀（aarch64-unknown-linux-ohos-clang 等）
clang_prefix_for() {
  case "$1" in
    aarch64-unknown-linux-ohos) echo "aarch64-unknown-linux-ohos" ;;
    armv7-unknown-linux-ohos)   echo "armv7-unknown-linux-ohos" ;;
    x86_64-unknown-linux-ohos)  echo "x86_64-unknown-linux-ohos" ;;
    *) echo ""; return 1 ;;
  esac
}

# 探测 OpenHarmony native SDK（DevEco Studio 自带或独立 command-line tools）
resolve_native_sdk() {
  local candidates=(
    "${OHOS_NATIVE_HOME:-}"
    "${DEVECO_SDK_HOME:-/dev/null}/default/openharmony/native"
    "${DEVECO_SDK_HOME:-/dev/null}/openharmony/native"
    "/c/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native"
    "$HOME/AppData/Local/Huawei/Sdk/default/openharmony/native"
    "$HOME/Library/Huawei/Sdk/default/openharmony/native"
    "/opt/openharmony/native"
    "/opt/ohos-sdk/native"
  )
  local c
  for c in "${candidates[@]}"; do
    if [ -n "$c" ] && [ -x "$c/llvm/bin/clang" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

command -v cargo >/dev/null 2>&1 || { echo "错误：未找到 cargo，请先安装 Rust（https://rustup.rs）" >&2; exit 1; }

for target in $TARGETS; do
  abi="$(abi_dir_for "$target")" || { echo "错误：不支持的 ohos 目标 $target" >&2; exit 1; }
  echo "==> [$target] 开始编译（产物 ABI 目录：$abi）"

  rustup target add "$target"

  if [ "$MODE" = "zig" ]; then
    # cargo-zigbuild 用 zig 充当链接器/交叉 cc，无需 OHOS SDK（CI/Linux 场景）
    command -v cargo-zigbuild >/dev/null 2>&1 || {
      echo "错误：未找到 cargo-zigbuild（pip install cargo-zigbuild）" >&2; exit 1;
    }
    (cd "$RUST_CRATE_DIR" && cargo zigbuild --release --target "$target")
  else
    native_sdk="$(resolve_native_sdk)" || {
      cat >&2 <<'EOF'
错误：未找到 OpenHarmony native SDK（含 llvm/bin/clang）。
请安装 DevEco Studio（含 OpenHarmony SDK），或设置环境变量：
  export OHOS_NATIVE_HOME=/path/to/sdk/default/openharmony/native
  # 或
  export DEVECO_SDK_HOME=/path/to/deveco/sdk
也可改用 zig 方案（无需 SDK）：scripts/build-ohos.sh --zig
EOF
      exit 1
    }
    tc_bin="$native_sdk/llvm/bin"
    prefix="$(clang_prefix_for "$target")"
    if [ ! -x "$tc_bin/$prefix-clang" ]; then
      echo "错误：$tc_bin 下未找到 $prefix-clang，请确认 SDK 版本完整性" >&2
      exit 1
    fi
    echo "    使用工具链：$tc_bin/$prefix-clang"
    var_suffix="${target//-/_}"  # aarch64_unknown_linux_ohos
    (cd "$RUST_CRATE_DIR" &&
      export "CC_${var_suffix}=$tc_bin/$prefix-clang" &&
      export "CXX_${var_suffix}=$tc_bin/$prefix-clang++" &&
      export "AR_${var_suffix}=$tc_bin/llvm-ar" &&
      export "CARGO_TARGET_${var_suffix^^}_LINKER=$tc_bin/$prefix-clang" &&
      cargo build --release --target "$target")
  fi

  so="${CARGO_TARGET_DIR:-$RUST_CRATE_DIR/target}/$target/release/liblocalfamily_asset_core.so"
  [ -f "$so" ] || { echo "错误：未找到编译产物 $so" >&2; exit 1; }
  mkdir -p "$OHOS_LIBS_ROOT/$abi"
  cp -f "$so" "$OHOS_LIBS_ROOT/$abi/"
  echo "==> [$target] 已复制到 flutter_app/ohos/entry/libs/$abi/liblocalfamily_asset_core.so"
done

echo "完成。接下来：cd flutter_app && flutter build hap --release（或用 DevEco Studio 打开 flutter_app/ohos 运行）"
