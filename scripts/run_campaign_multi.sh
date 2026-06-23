#!/usr/bin/env bash
# =============================================================================
# run_campaign_multi.sh — 複数サイズを1つの tmux セッションで順番に計測する
#
# 指定した複数の SIZE を、1つずつ順番に（CPUを取り合わないよう逐次）計測する。
# 1サイズ終わると自動で次のサイズに進むので、見張り不要。
#
# 使い方:
#   SIZES="1024 2048" TRIALS=5 bash scripts/run_campaign_multi.sh
#   SIZES="512 1024 2048" TRIALS=5 bash scripts/run_campaign_multi.sh
#
# 進捗確認:
#   tmux attach -t bench        （Ctrl-b d で離脱）
#   tail -f logs/<最新>.log
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SIZES="${SIZES:-1024 2048}"
NB_MIN="${NB_MIN:-32}"
NB_MAX="${NB_MAX:-512}"
STEP="${STEP:-4}"
TRIALS="${TRIALS:-5}"
SESSION="${SESSION:-bench}"

HOSTNAME_SHORT="$(hostname -s)"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPO_ROOT}/logs/${HOSTNAME_SHORT}_multi_t${TRIALS}_${TS}.log"
mkdir -p "${REPO_ROOT}/logs"

if ! command -v tmux &>/dev/null; then
    echo "[ERROR] tmux が見つかりません。 sudo apt install -y tmux で導入してください。"
    exit 1
fi

if tmux has-session -t "${SESSION}" 2>/dev/null; then
    echo "[ERROR] tmux セッション '${SESSION}' は既に存在します。"
    echo "        確認: tmux attach -t ${SESSION}"
    echo "        別名で起動: SESSION=bench2 SIZES=\"${SIZES}\" bash scripts/run_campaign_multi.sh"
    exit 1
fi

# 各サイズを順番に流すコマンドを組み立てる
INNER="cd '${REPO_ROOT}'"
for SZ in ${SIZES}; do
    INNER="${INNER} && echo '======== SIZE=${SZ} 計測開始 \$(date) ========' \
&& bash run_benchmark.sh --size ${SZ} --nb-min ${NB_MIN} --nb-max ${NB_MAX} --step ${STEP} --trials ${TRIALS}"
done
INNER="${INNER} && echo '======== 全サイズ完了 \$(date) ========'"

# 全体を tee でログに落とす
CMD="{ ${INNER} ; } 2>&1 | tee '${LOG}'"

echo "======================================================"
echo " 複数サイズ計測を tmux セッション '${SESSION}' で開始"
echo "   host   : ${HOSTNAME_SHORT}"
echo "   sizes  : ${SIZES}（この順に逐次実行）"
echo "   nb     : ${NB_MIN}〜${NB_MAX} step=${STEP}"
echo "   trials : ${TRIALS}"
echo "   log    : ${LOG}"
echo "======================================================"

tmux new-session -d -s "${SESSION}" "${CMD}"

echo "[起動] tmux セッション '${SESSION}' で計測を開始しました。"
echo ""
echo "  進捗を見る:   tmux attach -t ${SESSION}    （Ctrl-b d で離脱）"
echo "  ログ追尾:     tail -f ${LOG}"
echo "  状態確認:     tmux ls"