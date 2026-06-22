#!/usr/bin/env bash
# =============================================================================
# install_plasma.sh — PLASMA を GitHub からcloneしてビルド・インストール
# 管理者権限不要。${PLASMA_INSTALL} にインストールする。
# OpenBLAS のインストールが先に完了している必要がある。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

WORK_DIR="${HOME}/Download/build_plasma"
SRC_DIR="${WORK_DIR}/plasma"

echo "======================================================"
echo " PLASMA インストール開始"
echo " インストール先: ${PLASMA_INSTALL}"
echo "======================================================"

# OpenBLAS の確認
if ! ls "${OPENBLAS_LIBDIR}"/libopenblas.so &>/dev/null; then
    echo "[ERROR] OpenBLAS が見つかりません: ${OPENBLAS_LIBDIR}/libopenblas.so"
    echo "        先に install_openblas.sh を実行してください。"
    exit 1
fi

# すでにインストール済みか確認
if [ -f "${PLASMA_TEST}" ]; then
    echo "[SKIP] PLASMA はすでにインストール済みです。"
    echo "       再インストールしたい場合は ${PLASMA_INSTALL} を削除してください。"
    exit 0
fi

# 必要なコマンドの確認
for cmd in cmake python3 gfortran git; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "[ERROR] '${cmd}' が見つかりません。インストールしてください。"
        exit 1
    fi
done

mkdir -p "${WORK_DIR}"

# ソースの取得
if [ -d "${SRC_DIR}/.git" ]; then
    echo "[1/3] 既存のソースを使用します: ${SRC_DIR}"
    cd "${SRC_DIR}"
    git pull --ff-only || echo "       git pull をスキップ（ローカル変更あり）"
else
    echo "[1/3] PLASMA を git clone しています..."
    cd "${WORK_DIR}"
    git clone "${PLASMA_GIT_URL}" plasma
    cd "${SRC_DIR}"
fi

# CMake ビルド
echo "[2/3] CMake でビルドしています..."
mkdir -p build && cd build

# OpenBLAS の .so を実在パスから解決（lib / lib64 両対応）
OPENBLAS_SO="$(ls "${OPENBLAS_LIBDIR}"/libopenblas.so 2>/dev/null | head -n1)"
if [ -z "${OPENBLAS_SO}" ]; then
    echo "[ERROR] libopenblas.so が見つかりません: ${OPENBLAS_LIBDIR}"
    exit 1
fi
echo "       OpenBLAS lib: ${OPENBLAS_SO}"

cmake .. \
    -DCMAKE_INSTALL_PREFIX="${PLASMA_INSTALL}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBLAS_LIBRARIES="${OPENBLAS_SO}" \
    -DLAPACK_LIBRARIES="${OPENBLAS_SO}" \
    -DLAPACKE_LIBRARIES="${OPENBLAS_SO}" \
    -DCBLAS_INCLUDE_DIRS="${OPENBLAS_INSTALL}/include" \
    -DLAPACKE_INCLUDE_DIRS="${OPENBLAS_INSTALL}/include"

make -j"${NUM_MAKE_JOBS}"

# インストール
echo "[3/3] インストールしています -> ${PLASMA_INSTALL}"
make install

# make install で漏れるヘッダを手動でコピー
cp "${SRC_DIR}"/include/plasma_core_blas_*.h "${PLASMA_INSTALL}/include/"
cp "${SRC_DIR}"/include/core_lapack*.h "${PLASMA_INSTALL}/include/"

# インストール後、実際の libdir を再判定（config.sh source 時点では未ビルドのため）
export PLASMA_LIBDIR="$(detect_libdir "${PLASMA_INSTALL}")"
echo "       PLASMA lib: ${PLASMA_LIBDIR}"

echo ""
echo "[完了] PLASMA のインストールが完了しました。"
echo "       テストバイナリ: ${PLASMA_TEST}"

# --- ライブラリパスの永続化 ---------------------------------------------------
# ~/.bashrc に LD_LIBRARY_PATH を追記（重複追記を防ぐ）
BASHRC="${HOME}/.bashrc"
MARKER="# plasma-bench: library paths"

if ! grep -q "${MARKER}" "${BASHRC}" 2>/dev/null; then
    cat >> "${BASHRC}" << BASHRC_EOF

${MARKER}
export LD_LIBRARY_PATH="${OPENBLAS_LIBDIR}:${PLASMA_LIBDIR}\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
BASHRC_EOF
    echo "       LD_LIBRARY_PATH を ~/.bashrc に追記しました。"
    echo "       次回ログイン以降に自動で有効になります。"
fi

# 現在のシェルでも即時有効化
export LD_LIBRARY_PATH="${OPENBLAS_LIBDIR}:${PLASMA_LIBDIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
echo "       LD_LIBRARY_PATH を現在のシェルで有効化しました。"