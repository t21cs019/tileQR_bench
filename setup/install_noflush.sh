#!/usr/bin/env bash
# =============================================================================
# install_noflush.sh — Tune_SSRFB を GitHub からcloneしてNoFlushをビルド
# 管理者権限不要。${NOFLUSH_PATH} の親ディレクトリにインストールする。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

NOFLUSH_DIR="$(dirname "${NOFLUSH_PATH}")"
WORK_DIR="${HOME}/Download/build_noflush"
SRC_DIR="${WORK_DIR}/Tune_SSRFB"
NOFLUSH_GIT_URL="https://github.com/stomo0511/Tune_SSRFB.git"

echo "======================================================"
echo " NoFlush（Tune_SSRFB）インストール開始"
echo " インストール先: ${NOFLUSH_PATH}"
echo "======================================================"

# すでにインストール済みか確認
if [ -f "${NOFLUSH_PATH}" ]; then
    echo "[SKIP] NoFlush はすでにインストール済みです。"
    echo "       再インストールしたい場合は ${NOFLUSH_PATH} を削除してください。"
    exit 0
fi

# ソースの取得
mkdir -p "${WORK_DIR}"
if [ -d "${SRC_DIR}/.git" ]; then
    echo "[1/3] 既存のソースを使用します: ${SRC_DIR}"
    cd "${SRC_DIR}"
    git pull --ff-only || echo "       git pull をスキップ（ローカル変更あり）"
else
    echo "[1/3] Tune_SSRFB を git clone しています..."
    cd "${WORK_DIR}"
    git clone "${NOFLUSH_GIT_URL}" Tune_SSRFB
    cd "${SRC_DIR}"
fi

# ビルド
echo "[2/3] ビルドしています..."
cd "${SRC_DIR}"

g++ -m64 -fopenmp -O3 \
    -I"${PLASMA_INSTALL}/include" \
    -I"${OPENBLAS_INSTALL}/include" \
    -o NoFlush NoFlush.cpp \
    -L"${PLASMA_INSTALL}/lib" \
    -L"${OPENBLAS_INSTALL}/lib" \
    -lplasma -lplasma_core_blas -lopenblas \
    -Wl,-rpath,"${PLASMA_INSTALL}/lib" \
    -Wl,-rpath,"${OPENBLAS_INSTALL}/lib"

# NoFlush バイナリの確認
if [ ! -f "${SRC_DIR}/NoFlush" ]; then
    echo "[ERROR] ビルドに失敗しました。NoFlush バイナリが見つかりません。"
    exit 1
fi

# インストール先にコピー
echo "[3/3] インストールしています -> ${NOFLUSH_PATH}"
mkdir -p "${NOFLUSH_DIR}"
cp "${SRC_DIR}/NoFlush" "${NOFLUSH_PATH}"
chmod +x "${NOFLUSH_PATH}"

echo ""
echo "[完了] NoFlush のインストールが完了しました。"
echo "       実行ファイル: ${NOFLUSH_PATH}"