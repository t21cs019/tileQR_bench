# tileQR_bench

> ⚠️ **このリポジトリは凍結（アーカイブ）されました。**
> 計測機能は [`plasma-perf`](https://github.com/t21cs019/plasma-perf) に統合済みです。
> 今後の計測・修正・機能追加はすべて **plasma-perf 側**で行ってください。
> 本リポジトリは計測履歴の参照用に残しています（読み取り専用）。
>
> - フルQR計測（旧 `src/benchmark.py`）→ `plasma-perf` の `python -m plasma_perf bench tileqr`
> - 環境ビルド（旧 `setup/`）→ [`plasma-workspace`](https://github.com/t21cs019/plasma-workspace)
>
> ---

家庭内Intelマシン群・研究室サーバでのタイルQR分解（PLASMA dgeqrf）計測専用リポジトリ。
`optuna_tileQR` から **純スイープ計測に特化**して切り出した軽量版。

- Optuna / 可視化（plotly・matplotlib）は含まない
- 計測コアは Python 標準ライブラリのみで動作（uv 不要、システム python3 で動く）
- lib / lib64 を自動判定
- OpenBLAS / PLASMA はすべて `~/Library` 配下にビルド（**sudo 不要**）

## セットアップ

セットアップ方法は環境によって2通りある。

### A. 研究室・大学サーバ（推奨ルート）

共有サーバでは sudo が使えず、Tailscale や CPU ガバナー設定も不要・不可能。
`quickstart.sh` がツール確認 → ビルド → 確認までを1コマンドで行う。

```bash
# 1. クローン
git clone https://github.com/t21cs019/tileQR_bench.git
cd tileQR_bench

# 2. 最短セットアップ（ツール確認 → install.sh → check.sh）
bash setup/quickstart.sh
```

`quickstart.sh` の挙動:

- ビルドツール（gcc/gfortran/make/cmake/git/wget/python3）が揃っているか確認する。
  足りなければ `module avail` / `module load` で供給するよう案内して停止する
  （module 名はサーバごとに異なるため自動 load はしない）。
- `~/Library` に既にビルド済みなら `install.sh` を自動スキップする
  （別リポジトリ（optuna_tileQR 等）で既に PLASMA をビルド済みのサーバはこれに該当）。
- 最後に `check.sh` で確認する。
  CPU governor の FAIL は共有サーバでは無視してよい（計測の実行には影響しない）。

### B. 家庭内マシン（初期設定込み）

apt依存導入・CPUガバナー固定・lscpu保存・MAC表示・Tailscale 導入まで行う。
sudo が必要。

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

> **CPU governor について**
> `check.sh` は governor=performance を推奨する。共有サーバ等で `powersave` の場合は
> FAIL になるが計測自体は可能。ただし周波数が変動して GFlops にブレが出やすいので、
> TRIALS を多めにして最大値・上位値で評価するとよい。

## 計測

```bash
# 所要時間の見積もり（粗いスイープから外挿）
bash scripts/estimate_time.sh

# 本番計測：単一サイズ（tmux 内で5回スイープ。SSH が切れても継続）
TRIALS=5 bash scripts/run_campaign.sh
tmux attach -t bench        # 進捗確認（Ctrl-b d で離脱）

# 本番計測：複数サイズを1セッションで逐次実行（CPUを取り合わない）
SIZES="1024 2048" TRIALS=5 bash scripts/run_campaign_multi.sh
tmux attach -t bench        # 進捗確認（Ctrl-b d で離脱）
```

### run_campaign_multi.sh の環境変数

複数の SIZE を1つの tmux セッションで順番に計測する。1サイズ終わると自動で次に進むので
見張り不要。CPU を取り合わせないため逐次実行する。

| 変数 | 説明 | デフォルト |
|--------|------|---------|
| `SIZES` | 計測する行列サイズ（空白区切りで複数）。この順に逐次実行 | `1024 2048` |
| `TRIALS` | スイープ繰り返し回数 | `5` |
| `NB_MIN` | nb 最小値 | `32` |
| `NB_MAX` | nb 最大値 | `512` |
| `STEP` | ステップ幅 | `4` |
| `THREADS` | OMP_NUM_THREADS。未指定なら os.cpu_count に任せる。指定時はファイル名に `th<N>` を付与 | 未指定（auto） |
| `SESSION` | tmux セッション名 | `bench` |

```bash
# 例：3サイズ、4スレッド固定（出力ファイル名に th4 が入る）
SIZES="512 1024 2048" THREADS=4 SESSION=bench4t TRIALS=5 \
  bash scripts/run_campaign_multi.sh
```

進捗確認:

```bash
tmux attach -t bench        # Ctrl-b d で離脱
tail -f logs/<最新>.log
tmux ls                     # セッション一覧
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
（THREADS 指定時は `..._th<N>_t<trials>_...`）

列: `threads, size, nb, ib, GFlops`（既存ダッシュボードと互換）

## ディレクトリ

```
setup/
  00_bootstrap.sh        初期セットアップ（apt/governor/lscpu/MAC/tailscale）※家庭マシン用
  quickstart.sh          新サーバ用の最短セットアップ（ツール確認→install→check）
  config.sh              共通設定（lib/lib64 自動判定・環境固定）
  install.sh             OpenBLAS + PLASMA ビルド統括
  install_openblas.sh
  install_plasma.sh      （LAPACKE_LIBRARIES 指定・libdir 自動判定済み）
  install_noflush.sh
  check.sh               環境確認
scripts/
  estimate_time.sh       所要時間の外挿見積もり
  run_campaign.sh        tmux 内で本番スイープ（単一サイズ）
  run_campaign_multi.sh  複数サイズを1セッションで逐次計測
  sync_results.sh        rclone / scp 転送
src/
  benchmark.py           スイープ計測本体（標準ライブラリのみ）
  run_time_dgeqrf.py     plasmatest 呼び出し
specs/                   lscpu / cache / meminfo を機種ごとに保存
results/benchmark/       計測CSV
logs/                    計測ログ
```