#!/usr/bin/env bash
# =============================================================================
# run_benchmark.sh — ベンチマーク実行ラッパー
# 環境変数を整えてから benchmark.py を実行する。
#
# 使い方:
#   bash run_benchmark.sh [benchmark.py に渡すオプション]
#
# 例:
#   bash run_benchmark.sh --size 4096 --nb-min 32 --nb-max 512 --step 4 --trials 5
#   bash run_benchmark.sh --help
#
# 計測コアは標準ライブラリのみで動くため、システム python3 を使用する。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/setup/config.sh"

# plasmatest の存在確認
if [ ! -f "${PLASMA_TEST}" ]; then
    echo "[ERROR] plasmatest が見つかりません: ${PLASMA_TEST}"
    echo "        先に bash setup/install.sh を実行してください。"
    exit 1
fi

# ライブラリパスは config.sh で自動判定済み（LD_LIBRARY_PATH）
echo "[info] LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
echo "[info] OPENBLAS_NUM_THREADS=${OPENBLAS_NUM_THREADS}"

cd "${SCRIPT_DIR}/src"
exec python3 benchmark.py "$@"
