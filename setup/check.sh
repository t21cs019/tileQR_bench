#!/usr/bin/env bash
# =============================================================================
# check.sh — 計測環境のセットアップ確認
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

PASS=0
FAIL=0
ok()   { echo "[OK]   $1"; PASS=$((PASS+1)); }
ng()   { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "======================================================"
echo " tileQR_bench セットアップ確認: $(hostname -s)"
echo "======================================================"

echo "--- 基本ツール ---"
for cmd in gcc gfortran make cmake git wget python3; do
    if command -v "${cmd}" &>/dev/null; then ok "${cmd}"; else ng "${cmd}"; fi
done

echo "--- CPU 設定 ---"
if command -v cpupower &>/dev/null; then
    gov="$(cpupower frequency-info 2>/dev/null | grep -oP 'The governor "\K[^"]+' | head -1)"
    if [ "${gov}" = "performance" ]; then ok "governor=performance"; else ng "governor=${gov:-unknown}（performance 推奨）"; fi
else
    ng "cpupower 未導入"
fi

echo "--- OpenBLAS ---"
if ls "${OPENBLAS_LIBDIR}"/libopenblas.so &>/dev/null; then ok "libopenblas.so (${OPENBLAS_LIBDIR})"; else ng "libopenblas.so"; fi

echo "--- PLASMA ---"
if [ -f "${PLASMA_TEST}" ]; then ok "plasmatest"; else ng "plasmatest"; fi
if ls "${PLASMA_LIBDIR}"/libplasma.so &>/dev/null; then ok "libplasma.so (${PLASMA_LIBDIR})"; else ng "libplasma.so"; fi

echo "--- 動作確認（plasmatest 実走） ---"
if [ -f "${PLASMA_TEST}" ]; then
    if "${PLASMA_TEST}" dgeqrf --dim=512x512 --nb=64 --ib=16 &>/dev/null; then
        ok "plasmatest dgeqrf 実行"
    else
        ng "plasmatest 実行（LD_LIBRARY_PATH を確認）"
    fi
fi

echo "======================================================"
echo " 結果: PASS=${PASS}  FAIL=${FAIL}"
echo "======================================================"
[ "${FAIL}" -eq 0 ]
