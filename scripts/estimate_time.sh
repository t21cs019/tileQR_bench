#!/usr/bin/env bash
# =============================================================================
# estimate_time.sh — 粗いスイープを実測して本番フルスイープの所要時間を外挿
#
# step=64 程度の粗いスイープを1回まわし、(nb,ib) 1点あたりの平均時間を出して
# step=4 の全点数 × trials 回に換算する。
#
# 使い方:
#   bash scripts/estimate_time.sh                 # size=4096, trials=5 を想定
#   SIZE=4096 TRIALS=5 bash scripts/estimate_time.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/setup/config.sh"

SIZE="${SIZE:-4096}"
NB_MIN="${NB_MIN:-32}"
NB_MAX="${NB_MAX:-512}"
PROBE_STEP="${PROBE_STEP:-64}"   # 粗いスイープのステップ
FULL_STEP="${FULL_STEP:-4}"      # 本番のステップ
IB_MIN="${IB_MIN:-8}"
TRIALS="${TRIALS:-5}"

# (nb,ib) 全点数を数える関数: sum over nb of (len(range(ib_min, nb//2+1, step)))
count_points() {
    local step="$1"
    python3 - "$NB_MIN" "$NB_MAX" "$IB_MIN" "$step" <<'PY'
import sys
nb_min, nb_max, ib_min, step = map(int, sys.argv[1:5])
total = 0
for nb in range(nb_min, nb_max+1, step):
    total += len(range(ib_min, nb//2 + 1, step))
print(total)
PY
}

PROBE_POINTS="$(count_points "${PROBE_STEP}")"
FULL_POINTS="$(count_points "${FULL_STEP}")"

echo "======================================================"
echo " 所要時間の見積もり（$(hostname -s)）"
echo "   probe step=${PROBE_STEP} -> ${PROBE_POINTS} 点を実測"
echo "   full  step=${FULL_STEP}  -> ${FULL_POINTS} 点 × ${TRIALS} trials を換算"
echo "======================================================"

START="$(date +%s.%N)"
cd "${REPO_ROOT}"
bash run_benchmark.sh --size "${SIZE}" --nb-min "${NB_MIN}" --nb-max "${NB_MAX}" \
    --step "${PROBE_STEP}" --ib-min "${IB_MIN}" --trials 1 \
    --output "${REPO_ROOT}/results/benchmark/_probe_$(hostname -s).csv" >/dev/null
END="$(date +%s.%N)"

ELAPSED="$(python3 -c "print(${END}-${START})")"
PER_POINT="$(python3 -c "print(${ELAPSED}/${PROBE_POINTS})")"
FULL_SEC="$(python3 -c "print(${PER_POINT}*${FULL_POINTS}*${TRIALS})")"

python3 - "$ELAPSED" "$PER_POINT" "$FULL_SEC" "$FULL_POINTS" "$TRIALS" <<'PY'
import sys
elapsed, per_point, full_sec, full_points, trials = (float(sys.argv[1]), float(sys.argv[2]),
                                                     float(sys.argv[3]), int(float(sys.argv[4])), int(float(sys.argv[5])))
def hm(s):
    h=int(s//3600); m=int((s%3600)//60); return f"{h}時間{m}分"
print()
print(f"  probe 実測       : {elapsed:.1f} 秒")
print(f"  1点あたり        : {per_point:.3f} 秒")
print(f"  本番1 trial      : {hm(per_point*full_points)}  ({full_points} 点)")
print(f"  本番 {trials} trials : {hm(full_sec)}")
print()
print("  ※ nb が大きい領域ほど高速なので、実際はこれより短くなる傾向。")
PY

# probe の一時CSVは削除
rm -f "${REPO_ROOT}/results/benchmark/_probe_$(hostname -s).csv"
