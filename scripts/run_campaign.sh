#!/usr/bin/env bash
# =============================================================================
# run_campaign.sh — 本番計測を tmux セッション内で実行する
#
# nb 32〜512 step=4 の全スイープを TRIALS 回まわす。
# tmux セッション内で実行するため、SSH が切れても計測は継続する。
#
# 使い方:
#   bash scripts/run_campaign.sh                # 既定（size=4096, trials=5）
#   TRIALS=5 SIZE=4096 bash scripts/run_campaign.sh
#
# 進捗確認:
#   tmux attach -t bench        # セッションに接続
#   （Ctrl-b d でデタッチ）
#   tail -f logs/<最新>.log     # ログ追尾
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SIZE="${SIZE:-4096}"
NB_MIN="${NB_MIN:-32}"
NB_MAX="${NB_MAX:-512}"
STEP="${STEP:-4}"
TRIALS="${TRIALS:-5}"
SESSION="${SESSION:-bench}"

HOSTNAME_SHORT="$(hostname -s)"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPO_ROOT}/logs/${HOSTNAME_SHORT}_size${SIZE}_t${TRIALS}_${TS}.log"
mkdir -p "${REPO_ROOT}/logs"

if ! command -v tmux &>/dev/null; then
    echo "[ERROR] tmux が見つかりません。 sudo apt install -y tmux で導入してください。"
    exit 1
fi

if tmux has-session -t "${SESSION}" 2>/dev/null; then
    echo "[ERROR] tmux セッション '${SESSION}' は既に存在します。"
    echo "        確認: tmux attach -t ${SESSION}"
    echo "        別名で起動: SESSION=bench2 bash scripts/run_campaign.sh"
    exit 1
fi

CMD="cd '${REPO_ROOT}' && bash run_benchmark.sh \
--size ${SIZE} --nb-min ${NB_MIN} --nb-max ${NB_MAX} --step ${STEP} --trials ${TRIALS} \
2>&1 | tee '${LOG}'"

echo "======================================================"
echo " 本番計測を tmux セッション '${SESSION}' で開始します"
echo "   host   : ${HOSTNAME_SHORT}"
echo "   size   : ${SIZE}"
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
