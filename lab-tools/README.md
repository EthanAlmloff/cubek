# Prefill attention port: measurement tools (not for merging)

Branch `lab/prefill-port-tools` = `lab/attention-prod-all` (every PR of the stack merged) plus:
- `crates/cubek-attention/examples/prefill_lab.rs`: the lab harness, with a `listed` suite that times
  the routine's own listed settings (what autotune races) and switches for the per-shape settings.
  Generate it for any branch with `python3 lab-tools/mkharness.py . lab-tools/prefill_lab.base.rs`.
- `bench.sh` (3 clean runs of one setting), `scan.sh` (3 runs of a filtered set), `race3.sh` (listed
  race on all problems): every run under `flock /tmp/gpu-timing.lock`, retried if another GPU process
  appears around it. Paths in them point at ~/Projects/{bins,refs,lab}.
- `fi_bench.py`: FlashInfer on the same inputs, plus a reference check.
- `results/`: raw CSV/text of every measurement (see NOTES.md for which windows were contaminated).
References: regenerate from unmodified dev with `CUBEK_LAB_SAVE_REF=<path> CUBEK_LAB_FILTER=__none__
prefill_lab 32 8 <q> <k> full`; output layout is [queries, heads, dim] f32.
Report: https://claude.ai/artifact/LKvWRjGaQnyUytkENPf14a
