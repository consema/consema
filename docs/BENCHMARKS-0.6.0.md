# Consema 0.6.0 JSON family benchmark baseline

This is a reproducible comparison baseline, not an API guarantee, latency SLA, or release threshold. Measurements use the public parse/query/projection/materialization/edit paths and retain their validation work.

## Environment

- Date: 2026-08-04 (Asia/Shanghai)
- Source commit: `9300d64` (`0.6.0` workspace version)
- Toolchain: `rustc 1.97.0 (2d8144b78 2026-07-07)`, LLVM 22.1.6
- Target: `x86_64-pc-windows-msvc`
- Host: Windows NT 10.0.26200.0, x64
- CPU: 13th Gen Intel Core i9-13900HX, 32 logical processors visible
- Build: Cargo `--release`; no CPU affinity, isolation, or background-process suppression

## Corpus and operations

The input is the pinned JSON5 v2.2.3 `package.json5` fixture stored with LF line endings:

- source bytes: 1,893;
- lossless structural pieces: 364;
- stored SHA-256: `ef3136abec4e0a19f610e39c7654dda5a06fee242ab8012df87d7ad9911411ad`;
- canonical JSON5 output bytes: 1,566;
- iterations per sample: 20,000;
- warm-up: 100 parse and projection operations.

The five measured operations are:

1. full `json5.standard@1` parse and immutable document formation;
2. `json.lossless-syntax-query@2` filtered to `Identifier` pieces;
3. `json5.projection.best-exact-core@1` complete projection;
4. `json5.canonical-compact@1` complete materialization and target reparse;
5. representation-preserving string edit commit with patch/proof derivation and full reparse.

Reproduce with:

```text
cargo run --release -p consema-conformance --example json_family_baseline -- 20000
```

## Results

| Sample | Parse ns/op | Parse MiB/s | Syntax query ns/op | Projection ns/op | Materialization ns/op | Materialization MiB/s | Edit ns/op |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 31,437 | 57.42 | 1,712 | 79,908 | 86,065 | 17.35 | 35,654 |
| 2 | 30,834 | 58.54 | 1,702 | 88,080 | 105,409 | 14.16 | 48,104 |
| 3 | 31,735 | 56.88 | 1,399 | 82,187 | 90,659 | 16.47 | 46,895 |
| Median | 31,437 | 57.42 | 1,702 | 82,187 | 90,659 | 16.47 | 46,895 |

The sample spread is retained deliberately. Future comparisons must use the same corpus, operation definitions, release profile, and iteration count; results from different hardware or toolchains must be reported separately rather than merged into this baseline.
