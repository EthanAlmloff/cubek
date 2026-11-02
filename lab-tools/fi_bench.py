"""FlashInfer prefill timing on the prefill_lab problems, and a check of the saved references.

usage: fi_bench.py <queries> <keys> [ref.bin]

Inputs are the harness's own (`random_f16` in prefill_lab.rs): an LCG per tensor, values in
[-1, 1) as f16, shaped [1, heads, seq, 128]. Causal, queries placed last (FlashInfer's bottom-right
alignment). Kernel time from CUDA events: the median of 7 rounds of 20 launches. The harness saves
its output as [queries, heads, dim] f32.

Setup used: uv venv -p 3.12; torch (cu130 index); flashinfer-python 0.7.2; ninja and nvcc on PATH.
"""
import sys
import numpy as np
import torch
import flashinfer

A = np.uint64(6364136223846793005)
C = np.uint64(1442695040888963407)
DIM, HEADS, KV_HEADS = 128, 32, 8


def random_f16(shape, seed):
    count = int(np.prod(shape))
    block = 1 << 14
    with np.errstate(over="ignore"):
        mul = np.empty(block, np.uint64)
        add = np.empty(block, np.uint64)
        m, a = np.uint64(1), np.uint64(0)
        for j in range(block):
            m, a = m * A, a * A + C
            mul[j], add[j] = m, a
        state = np.uint64(seed) * A + C
        out = np.empty(count, np.uint64)
        for start in range(0, count, block):
            n = min(block, count - start)
            out[start:start + n] = mul[:n] * state + add[:n]
            state = out[start + n - 1]
    unit = (out >> np.uint64(40)).astype(np.float64) / float(1 << 24)
    return (unit * 2.0 - 1.0).astype(np.float32).astype(np.float16).reshape(shape)


def main():
    q_len, kv_len = int(sys.argv[1]), int(sys.argv[2])
    ref = sys.argv[3] if len(sys.argv) > 3 else None
    q = torch.from_numpy(random_f16([1, HEADS, q_len, DIM], 1))[0].transpose(0, 1).contiguous().cuda()
    k = torch.from_numpy(random_f16([1, KV_HEADS, kv_len, DIM], 2))[0].transpose(0, 1).contiguous().cuda()
    v = torch.from_numpy(random_f16([1, KV_HEADS, kv_len, DIM], 3))[0].transpose(0, 1).contiguous().cuda()
    run = lambda: flashinfer.single_prefill_with_kv_cache(q, k, v, causal=True)
    out = run()
    torch.cuda.synchronize()
    rounds = []
    for _ in range(7):
        start, end = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
        start.record()
        for _ in range(20):
            run()
        end.record()
        torch.cuda.synchronize()
        rounds.append(start.elapsed_time(end) * 1000 / 20)
    rounds.sort()
    line = f"flashinfer {q_len}x{kv_len}: {rounds[3]:.1f} us (rounds {' '.join(f'{r:.1f}' for r in rounds)})"
    if ref:
        theirs = np.fromfile(ref, dtype=np.float32).reshape(q_len, HEADS, DIM).transpose(1, 0, 2)
        ours = out.float().transpose(0, 1).cpu().numpy()
        line += f" | ref vs flashinfer maxdiff {np.abs(theirs - ours).max():.2e}"
    print(line)


if __name__ == "__main__":
    main()
