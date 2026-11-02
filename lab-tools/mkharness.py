"""Writes the local prefill_lab harness for the checked-out cubek tree: the base harness plus a
switch for each per-shape setting the tree has (never committed)."""
import sys, pathlib
root = pathlib.Path(sys.argv[1]); base = pathlib.Path(sys.argv[2]).read_text()
mk = root / "crates/cubek-microkernel/src/attention"
s = base
if "unbiased_steps" in (mk / "plane/fragment/settings.rs").read_text():
    a = '''    CubeAttentionPlaneSettings::Fragment(PlaneFragmentAttentionMicrokernelSettings::fragments(
        rows, keys,
    ))'''
    assert s.count(a) == 1
    s = s.replace(a, '''    CubeAttentionPlaneSettings::Fragment(PlaneFragmentAttentionMicrokernelSettings {
        unbiased_steps: std::env::var("CUBEK_LAB_UNBIASED").is_ok(),
        ..PlaneFragmentAttentionMicrokernelSettings::fragments(rows, keys)
    })''')
if "query_as_keys" in (mk / "cube/settings.rs").read_text():
    a = "delivery: lab_delivery(),"
    assert s.count(a) == 2
    s = s.replace(a, a + ' query_as_keys: std::env::var("CUBEK_LAB_Q_ASYNC").is_ok(),')
(root / "crates/cubek-attention/examples/prefill_lab.rs").write_text(s)
