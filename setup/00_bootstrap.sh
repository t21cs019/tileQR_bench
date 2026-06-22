#!/usr/bin/env bash
# =============================================================================
# 00_bootstrap.sh — 計測機の初期セットアップ（全台共通の前段）
#
# 実行内容:
#   1. apt 依存パッケージの導入（build-essential 等）
#   2. CPU ガバナーを performance に固定
#   3. lscpu / メモリ情報の保存（機種ごとの記録）
#   4. MAC アドレスの表示（ルーターDHCP予約 登録用）
#   5. Tailscale の導入（任意）
#
# 使い方:
#   bash setup/00_bootstrap.sh
#
# 注意:
#   - sudo を使用します（apt / cpupower / tailscale 導入のため）。
#   - ベンチ環境のビルド（OpenBLAS/PLASMA）はこの後 install.sh で行います。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

HOSTNAME_SHORT="$(hostname -s)"
SPEC_DIR="${REPO_ROOT}/specs"
mkdir -p "${SPEC_DIR}"

echo "======================================================"
echo " 計測機 初期セットアップ: ${HOSTNAME_SHORT}"
echo "======================================================"

# --- 1. apt 依存パッケージ ----------------------------------------------------
echo ""
echo ">>> [1/5] apt 依存パッケージの導入"
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    gfortran \
    cmake \
    git \
    wget \
    curl \
    linux-tools-common \
    "linux-tools-$(uname -r)" \
    cpufrequtils \
    numactl

# --- 2. CPU ガバナーを performance に -----------------------------------------
echo ""
echo ">>> [2/5] CPU ガバナーを performance に設定"
if sudo cpupower frequency-set -g performance 2>/dev/null; then
    echo "[OK] performance ガバナーを設定しました。"
else
    echo "[WARN] cpupower でのガバナー設定に失敗しました。"
    echo "       一部の環境（仮想化等）では governor を変更できません。"
fi
# 確認
echo "現在のガバナー:"
if command -v cpupower &>/dev/null; then
    cpupower frequency-info 2>/dev/null | grep -i "current policy\|governor" || true
fi

# --- 3. lscpu / メモリ情報の保存 ---------------------------------------------
echo ""
echo ">>> [3/5] CPU/メモリ情報の保存 -> ${SPEC_DIR}/"
lscpu > "${SPEC_DIR}/lscpu_${HOSTNAME_SHORT}.txt"
free -h > "${SPEC_DIR}/meminfo_${HOSTNAME_SHORT}.txt"
# キャッシュ階層も明示的に保存（cache/thread 計算の根拠用）
if command -v lscpu &>/dev/null; then
    lscpu -C > "${SPEC_DIR}/cache_${HOSTNAME_SHORT}.txt" 2>/dev/null || true
fi
echo "[OK] 保存しました:"
echo "     ${SPEC_DIR}/lscpu_${HOSTNAME_SHORT}.txt"
echo "     ${SPEC_DIR}/meminfo_${HOSTNAME_SHORT}.txt"
echo "     ${SPEC_DIR}/cache_${HOSTNAME_SHORT}.txt"

# --- 4. MAC アドレス表示（ルーターDHCP予約 登録用） ---------------------------
echo ""
echo ">>> [4/5] MAC アドレス（ルーターのDHCP予約に登録してください）"
echo "------------------------------------------------------"
ip -br link | awk '$1 != "lo" {printf "  %-12s %s\n", $1, $3}'
echo "------------------------------------------------------"
echo "  ↑ このMACをルーター管理画面でIP予約に登録すると、"
echo "    ${HOSTNAME_SHORT} が常に同じLAN内IPになります。"

# --- 5. Tailscale 導入（任意） -----------------------------------------------
echo ""
echo ">>> [5/5] Tailscale の導入"
if [ "${INSTALL_TAILSCALE}" = "1" ]; then
    if command -v tailscale &>/dev/null; then
        echo "[SKIP] tailscale はすでに導入済みです。"
    else
        echo "tailscale を導入しています..."
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    echo ""
    echo "  認証するには次を実行してください（ブラウザ認証）:"
    echo "    sudo tailscale up --hostname=${HOSTNAME_SHORT}"
    echo "  認証後、MagicDNS 有効なら 'ssh ${USER}@${HOSTNAME_SHORT}' で接続できます。"
else
    echo "[SKIP] INSTALL_TAILSCALE=0 のためスキップしました。"
    echo "       導入する場合は config.sh で INSTALL_TAILSCALE=1 にしてください。"
fi

echo ""
echo "======================================================"
echo " 初期セットアップ完了: ${HOSTNAME_SHORT}"
echo " 次のステップ:"
echo "   bash setup/install.sh    # OpenBLAS + PLASMA のビルド"
echo "======================================================"
