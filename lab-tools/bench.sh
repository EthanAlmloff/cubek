#!/usr/bin/env bash
# bench.sh <binary> <queries> <keys> <filter> [ENV=VAL ...]
# 3 clean runs of setting <filter> (winner skipped): median µs and max diff. A run during which
# another process held the GPU (seen before or after it) is thrown away and retried.
bin=$1; q=$2; k=$3; filter=$4; shift 4
ref=$HOME/Projects/refs/ref_${q}_${k}.bin
[ -f "$ref" ] || { echo "no reference $ref"; exit 1; }
busy() { [ -n "$(nvidia-smi --query-compute-apps=pid --format=csv,noheader)" ]; }
lines=(); tries=0
while [ ${#lines[@]} -lt 3 ] && [ $tries -lt 30 ]; do
  tries=$((tries+1))
  while busy; do sleep 5; done
  line=$(flock /tmp/gpu-timing.lock bash -c 'busy() { [ -n "$(nvidia-smi --query-compute-apps=pid --format=csv,noheader)" ]; }; busy && exit 3; out=$(env "$@" | tail -n +2); busy && exit 3; echo "$out"' _ \
    "$@" CUBEK_LAB_REF=$ref CUBEK_LAB_NO_WINNER=1 CUBEK_LAB_FILTER="$filter" "$bin" 32 8 $q $k full 2>/dev/null | grep -F "$filter" | head -1)
  [ -n "$line" ] && lines+=("$line")
done
us=$(for l in "${lines[@]}"; do echo "$l" | awk -F, '{print $3}'; done | sort -g | sed -n 2p)
diff=$(echo "${lines[0]}" | awk -F, '{print $NF}')
echo "$q x $k | $filter | $* | median ${us} us | maxdiff ${diff} | runs: $(for l in "${lines[@]}"; do echo -n "$(echo "$l" | awk -F, '{print $3}') "; done)| tries $tries"
