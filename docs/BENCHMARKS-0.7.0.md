# Consema 0.7.0 YAML benchmark baseline

This is a reproducible comparison baseline, not an API guarantee, latency SLA,
or release threshold. Measurements use the public parse/query/projection/PGCE/
materialization/edit paths and retain all validation and round-trip checks.

## Environment

- Date: 2026-08-04 (Asia/Shanghai)
- Source commit: `64f118c` (`0.7.0` workspace version)
- Toolchain: `rustc 1.97.0 (2d8144b78 2026-07-07)`, LLVM 22.1.6
- Target: `x86_64-pc-windows-msvc`
- Host: Windows NT 10.0.26200.0, x64
- CPU: 13th Gen Intel Core i9-13900HX, 32 logical processors visible
- Build: Cargo `--release`; no CPU affinity, isolation, or background-process suppression

## Corpus and operations

The input is the repository-authored `anchor-heavy.yaml` production-shaped
fixture under the repository MIT license:

- source bytes: 315;
- lossless structural pieces: 100;
- source SHA-256: `4aa50a75d6349c968457ec34cd3a7ffbd50eb90deeaf49ee443e6ff8c450302b`;
- exact graph nodes: 31;
- canonical PGCE/1 bytes: 943;
- canonical block materialization bytes: 606;
- iterations per sample: 20,000;
- warm-up: 100 parse and graph-projection operations.

The seven measured operations are:

1. full `yaml.1.2-core@1` parse and immutable stream formation;
2. `yaml.lossless-syntax-query@1` filtered to alias pieces;
3. exact `yaml.projection.best-exact-graph@1` projection;
4. canonical PGCE/1 graph encoding;
5. `yaml.projection.best-exact-value@1` with explicit acyclic sharing duplication;
6. exact `yaml.canonical-block@1` graph materialization and target reparse;
7. anchor rename commit, including dependent alias edits, patch/proof derivation,
   and full reparse.

Reproduce with:

```text
cargo run --locked --release -p consema-conformance --example yaml_baseline -- 20000
```

## Results

| Sample | Parse ns/op | Parse MiB/s | Syntax query ns/op | Graph projection ns/op | PGCE ns/op | PGCE MiB/s | Value projection ns/op | Graph materialization ns/op | Materialization MiB/s | Anchor edit ns/op |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 66,405 | 4.52 | 294 | 2,571 | 1,644 | 546.86 | 52,362 | 177,535 | 3.25 | 75,835 |
| 2 | 70,693 | 4.24 | 254 | 2,803 | 1,613 | 557.47 | 56,009 | 179,667 | 3.21 | 77,038 |
| 3 | 67,860 | 4.42 | 290 | 2,610 | 1,460 | 615.62 | 55,227 | 182,355 | 3.16 | 76,216 |
| Median | 67,860 | 4.42 | 290 | 2,610 | 1,613 | 557.47 | 55,227 | 179,667 | 3.21 | 76,216 |

The complete sample spread is retained deliberately. Future comparisons must
use the same corpus, operation definitions, release profile, and iteration
count. Results from another machine or toolchain must be reported separately
instead of being merged into this baseline.
