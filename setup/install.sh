#!/usr/bin/env bash
# =============================================================================
# install.sh — tileQR_bench 計測環境を一括ビルド
#
# 前提:
#   先に bash setup/00_bootstrap.sh を実行して
#   apt 依存（build-essential 等）を導入済みであること。
#
# 実行順序:
#   1. OpenBLAS
#   2. PLASMA
#   3. NoFlush（Tune_SSRFB）
#
# 注意:
#   計測コア（benchmark.py / run_time_dgeqrf.py）は標準ライブラリのみで動くため
#   uv / optuna / pandas 等の Python 依存は不要。システムの python3 を使う。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "======================================================"
echo " tileQR_bench 計測環境セットアップ開始"
echo "======================================================"

# python3 の存在確認（計測コアが使用）
if ! command -v python3 &>/dev/null; then
    echo "[ERROR] python3 が見つかりません。"
    echo "        sudo apt install -y python3  で導入してください。"
    exit 1
fi

echo ""
echo ">>> [1/3] OpenBLAS のインストール"
bash "${SCRIPT_DIR}/install_openblas.sh"

echo ""
echo ">>> [2/3] PLASMA のインストール"
bash "${SCRIPT_DIR}/install_plasma.sh"

echo ""
echo ">>> [3/3] NoFlush（Tune_SSRFB）のインストール"
if [ -f "${SCRIPT_DIR}/install_noflush.sh" ]; then
    bash "${SCRIPT_DIR}/install_noflush.sh"
else
    echo "[SKIP] install_noflush.sh が無いためスキップ（純スイープ計測では不要）"
fi

echo ""
echo "======================================================"
echo " セットアップ完了！"
echo ""
echo " 確認:"
echo "   bash setup/check.sh"
echo ""
echo " 計測:"
echo "   bash run_benchmark.sh --help"
echo "======================================================"
