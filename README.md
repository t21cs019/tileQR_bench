# tileQR_bench

家庭内Intelマシン群でのタイルQR分解（PLASMA dgeqrf）計測専用リポジトリ。
`optuna_tileQR` から **純スイープ計測に特化**して切り出した軽量版。

- Optuna / 可視化（plotly・matplotlib）は含まない
- 計測コアは Python 標準ライブラリのみで動作（uv 不要、システム python3 で動く）
- lib / lib64 を自動判定
- セットアップに apt依存導入・CPUガバナー設定・lscpu保存・環境固定・Tailscale を内包

## セットアップ手順（新規マシン）

```bash
# 1. クローン
git clone https://github.com/t21cs019/tileQR_bench.git
cd tileQR_bench

# 2. 初期セットアップ（apt依存・ガバナー・lscpu保存・MAC表示・Tailscale）
bash setup/00_bootstrap.sh
#   → 表示された MAC をルーターのDHCP予約に登録
#   → sudo tailscale up --hostname=<ホスト名>  で認証

# 3. 計測環境のビルド（OpenBLAS + PLASMA）
bash setup/install.sh

# 4. 確認
bash setup/check.sh
```

## 計測

```bash
# 所要時間の見積もり（粗いスイープから外挿）
bash scripts/estimate_time.sh

# 本番計測（tmux 内で5回スイープ。SSH が切れても継続）
TRIALS=5 bash scripts/run_campaign.sh
tmux attach -t bench        # 進捗確認（Ctrl-b d で離脱）
```

## 結果の転送

```bash
# OneDrive へ（rclone）
bash scripts/sync_results.sh rclone

# 集約機へ直接（scp）
SCP_DEST='ryo@desktop:~/tileQR_dashboard/inbox/manual' \
  bash scripts/sync_results.sh scp
```

## CSV 形式

`results/benchmark/<host>_size<S>_nb<min>-<max>_t<trials>_<timestamp>.csv`

列: `threads, size, nb, ib, GFlops`（既存ダッシュボードと互換）

## ディレクトリ

```
setup/
  00_bootstrap.sh      初期セットアップ（apt/governor/lscpu/MAC/tailscale）
  config.sh            共通設定（lib/lib64 自動判定・環境固定）
  install.sh           OpenBLAS + PLASMA ビルド統括
  install_openblas.sh
  install_plasma.sh    （LAPACKE_LIBRARIES 指定・libdir 自動判定済み）
  install_noflush.sh
  check.sh             環境確認
scripts/
  estimate_time.sh     所要時間の外挿見積もり
  run_campaign.sh      tmux 内で本番スイープ
  sync_results.sh      rclone / scp 転送
src/
  benchmark.py         スイープ計測本体（標準ライブラリのみ）
  run_time_dgeqrf.py   plasmatest 呼び出し
specs/                 lscpu / cache / meminfo を機種ごとに保存
results/benchmark/     計測CSV
logs/                  計測ログ
```
