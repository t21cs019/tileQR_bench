#!/usr/bin/env bash
# =============================================================================
# config.sh — tileQR_bench 共通設定
# すべてのスクリプトはこのファイルを source して使う
# =============================================================================

# --- インストール先 -----------------------------------------------------------
export PLASMA_BENCH_LIBS="${HOME}/Library"
export OPENBLAS_INSTALL="${PLASMA_BENCH_LIBS}/openblas"
export PLASMA_INSTALL="${PLASMA_BENCH_LIBS}/plasma"

# --- lib / lib64 自動判定 -----------------------------------------------------
# PLASMA/OpenBLAS が lib か lib64 どちらに入るかは環境依存。
# 実際に存在する方を採用する（存在しなければ lib を既定とする）。
detect_libdir() {
    local prefix="$1"
    if [ -d "${prefix}/lib64" ] && ls "${prefix}/lib64/"*.so* &>/dev/null; then
        echo "${prefix}/lib64"
    else
        echo "${prefix}/lib"
    fi
}
export OPENBLAS_LIBDIR="$(detect_libdir "${OPENBLAS_INSTALL}")"
export PLASMA_LIBDIR="$(detect_libdir "${PLASMA_INSTALL}")"

# --- 実行バイナリ -------------------------------------------------------------
export PLASMA_TEST="${PLASMA_INSTALL}/bin/plasmatest"

# --- ビルド設定 ---------------------------------------------------------------
export NUM_MAKE_JOBS="$(nproc)"

# --- ソースのダウンロードURL --------------------------------------------------
OPENBLAS_VERSION="0.3.28"
export OPENBLAS_VERSION
export OPENBLAS_URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/v${OPENBLAS_VERSION}/OpenBLAS-${OPENBLAS_VERSION}.tar.gz"
export PLASMA_GIT_URL="https://github.com/icl-utk-edu/plasma.git"

# --- Python / uv 環境 ---------------------------------------------------------
export UV_INSTALL_DIR="${HOME}/.local/bin"
export PATH="${UV_INSTALL_DIR}:${PATH}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLASMA_BENCH_VENV="${REPO_ROOT}/.venv"

# --- 計測機オプション ---------------------------------------------------------
# Tailscale を 00_bootstrap.sh で導入するか（1=導入, 0=スキップ）
export INSTALL_TAILSCALE="${INSTALL_TAILSCALE:-1}"

# --- 計測時の環境固定 ---------------------------------------------------------
# BLAS 内部スレッドを無効化（PLASMA 側で並列するため必須）
export OPENBLAS_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# --- ライブラリパス（自動判定した libdir を使用） -----------------------------
export LD_LIBRARY_PATH="${OPENBLAS_LIBDIR}:${PLASMA_LIBDIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
