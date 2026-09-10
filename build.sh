#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out}"
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
CLANG_TRIPLE="${CLANG_TRIPLE:-aarch64-linux-gnu-}"

DEFCONFIG_FILE="${ROOT_DIR}/arch/arm64/boot/configs/vili_defconfig"
if [ ! -f "${DEFCONFIG_FILE}" ]; then
    DEFCONFIG_FILE="${ROOT_DIR}/arch/arm64/configs/vili_defconfig"
fi

if [ ! -f "${DEFCONFIG_FILE}" ]; then
    echo "ERROR: vili defconfig not found at ${ROOT_DIR}/arch/arm64/boot/configs/vili_defconfig or ${ROOT_DIR}/arch/arm64/configs/vili_defconfig" >&2
    exit 1
fi

CLANG_BIN="${CLANG_BIN:-$(command -v clang || true)}"
if [ -z "${CLANG_BIN}" ] || [ ! -x "${CLANG_BIN}" ]; then
    echo "ERROR: clang not found in PATH. Install LLVM 20+ and re-run this script." >&2
    exit 1
fi

CLANG_MAJOR="$(${CLANG_BIN} --version | head -n 1 | sed -E 's/.*clang version ([0-9]+)(\.[0-9]+)?(\.[0-9]+)?.*/\1/' || true)"
if [ -z "${CLANG_MAJOR}" ] || [ "${CLANG_MAJOR}" -lt 20 ]; then
    echo "ERROR: Clang 20 or newer is required for this build; found ${CLANG_MAJOR:-unknown} from ${CLANG_BIN}" >&2
    echo "   Recommended upstream LLVM toolchain: clang+llvm-20.1.0-x86_64-linux-gnu-ubuntu-24.04.tar.xz" >&2
    exit 1
fi

AARCH64_GCC="${CROSS_COMPILE}gcc"
if ! command -v "${AARCH64_GCC}" >/dev/null 2>&1; then
    echo "ERROR: ${AARCH64_GCC} is required for the cross compiler toolchain." >&2
    echo "   On Ubuntu/Debian runners: sudo apt-get install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"
cp "${DEFCONFIG_FILE}" "${OUT_DIR}/.config"

make -C "${ROOT_DIR}" \
    O="${OUT_DIR}" \
    ARCH=arm64 \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    CLANG_TRIPLE="${CLANG_TRIPLE}" \
    CC=clang \
    LD=ld.lld \
    REAL_CC=clang \
    olddefconfig

make -C "${ROOT_DIR}" \
    O="${OUT_DIR}" \
    ARCH=arm64 \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    CLANG_TRIPLE="${CLANG_TRIPLE}" \
    CC=clang \
    LD=ld.lld \
    REAL_CC=clang \
    -j"$(nproc)" \
    Image.gz

if [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ]; then
    ls -lh "${OUT_DIR}/arch/arm64/boot/Image.gz"
else
    echo "ERROR: build completed without producing ${OUT_DIR}/arch/arm64/boot/Image.gz" >&2
    ls -R "${OUT_DIR}/arch/arm64/boot" 2>/dev/null || true
    exit 1
fi
