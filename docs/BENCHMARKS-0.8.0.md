# Consema 0.8.0 line-format benchmark baseline

This is a reproducible comparison baseline, not an API guarantee, latency SLA,
or release threshold. Measurements use the public parse/query/projection/
materialization/edit paths and retain all validation, closure, and round-trip
checks.

## Environment

- Date: 2026-08-05 (Asia/Shanghai)
- Source commit: `5f02486` (`0.8.0` workspace version)
- Benchmark harness commit: `ee27db2`
- Toolchain: `rustc 1.97.0 (2d8144b78 2026-07-07)`, LLVM 22.1.6
- Target: `x86_64-pc-windows-msvc`
- Host: Windows NT 10.0.26200.0, x64
- CPU: 13th Gen Intel Core i9-13900HX, 32 logical processors visible
- Build: Cargo `--release`; no CPU affinity, isolation, or background-process suppression

## Corpus and operations

Both inputs are repository-authored production-shaped fixtures under the
repository MIT license.

The INI input is `desktop-settings.ini` under `ini.portable@1`:

- source bytes: 177;
- lossless structural pieces: 45;
- source SHA-256: `b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8`;
- native entries: 7;
- canonical `ini.portable-canonical@1` bytes: 140.

The five INI operations are full parse and immutable formation,
`ini.all-entries@1` ordered native query, best-exact nested EntryMapping
projection, canonical materialization with target reparse and exact projection
closure, and semantic replacement of the first entry value with canonical
profile representation. The edit includes planning, patch/proof derivation,
full target reparse, and semantic verification.

The Properties input is `logging.properties` under
`java-properties.reader@1` with explicit UTF-8 Reader input:

- source bytes: 389;
- lossless structural pieces: 31;
- source SHA-256: `ce2829e6e3647a45d712b202f1f3ccc1f7966baffba0074d27b5657a5e9bfb97`;
- native property occurrences: 7;
- canonical `java-properties.reader-canonical@1` bytes: 346.

The five Properties operations are full parse and immutable formation,
`properties.document-properties@1` ordered native query, best-exact flat
EntryMapping projection, canonical materialization with target reparse and
exact projection closure, and semantic Java-string replacement of the first
property value. The edit includes planning, patch/proof derivation, full target
reparse, and semantic verification.

Canonical materialization creates a new document from the projected semantic
mapping. Its byte count is therefore not a lossless-render byte count: comments
and original presentation remain in the source Document and edit paths but are
not members of PortableValue.

Each sample uses 20,000 iterations after 100 parse/projection warm-up
iterations for each format. Reproduce with:

```text
cargo run --locked --offline --release -p consema-conformance --example line_formats_baseline -- 20000
```

## INI results

| Sample | Parse ns/op | Parse MiB/s | Native query ns/op | Projection ns/op | Materialization ns/op | Materialization MiB/s | Edit ns/op |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 36,493 | 4.62 | 627 | 6,569 | 42,642 | 3.13 | 40,906 |
| 2 | 35,383 | 4.77 | 501 | 6,819 | 41,126 | 3.24 | 37,548 |
| 3 | 36,095 | 4.67 | 556 | 6,685 | 42,184 | 3.16 | 40,792 |
| Median | 36,095 | 4.67 | 556 | 6,685 | 42,184 | 3.16 | 40,792 |

## Java Properties results

| Sample | Parse ns/op | Parse MiB/s | Native query ns/op | Projection ns/op | Materialization ns/op | Materialization MiB/s | Edit ns/op |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 142,460 | 2.60 | 298 | 4,926 | 141,612 | 2.33 | 131,239 |
| 2 | 139,990 | 2.65 | 294 | 4,822 | 142,645 | 2.31 | 131,439 |
| 3 | 166,933 | 2.22 | 394 | 6,641 | 156,681 | 2.10 | 136,551 |
| Median | 142,460 | 2.60 | 298 | 4,926 | 142,645 | 2.31 | 131,439 |

The complete sample spread is retained deliberately. Future comparisons must
use the same corpus, operation definitions, release profile, and iteration
count. Results from another machine or toolchain must be reported separately
instead of being merged into this baseline.
