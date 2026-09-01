"""
kernel_bench.py — dtsmqr カーネル単体計測ラッパー（NoFlush 経由）。

叩き方について（2026-09-01 ユーザ確認）:
    plasmatest には dtsmqr/ssrfb 相当のルーチンが存在しない
    （LAPACK レベルの dgeqrf 等のみ露出しており、PLASMA 内部の
    core_dtsmqr / core_dssrfb は叩けない）。

    卒論当時に kernel_dtsmqr.parquet を生成した実際のツールは
    このワークスペース内には見つからなかった（要検証・後日ユーザが
    卒論当時のコードを提供予定）。ひとまず optuna_tileQR/tools/Tune_SSRFB-master
    にある NoFlush（Tune_SSRFB, https://github.com/stomo0511/Tune_SSRFB ）を
    そのまま使う。

    重要: NoFlush は "SSRFB" と名付けられているが、ソース
    （NoFlush.cpp）の実体は core_dtsmqr を呼んでいる。
    そのため agullo（dtsmqr ベンチ）と model（SSRFB によるβ推定）は
    実際には同じカーネル呼び出しを利用することになる。

NoFlush の入出力契約:
    usage: NoFlush [NB size] [min IB size] [max IB size]
    標準出力: ib ごとに "nb, ib, time" の1行（time は N_IT 回実行の平均秒）。
    N_IT・MAT_SIZE はビルド時定数（このワークスペースにあるソースでは
    N_IT=50, MAT_SIZE=16384）で、実行時引数では変更できない。
    nb % ib != 0 の ib は出力されない（黙ってスキップされる）。

flops_dtsmqr は SSRFB（DSSRFB）の支配項 4*nb^3（Buttari et al.
arXiv:0709.1272 §3.2）を暫定的に流用している。dtsmqr 固有の flops 式は
未検証であり、卒論当時のコードと突き合わせて要検証。
"""
import os
import re
import subprocess

# NoFlush のパスは環境変数から取得（run_time_dgeqrf.py と同じ書き方）
_NOFLUSH_PATH = os.environ.get(
    "NOFLUSH_PATH",
    os.path.expanduser("~/Library/Tune_SSRFB/NoFlush"),
)

_LINE_RE = re.compile(r"^\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.eE+-]+)\s*$", re.MULTILINE)


def flops_dtsmqr(nb: int, ib: int) -> float:
    """暫定式。DSSRFB の支配項 4*nb^3 を流用（要検証）。"""
    return 4.0 * nb**3


def run_dtsmqr_sweep(
    nb: int,
    ib_min: int,
    ib_max: int,
    threads: int = 1,
    exe: str = None,
) -> dict:
    """nb を固定して ib_min〜ib_max を1回のプロセス起動でまとめて計測する。

    Returns
    -------
    dict: {ib: time_sec}（nb % ib != 0 の ib は含まれない。失敗時は空 dict）
    """
    exe = exe or _NOFLUSH_PATH
    command = [exe, str(nb), str(ib_min), str(ib_max)]

    env = os.environ.copy()
    env["OMP_NUM_THREADS"] = str(threads)

    result = subprocess.run(command, capture_output=True, text=True, env=env)

    out = {}
    for match in _LINE_RE.finditer(result.stdout):
        n, ib, t = int(match.group(1)), int(match.group(2)), float(match.group(3))
        if n == nb:
            out[ib] = t

    if not out:
        print(
            f"[WARN] dtsmqr 計測失敗またはゼロ点: nb={nb}, ib=[{ib_min},{ib_max}], "
            f"threads={threads}"
        )
        if result.stderr:
            print(f"       stderr: {result.stderr.strip()}")

    return out


def run_dtsmqr_point(nb: int, ib: int, threads: int = 1, exe: str = None) -> float:
    """(nb, ib) 単体の平均実行時間（秒）を返す。失敗時/nb%ib!=0 の場合は None。"""
    times = run_dtsmqr_sweep(nb, ib, ib, threads=threads, exe=exe)
    return times.get(ib)
