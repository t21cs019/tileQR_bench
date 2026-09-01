#!/usr/bin/env bash
# =============================================================================
# run_tuning_campaign.sh — tuning/run_tuning.py を tmux セッション内で実行する
#
# 3手法（agullo, optuna_full, model）を同一セッション内で逐次実行する
# （指示書 1.4: 手法間で CPU 状態を揃えるため並行実行禁止）。
# taskset で 0〜THREADS-1 の論理CPUにピニングする（子プロセスは affinity を
# 継承するため、plasmatest/NoFlush 呼び出し個別に taskset を挟む必要はない）。
#
# 使い方:
#   SIZE=4096 REPEAT=10 THREADS=4 bash scripts/run_tuning_campaign.sh
#   SIZES="1024 2048" REPEAT=10 THREADS=4 bash scripts/run_tuning_campaign.sh
#
# 進捗確認:
#   tmux attach -t tuning        # セッションに接続（Ctrl-b d でデタッチ）
#   tail -f logs/tuning_<host>_size<S>_<ts>.log
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SIZE="${SIZE:-4096}"
SIZES="${SIZES:-${SIZE}}"
REPEAT="${REPEAT:-10}"
THREADS="${THREADS:-4}"
METHODS="${METHODS:-agullo,optuna_full,model}"
SESSION="${SESSION:-tuning}"
COOLDOWN="${COOLDOWN:-30}"

HOSTNAME_SHORT="$(hostname -s)"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPO_ROOT}/logs/tuning_${HOSTNAME_SHORT}_size$(echo ${SIZES} | tr ' ' '-')_${TS}.log"
mkdir -p "${REPO_ROOT}/logs"

if ! command -v tmux &>/dev/null; then
    echo "[ERROR] tmux が見つかりません。 sudo apt install -y tmux で導入してください。"
    exit 1
fi

if ! command -v uv &>/dev/null; then
    echo "[ERROR] uv が見つかりません。先に bash scripts/setup_tuning_python.sh を実行してください。"
    exit 1
fi

if tmux has-session -t "${SESSION}" 2>/dev/null; then
    echo "[ERROR] tmux セッション '${SESSION}' は既に存在します。"
    echo "        確認: tmux attach -t ${SESSION}"
    echo "        別名で起動: SESSION=tuning2 bash scripts/run_tuning_campaign.sh"
    exit 1
fi

TASKSET_PREFIX=""
if command -v taskset &>/dev/null; then
    TASKSET_PREFIX="taskset -c 0-$((THREADS - 1))"
else
    echo "[WARN] taskset が見つかりません。CPUピニング無しで実行します。"
fi

CMD_LINES=""
for SZ in ${SIZES}; do
    CMD_LINES+="echo '=== size=${SZ} ==='; "
    CMD_LINES+="${TASKSET_PREFIX} uv run --project '${REPO_ROOT}' python '${REPO_ROOT}/tuning/run_tuning.py' \
--size ${SZ} --methods ${METHODS} --repeat ${REPEAT} --threads ${THREADS} \
--cooldown ${COOLDOWN} --output '${REPO_ROOT}/results/tuning/'; "
done

CMD="cd '${REPO_ROOT}' && (${CMD_LINES}) 2>&1 | tee '${LOG}'"

echo "======================================================"
echo " チューニング比較を tmux セッション '${SESSION}' で開始します"
echo "   host    : ${HOSTNAME_SHORT}"
echo "   sizes   : ${SIZES}"
echo "   methods : ${METHODS}"
echo "   repeat  : ${REPEAT}"
echo "   threads : ${THREADS} (${TASKSET_PREFIX:-pinning無し})"
echo "   log     : ${LOG}"
echo "======================================================"

tmux new-session -d -s "${SESSION}" "${CMD}"

echo "[起動] tmux セッション '${SESSION}' で計測を開始しました。"
echo ""
echo "  進捗を見る:   tmux attach -t ${SESSION}    （Ctrl-b d で離脱）"
echo "  ログ追尾:     tail -f ${LOG}"
echo "  状態確認:     tmux ls"
