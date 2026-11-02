# Running note: prefill attention port (God 2's successor session)

## Track in hand
Port of the long-prompt attention lab work into PRs. Report: https://claude.ai/artifact/LKvWRjGaQnyUytkENPf14a

## Decisions made without you
- 2026-11-02 ~14:20: #2019 merged at 13:58, so no PR pins #2019's head and none carries "Merge after: cubecl#2019".
- Split by measurement: wide blocks, inner fills, last-first, 8-warp shapes each a PR; unbiased steps and async Q stacked on the 8-warp PR because each flips per-shape flags on its rows.
- Async Q and unbiased steps kept per shape, never defaults (each costs some shapes 1–4%).
- Not ported: lab switches outside the spec (SPLIT_KV, FILLERS, EARLY_K, LOCAL_SUMS, CUBES, OUT_BOUNCE, timing-only ones).
- #1060 keeps a special cubecl pin (dev's pin + cubecl#2029) until #2029 merges; I re-merge it on each promotion.
- Killed my own debug-build correctness run (held the GPU lock while CPU-bound); reran in release, unlocked: 34/34.
- Timings re-run on current pins after dev moved (cubecl #2034 etc.), since the earlier 1495 µs was at d8d66ab3.

## Mistakes
- A scripted dev merge pushed conflict markers to #1061–#1064 for a few minutes; fixed with follow-up commits (force push was blocked, as it should be).

## Waiting on you
- Merge cubecl#2029 (then #1060 takes dev's pin), then the cubek PRs.
- Clock lock: `nvidia-smi -lgc 2100` reports success but I read 2317–2332 MHz under load; not reset, since another session times on this GPU.

## Log
- 18:5x: final race on current pins running (dev2 best at 6016×8192: 1969 µs; stack's 8-warp rows pending).
- 19:0x: stack regressed on current pins (8-warp f1x8 copy-engine 1495 -> 2376 µs, single pass); paused the race queue to A/B old vs new builds.
- 19:2x: the 'regression' rows overlapped the other session's unlocked metabolic correctness run (on the GPU 18:5x–19:3x); A/B waits for it to end before timing. Decision: treat those race rows as suspect, re-run after.
- 19:5x: peer reports unlocked GPU runs 15:50–18:30, so the 1495/2060 µs race (16:16–16:40) is suspect too. Decision: re-measure all headline numbers now, with bench.sh rejecting any run that overlaps another GPU process; peer locks everything until 21:00.
- 20:2x: asked about cubek#1070/cubecl#2033: not mine (opened 20:20/16:57 by another session); told the orchestrator to go ahead. Clean A/B so far: old vs current stack identical (1768 vs 1767 µs by units) -> the 'regression' was contamination.
- 20:4x: you came back; #1070 again: told the orchestrator it's not mine, they should take it.
- 21:1x: xtask check format/typos/lint pass on cubecl feat/walk-over-run and on cubek wide, inner-fills, last-first, async-query (contains #1062-#1064). Clean A/B: current stack == old stack (1767/1520 µs vs 1768/1521).
- 21:35: clean A/B done (f1x8 h4 pq2 double swz, LF, 6016x8192): old dev 2139/1873, current dev 2012/1751, stack 1767/1520 µs (by units / copy engine). Race3 (clean listed race, all sizes) started.
- 22:3x: race3 (clean, listed settings, median of rounds) done. Best per problem, dev2 -> stack (FlashInfer): 6016x8192 1966 -> 1493 (1561); 2048² 231 -> 191 (162); 4096² 672 -> 524 (504); 8192² 2128 -> 1648 (1676); 16384² 8061 -> 6301 (6232); 512x8192 376 -> 312 (276). The stack's winner is f1x8 unbiased + Q async + last-first everywhere except 16384² (f2x4).
