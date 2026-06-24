#!/usr/bin/env bash
# =============================================================================
# quickstart.sh — 新しいサーバで計測環境を最短セットアップする
#
# やること:
#   1. ビルドに必要なツールが揃っているか確認（module は自動 load しない）
#   2. 既に ~/Library にビルド済みなら install をスキップ
#   3. 揃っていれば install.sh（OpenBLAS + PLASMA ビルド）を実行
#   4. check.sh で最終確認
#
# 使い方:
#   git clone https://github.com/t21cs019/tileQR_bench.git
#   cd tileQR_bench
#   bash setup/quickstart.sh
#
# 注意:
#   - sudo は使いません。すべて ~/Library 配下にインストールします。
#   - ツールが足りない場合は module で供給してから再実行してください。
#       module avail            # 使えるモジュールを探す
#       module load gcc cmake   # 例（名前はサーバごとに異なる）
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "======================================================"
echo " tileQR_bench quickstart: $(hostname -s)"
echo "======================================================"

# --- 1. ビルドツールの確認 ----------------------------------------------------
echo ""
echo ">>> [1/3] ビルドツールの確認"
MISSING=0
for cmd in gcc gfortran make cmake git wget python3; do
    if command -v "${cmd}" &>/dev/null; then
        echo "  [OK]      ${cmd}"
    else
        echo "  [MISSING] ${cmd}"
        MISSING=$((MISSING+1))
    fi
done

if [ "${MISSING}" -gt 0 ]; then
    echo ""
    echo "[STOP] 必要なツールが ${MISSING} 個不足しています。"
    echo "       このサーバでは module で供給できることが多いです:"
    echo "         module avail              # 使えるモジュールを一覧"
    echo "         module load gcc cmake     # 例（名前はサーバごとに異なる）"
    echo "       供給してから、もう一度このスクリプトを実行してください。"
    exit 1
fi

# --- 2. 既存ビルドの検出（あれば install をスキップ） -------------------------
echo ""
echo ">>> [2/3] 既存ビルドの確認: ${PLASMA_TEST}"
if [ -f "${PLASMA_TEST}" ]; then
    echo "  [SKIP] PLASMA はすでにビルド済みです。install.sh をスキップします。"
    echo "         再ビルドしたい場合は ${PLASMA_INSTALL} を削除してください。"
else
    echo "  ビルドが見つかりません。install.sh を実行します。"
    echo ""
    bash "${SCRIPT_DIR}/install.sh"
fi

# --- 3. 最終確認 --------------------------------------------------------------
echo ""
echo ">>> [3/3] 環境チェック（check.sh）"
echo ""
bash "${SCRIPT_DIR}/check.sh"
rc=$?

echo ""
echo "======================================================"
if [ "${rc}" -eq 0 ]; then
    echo " quickstart 完了。計測に進めます:"
    echo "   bash scripts/estimate_time.sh"
else
    echo " check.sh に FAIL があります。"
    echo " CPU governor の FAIL は共有サーバでは無視して構いません"
    echo " （計測の実行には影響しません）。"
    echo " OpenBLAS / PLASMA / plasmatest 実走が OK なら計測可能です。"
fi
echo "======================================================"