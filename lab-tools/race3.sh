#!/usr/bin/env bash
# Listed-settings race of dev2 and final2 on every problem, then the lab's best config; every
# harness call runs under the GPU lock and is retried if another GPU process appears around it.
S=/tmp/claude-1140614255/-home-louis-fortier-dubois-tracel-ai/b1a9321c-4753-4a06-8ebf-0d29e9ce991f/scratchpad
L=$HOME/Projects/lab
busy() { [ -n "$(nvidia-smi --query-compute-apps=pid --format=csv,noheader)" ]; }
clean_run() { # args: env-and-command...
  for t in $(seq 1 20); do
    while busy; do sleep 5; done
    out=$(flock /tmp/gpu-timing.lock bash -c 'busy() { [ -n "$(nvidia-smi --query-compute-apps=pid --format=csv,noheader)" ]; }; busy && exit 3; o=$(env "$@" 2>/dev/null); busy && exit 3; echo "$o"' _ "$@") && { echo "$out"; return; }
  done
}
: > $L/race3.csv
for p in "6016 8192" "2048 2048" "4096 4096" "8192 8192" "16384 16384" "512 8192"; do set -- $p
  for b in dev2 final2; do
    clean_run CUBEK_LAB_REF=$HOME/Projects/refs/ref_$1_$2.bin $HOME/Projects/bins/$b 32 8 $1 $2 listed | grep -v "^routine" | sed "s/^/$b,$1x$2,/" >> $L/race3.csv
  done
done
echo RACE_DONE >> $L/race3.csv
