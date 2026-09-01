#!/usr/bin/env bash
# =============================================================================
# setup_tuning_python.sh — uv で tuning/ 用の Python 環境を構築する
#
# 計測コア（src/benchmark.py 等）は標準ライブラリのみで動くので不要。
# tuning/run_tuning.py（optuna・numpy を使う）や tuning/evaluate.py
# （pandas・pyarrow を使う、データ側の環境で実行）を使うときにこれを実行する。
# uv.lock でバージョンを固定・再現する（plasma-bench/scripts/setup_python.sh
# と同じ作法）。管理者権限不要。
#
# 使い方:
#   bash scripts/setup_tuning_python.sh                  # tuning extra を導入（既定）
#   bash scripts/setup_tuning_python.sh --extra evaluate  # evaluate.py 用（pandas/pyarrow）のみ
#   bash scripts/setup_tuning_python.sh --all-extras      # 両方
#
# 実行後の使い方:
#   uv run python tuning/run_tuning.py --dry-run --size 4096 --methods agullo,optuna_full,model
#   uv run python tuning/evaluate.py --results ... --qr-sweep ... --config ...
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/../setup/config.sh"

cd "${REPO_ROOT}"

# --- 1. uv のインストール（管理者権限不要） -----------------------------------
if command -v uv &>/dev/null; then
    echo "[1/2] uv はインストール済みです: $(uv --version)"
else
    echo "[1/2] uv をインストールしています..."
    if command -v curl &>/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget &>/dev/null; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "[ERROR] curl も wget も見つかりません。どちらかを用意してください。"
        exit 1
    fi
    export PATH="${UV_INSTALL_DIR}:${PATH}"
    if ! command -v uv &>/dev/null; then
        echo "[ERROR] uv のインストールに失敗しました。"
        exit 1
    fi
fi

# --- 2. uv sync で依存を導入（uv.lock に固定、.venv/ に構築） ------------------
echo "[2/2] uv sync で依存パッケージを導入しています..."
if [ "$#" -gt 0 ]; then
    uv sync "$@"
else
    uv sync --extra tuning
fi

echo ""
echo "[完了] Python 環境の構築が完了しました（${PLASMA_BENCH_VENV}）。"
echo "       実行例: uv run python tuning/run_tuning.py --dry-run --size 4096 --methods agullo,optuna_full,model"
