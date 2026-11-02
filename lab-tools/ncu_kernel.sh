#!/usr/bin/env bash
# ncu_kernel.sh <binary> <q> <k> <filter> [ENV=VAL ...]: kernel-only time (gpu__time_duration) of
# the attention launches of the listed settings matching <filter> (prefill_lab's `listed` suite), median over the profiled launches. Clocks are
# left as they are (--clock-control none). Runs under the GPU lock.
bin=$1; q=$2; k=$3; filter=$4; shift 4
out=$(flock /tmp/gpu-timing.lock sudo -E env "$@" CUBEK_LAB_NO_WINNER=1 CUBEK_LAB_FILTER="$filter" CUBEK_LAB_LAUNCHES=3 \
  /usr/local/cuda-13.3/bin/ncu --clock-control none --metrics gpu__time_duration.sum --csv \
  --launch-skip 2 --launch-count 12 "$bin" 32 8 $q $k listed 2>/dev/null)
echo "$out" | grep gpu__time_duration | awk -F'","' '{print $5 "|" $NF}' | tr -d '"' | sort | uniq -c | sort -rn | head -3
