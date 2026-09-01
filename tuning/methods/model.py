"""
model.py — 提案手法。

    1. β を取得（beta_fit.py。--beta で外部から与えられた場合は計測をスキップし、
       時間0とする）
    2. predict_band(beta, p, size) で帯 (lo, hi) を得る
    3. Optuna で探索。16試行、1試行につき QR は1回計測。
       nb ∈ [lo, hi]、ib ∈ [max(8, nb/8), nb/2]。
       warm start: 最初の3試行を predict_nb の値と、その 0.75倍・1.3倍で埋める
       （ib は nb/4 に最も近い候補）。
    4. 観測上位3ペアを各3回再計測し、平均が最良のものを最終回答とする。

p は物理コア数を使う（lscpu -p=CORE のユニーク数。nproc ではない）。
"""
import os
import subprocess
import sys
import time

try:
    import optuna
except ImportError as e:  # pragma: no cover
    raise ImportError(
        "model には optuna が必要です。"
        "`bash scripts/setup_tuning_python.sh` を実行し、"
        "`uv run python tuning/run_tuning.py ...` で起動してください。"
    ) from e

optuna.logging.set_verbosity(optuna.logging.WARNING)

from .. import beta_fit  # noqa: E402
from .. import model_predict  # noqa: E402

_SRC_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "src")
if _SRC_DIR not in sys.path:
    sys.path.insert(0, _SRC_DIR)
from run_time_dgeqrf import run_time_dgeqrf  # noqa: E402

N_TRIALS = 16
TOP_K = 3
VERIFY_REPS = 3
WARM_START_FACTORS = (1.0, 0.75, 1.3)


def get_physical_cores() -> int:
    """lscpu -p=CORE のユニーク数（nproc ではない）。取得できない場合は os.cpu_count()。"""
    try:
        out = subprocess.run(
            ["lscpu", "-p=CORE"], capture_output=True, text=True, check=True
        ).stdout
        cores = {line.strip() for line in out.splitlines() if line and not line.startswith("#")}
        if cores:
            return len(cores)
    except Exception:
        pass
    return os.cpu_count() or 1


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def run(size, threads, seed, ctx=None, **kwargs):
    """
    kwargs:
        beta        : 外部から与える β（指定時は計測をスキップし time_prep_sec=0）
        beta_reps   : β 推定の計測反復回数（既定1、サーバは3推奨）
        band_thr    : predict_band の閾値（既定 model_predict.THR）
        n_trials    : Optuna 探索試行数（既定16）
        top_k       : 再検証するペア数（既定3）
        verify_reps : 再検証の計測回数（既定3）
        noflush_exe : NoFlush パス上書き
        beta_raw_csv: β の生データ保存先 CSV パス

    Returns
    -------
    dict: nb, ib, time_total_sec, time_prep_sec, n_qr_exec, n_kernel_exec,
          beta, band_lo, band_hi, gflops_observed, notes
    """
    beta_given = kwargs.get("beta")
    beta_reps = kwargs.get("beta_reps", 1)
    band_thr = kwargs.get("band_thr", model_predict.THR)
    n_trials = kwargs.get("n_trials", N_TRIALS)
    top_k = kwargs.get("top_k", TOP_K)
    verify_reps = kwargs.get("verify_reps", VERIFY_REPS)
    noflush_exe = kwargs.get("noflush_exe")
    beta_raw_csv = kwargs.get("beta_raw_csv")

    p = get_physical_cores()

    time_prep = 0.0
    n_kernel_exec = 0
    beta_notes = ""
    if beta_given is None:
        fit = beta_fit.fit_beta(
            threads=threads, reps=beta_reps, exe=noflush_exe, raw_csv=beta_raw_csv
        )
        beta = fit["beta"]
        time_prep = fit["time_sec"]
        n_kernel_exec = len(fit["raw"]) * beta_reps
        if beta is None:
            beta_notes = "beta_fit失敗(有効なnbが2点未満)。model手法は実行不能"
    else:
        beta = beta_given

    if beta is None:
        return {
            "nb": None,
            "ib": None,
            "time_total_sec": time_prep,
            "time_prep_sec": time_prep,
            "n_qr_exec": 0,
            "n_kernel_exec": n_kernel_exec,
            "beta": None,
            "band_lo": None,
            "band_hi": None,
            "gflops_observed": None,
            "notes": beta_notes,
        }

    lo, hi = model_predict.predict_band(beta, p, size, thr=band_thr)
    nb0 = model_predict.predict_nb(beta, p, size)

    n_qr_exec = 0
    trial_records = []  # [(nb, ib, gflops), ...]

    def objective(trial: "optuna.Trial") -> float:
        nonlocal n_qr_exec
        nb = trial.suggest_int("nb", lo, hi)
        ib_lo = max(8, nb // 8)
        ib_hi = max(ib_lo, nb // 2)
        ib = trial.suggest_int("ib", ib_lo, ib_hi)
        g = run_time_dgeqrf(threads, size, nb, ib)
        n_qr_exec += 1
        trial_records.append((nb, ib, g))
        return g

    study = optuna.create_study(
        direction="maximize",
        sampler=optuna.samplers.TPESampler(seed=seed),
    )

    for factor in WARM_START_FACTORS:
        nb_ws = _clamp(int(round(nb0 * factor)), lo, hi)
        ib_lo = max(8, nb_ws // 8)
        ib_hi = max(ib_lo, nb_ws // 2)
        ib_ws = _clamp(nb_ws // 4, ib_lo, ib_hi)
        study.enqueue_trial({"nb": nb_ws, "ib": ib_ws})

    t0 = time.time()
    study.optimize(objective, n_trials=n_trials)
    search_elapsed = time.time() - t0

    ranked = sorted(trial_records, key=lambda r: r[2], reverse=True)
    seen = set()
    top_pairs = []
    for nb, ib, _g in ranked:
        if (nb, ib) in seen:
            continue
        seen.add((nb, ib))
        top_pairs.append((nb, ib))
        if len(top_pairs) >= top_k:
            break

    t1 = time.time()
    best_pair, best_avg = None, -1.0
    for nb, ib in top_pairs:
        vals = [run_time_dgeqrf(threads, size, nb, ib) for _ in range(verify_reps)]
        n_qr_exec += verify_reps
        avg = sum(vals) / len(vals)
        if avg > best_avg:
            best_avg, best_pair = avg, (nb, ib)
    verify_elapsed = time.time() - t1

    total_elapsed = time_prep + search_elapsed + verify_elapsed

    return {
        "nb": best_pair[0] if best_pair else None,
        "ib": best_pair[1] if best_pair else None,
        "time_total_sec": total_elapsed,
        "time_prep_sec": time_prep,
        "n_qr_exec": n_qr_exec,
        "n_kernel_exec": n_kernel_exec,
        "beta": beta,
        "band_lo": lo,
        "band_hi": hi,
        "gflops_observed": best_avg if best_avg >= 0 else None,
        "notes": beta_notes,
    }
