# チューニング手法の実測比較

`INSTRUCTIONS_tuning_comparison.md`（リポジトリ直下）に基づく実装。
「正解を知らない状態から、各手法が何秒で何 GFlops に到達するか」を測る
（既存の `benchmark.py` の nb×ib 全スイープとは目的が別）。

比較する3手法: `agullo`（卒論の既存手法）, `optuna_full`（卒論の Optuna）,
`model`（本研究の提案手法）。詳細は指示書参照。

## 実行手順（i3-10100）

```bash
# 0. SMT 状態を確認（正解表が SMT-off なので off に揃える）
lscpu | grep -i "Thread(s) per core"

# 1. tuning/ 用の Python 環境を uv で構築する（計測コア src/ は標準ライブラリの
#    みで動くので benchmark.py だけを使うなら不要。plasma-bench/scripts/
#    setup_python.sh と同じ作法。uv.lock で固定・.venv/ に構築される）
bash scripts/setup_tuning_python.sh

# 2. NoFlush（dtsmqrカーネル計測ツール）を用意する
#    optuna_tileQR/tools/Tune_SSRFB-master/NoFlush.cpp を
#    ~/Library/Tune_SSRFB/NoFlush としてビルドしておく
#    （PLASMA/OpenBLAS の include/lib が必要。既存の
#      plasma-workspace/setup/install_noflush.sh と同じビルド手順）
#    NOFLUSH_PATH 環境変数でパスを上書きできる

# 3. dry-run で実行回数・推定時間を確認
uv run python tuning/run_tuning.py --dry-run --size 4096 --methods agullo,optuna_full,model

# 4. 短縮版で動作確認（repeat=1, agulloのkernel-repsを5に落とす）
uv run python tuning/run_tuning.py --size 4096 --methods model --repeat 1 --threads 4
uv run python tuning/run_tuning.py --size 4096 --methods agullo --repeat 1 --threads 4 --kernel-reps 5

# 5. 本番（agullo は所要時間が長いため repeat=3 に落としてよい。指示書 5節）
SIZE=4096 REPEAT=10 THREADS=4 METHODS=optuna_full,model \
  bash scripts/run_tuning_campaign.sh
SIZE=4096 REPEAT=3  THREADS=4 METHODS=agullo \
  bash scripts/run_tuning_campaign.sh SESSION=tuning_agullo

# 6. size=4096 が終わったら追加サイズで卒論のキャッシュ式の限界を示す
SIZES="1024 2048" REPEAT=10 THREADS=4 bash scripts/run_tuning_campaign.sh
```

## 評価（オフライン、データ側で実行）

```bash
# tileQR_data 側（pandas/pyarrow が要る。evaluate extra を導入）
bash scripts/setup_tuning_python.sh --extra evaluate
uv run python tuning/evaluate.py \
    --results results/tuning/tuning_i3-10100_size4096_th4_*.csv \
    --qr-sweep ../tileQR_data/derived/qr_sweep.parquet \
    --config i3-10100_s1_smt-off
```

**注意（2026-09-01 時点）**: `tileQR_data/derived/qr_sweep.parquet` にはまだ
`i3-10100_*` の config が存在しない（既存の正解表は i3-7100/i3-8100 等のみ）。
i3-10100 の正解表（`benchmark.py` の全スイープ）を別途収集してから
`evaluate.py` を実行すること。

## 実装上の未検証事項・要フォローアップ

指示書 8節に基づき実装前に確認したが、下記は**暫定実装**であり、
ユーザから提供される卒論当時のコードと突き合わせて検証する必要がある
（2026-09-01 に確認済み・要フォローアップとして合意）。

1. **dtsmqr カーネルの叩き方**（`tuning/kernel_bench.py`）:
   `plasmatest` には dtsmqr/ssrfb 相当のルーチンが無い。卒論当時に
   `tileQR_data/raw/kernel_dtsmqr/*.csv` を生成した実際のツールはこの
   ワークスペース内に見つからなかった。ひとまず
   `optuna_tileQR/tools/Tune_SSRFB-master/NoFlush.cpp`（実体は
   `core_dtsmqr` を呼ぶ）を流用している。この NoFlush は `nb % ib == 0`
   の ib しか結果を返さないため、指示書の「ib step=2」を厳密には
   再現できていない（`agullo` の notes 列に明記）。
   → ユーザが卒論当時のコードを提供予定。届いたら差し替えて再検証する。

2. **model.py の「SSRFB による β 推定」**: 同じ NoFlush ツールを使う
   （2026-09-01 ユーザ確認済み）。"SSRFB" という名称だが実体は dtsmqr。

3. **ヒューリスティック2の条件2・3の解釈**（`tuning/methods/agullo.py`
   の `select_heuristic2`）: Agullo LAWN 242 原論文・卒論本文がこの
   ワークスペースから参照できず一意に特定できなかったため、以下で実装した
   （2026-09-01 ユーザ承認: 妥当な解釈で実装し notes に明記）。
   - 条件1: MaxIB ペアの上側凸包上にある点（単調鎖法で自前実装）
   - 条件2: 凸包の隣接頂点間の傾き `Δgflops/Δnb` が最大になる頂点
   - 条件3: nb の最小〜最大を等幅8区間に分割し、区間ごとに条件1・2を
     満たす点を1つ選ぶ（該当点が無い区間はスキップ、選択数が8未満に
     なりうる。実行結果の notes 列に選択数を記録）
   → 卒論本文や Agullo 原論文が入手でき次第、この解釈を照合すること。

4. **flops_dtsmqr の式**: DSSRFB の支配項 `4*nb^3`
   （Buttari et al. arXiv:0709.1272 §3.2）を暫定的に流用している。
   dtsmqr 固有の flops 式は未検証。

## ディレクトリ

```
pyproject.toml          uv 用の依存定義（extras: tuning, evaluate）
uv.lock                  uv sync が固定するロックファイル
tuning/
  run_tuning.py         CLIエントリポイント
  model_predict.py      モデル式（帯・点を返す。依存なしの純関数）
  beta_fit.py            SSRFB(dtsmqr代理)計測 → β 推定
  kernel_bench.py        dtsmqr カーネル計測ラッパー（NoFlush 経由）
  evaluate.py            オフライン評価（データ側で実行）
  methods/
    agullo.py            卒論の既存手法
    optuna_full.py       卒論の Optuna
    model.py             提案手法
scripts/
  setup_tuning_python.sh   uv で tuning/ 用の Python 環境を構築（extra: tuning/evaluate）
  run_tuning_campaign.sh   tmux で3手法×N回を逐次実行（uv run 経由）
results/tuning/              出力CSV・プロベナンス
```

## 依存管理（uv）

`tuning/` の Python 依存は `pyproject.toml` の optional-dependencies で管理する
（`plasma-bench`/`plasma-workspace` と同じ作法）。計測コア（`src/`）は
標準ライブラリのみで動くため、`benchmark.py` だけを使うなら uv 環境は不要。

```bash
bash scripts/setup_tuning_python.sh                  # tuning extra（optuna, numpy）
bash scripts/setup_tuning_python.sh --extra evaluate # evaluate extra（pandas, pyarrow）
bash scripts/setup_tuning_python.sh --all-extras     # 両方
```

このリポジトリ自体は pip パッケージとしてビルド・インストールしない
（`pyproject.toml` の `[tool.uv] package = false`）。`src/`・`tuning/` は
`sys.path` 経由で直接実行する既存方針（`run_time_dgeqrf.py` の import 等）を
崩さないため。
