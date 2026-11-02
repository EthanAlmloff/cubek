#!/usr/bin/env bash
# scan.sh <tag> <binary> <queries> <keys> <filter> [ENV=VAL ...]
# Times every setting matching <filter> (|-separated) 3 times under the GPU lock; prints, per
# setting, "<tag>,<q>x<k>,<setting>,<median us>,<maxdiff>" sorted fastest first.
tag=$1; bin=$2; q=$3; k=$4; filter=$5; shift 5
ref=$HOME/Projects/refs/ref_${q}_${k}.bin
[ -f "$ref" ] || { echo "no reference $ref"; exit 1; }
tmp=$(mktemp)
for i in 1 2 3; do
  flock /tmp/gpu-timing.lock env "$@" CUBEK_LAB_REF=$ref CUBEK_LAB_NO_WINNER=1 CUBEK_LAB_HEADS=4 CUBEK_LAB_PQ=2 \
    CUBEK_LAB_FILTER="$filter" "$bin" 32 8 $q $k full 2>/dev/null | grep -v "^routine" | grep -v "declined\|panicked" \
    | awk -F, '{print $1","$3","$NF}' >> $tmp
done
python3 - "$tmp" "$tag" "${q}x${k}" <<'EOF'
import sys, statistics, collections
rows = collections.defaultdict(list); diff = {}
for line in open(sys.argv[1]):
    name, us, d = line.strip().rsplit(",", 2)
    rows[name].append(float(us)); diff[name] = d
out = sorted((statistics.median(v), n) for n, v in rows.items())
for med, n in out:
    print(f"{sys.argv[2]},{sys.argv[3]},{n.removeprefix('cube ')},{med:.1f},{diff[n]},n={len(rows[n])}")
EOF
rm -f $tmp
