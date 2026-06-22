#!/usr/bin/env bash
# =============================================================================
# install_openblas.sh — OpenBLAS をソースからビルド・インストール
# 管理者権限不要。${OPENBLAS_INSTALL} にインストールする。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

WORK_DIR="${HOME}/Download/build_openblas"
TARBALL="${WORK_DIR}/openblas.tar.gz"

echo "======================================================"
echo " OpenBLAS インストール開始"
echo " インストール先: ${OPENBLAS_INSTALL}"
echo "======================================================"

# すでにインストール済みか確認
if [ -f "${OPENBLAS_INSTALL}/lib/libopenblas.so" ]; then
    echo "[SKIP] OpenBLAS はすでにインストール済みです。"
    echo "       再インストールしたい場合は ${OPENBLAS_INSTALL} を削除してください。"
    exit 0
fi

# 作業ディレクトリの準備
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# ダウンロード
if [ ! -f "${TARBALL}" ]; then
    echo "[1/4] OpenBLAS ${OPENBLAS_VERSION} をダウンロードしています..."
    wget -q --show-progress -O "${TARBALL}" "${OPENBLAS_URL}"
else
    echo "[1/4] 既存のtarballを使用します: ${TARBALL}"
fi

# 展開
echo "[2/4] 展開しています..."
SRC_DIR="OpenBLAS-${OPENBLAS_VERSION}"
if [ ! -d "${SRC_DIR}" ]; then
    tar xzf "${TARBALL}"
fi
cd "${SRC_DIR}"

# ビルド
echo "[3/4] ビルドしています（${NUM_MAKE_JOBS} 並列）..."
make -j"${NUM_MAKE_JOBS}" \
    USE_THREAD=1 \
    USE_OPENMP=1 \
    NO_SHARED=0

# インストール
echo "[4/4] インストールしています -> ${OPENBLAS_INSTALL}"
make install PREFIX="${OPENBLAS_INSTALL}"

echo ""
echo "[完了] OpenBLAS のインストールが完了しました。"
echo "       ライブラリ: ${OPENBLAS_INSTALL}/lib/libopenblas.so"