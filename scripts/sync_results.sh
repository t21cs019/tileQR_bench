#!/usr/bin/env bash
# =============================================================================
# sync_results.sh — 計測結果CSVを集約先へ転送する
#
# 2つの転送方式に対応:
#   - rclone : OneDrive 等のリモートへアップロード
#   - scp    : 集約機（WSL2/Windowsデスクトップ等）へ直接コピー
#
# 使い方:
#   bash scripts/sync_results.sh rclone
#   bash scripts/sync_results.sh scp
#
# 設定は config.sh の下部、または環境変数で上書き:
#   RCLONE_REMOTE   例: "onedrive:research/tileQR/inbox/manual"
#   SCP_DEST        例: "ryo@desktop:/home/ryo/tileQR_dashboard/inbox/manual"
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/setup/config.sh"

RESULTS_DIR="${REPO_ROOT}/results/benchmark"
HOSTNAME_SHORT="$(hostname -s)"

# 転送先（環境変数で上書き可能）
RCLONE_REMOTE="${RCLONE_REMOTE:-onedrive:research/tileQR/inbox/manual}"
SCP_DEST="${SCP_DEST:-}"

MODE="${1:-}"

if [ -z "${MODE}" ]; then
    echo "使い方: bash scripts/sync_results.sh [rclone|scp]"
    exit 1
fi

# 転送対象（このホストのCSV + specs）
mapfile -t CSV_FILES < <(find "${RESULTS_DIR}" -name "${HOSTNAME_SHORT}_*.csv" 2>/dev/null)
if [ "${#CSV_FILES[@]}" -eq 0 ]; then
    echo "[WARN] 転送対象CSVが見つかりません: ${RESULTS_DIR}/${HOSTNAME_SHORT}_*.csv"
    exit 0
fi
echo "転送対象: ${#CSV_FILES[@]} 件のCSV (${HOSTNAME_SHORT})"

case "${MODE}" in
    rclone)
        if ! command -v rclone &>/dev/null; then
            echo "[ERROR] rclone が見つかりません。"
            echo "        ~/.local/bin/ に直接バイナリを置く方法で導入できます。"
            exit 1
        fi
        echo "rclone でアップロード -> ${RCLONE_REMOTE}"
        for f in "${CSV_FILES[@]}"; do
            rclone copy "${f}" "${RCLONE_REMOTE}/" --progress
        done
        # specs も一緒に送る（任意）
        if [ -d "${REPO_ROOT}/specs" ]; then
            rclone copy "${REPO_ROOT}/specs" "${RCLONE_REMOTE%/inbox/manual}/specs/" 2>/dev/null || true
        fi
        ;;
    scp)
        if [ -z "${SCP_DEST}" ]; then
            echo "[ERROR] SCP_DEST が未設定です。"
            echo "        例: SCP_DEST='ryo@desktop:~/tileQR_dashboard/inbox/manual' bash scripts/sync_results.sh scp"
            exit 1
        fi
        echo "scp で転送 -> ${SCP_DEST}"
        scp "${CSV_FILES[@]}" "${SCP_DEST}/"
        ;;
    *)
        echo "[ERROR] 未知のモード: ${MODE}（rclone か scp を指定）"
        exit 1
        ;;
esac

echo "[完了] 転送が完了しました。"
