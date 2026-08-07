# consema CLI 0.12.0 performance baseline

## Environment

- Date: 2026-08-07 (local)
- Windows 11 Pro 10.0.26200, x86-64
- CPU: 13th Gen Intel Core i9-13900HX, 32 logical processors; no CPU
  affinity, isolation, or background-process suppression — the machine ran
  under concurrent background load (IDE, messaging clients, and the
  parallel 0.12.0 conformance milestone's cargo builds), so per-sample
  spread is wider than on an idle box; the median discipline and the
  retained raw spread are the reproducibility contract
  (BENCHMARKS-0.11.0.md 体例).
- Rust 1.97.1 stable (`8bab26f4f 2026-07-14`), `--release` profile,
  `cargo build --release --locked -p consema`
- Binary: `target/release/consema.exe` built from the 0.12.0 development
  workspace (unreleased, HEAD `b505ada`; includes the milestone-M9
  conformance self-check)
- Timing harness: PowerShell `Stopwatch` wall clock around N invocations of
  the CLI binary; each figure is the **whole process** cost (spawn + argv
  parse + command + shutdown) and includes no in-process SDK shortcut —
  this is the product-entry metric, not a parser microbenchmark. Per-sample
  command lines are listed under Reproducibility.

## Corpus and operations

Corpus is repository-authored, pinned-by-fixture-gate inputs under
`conformance/fixtures/`, plus a generated 100-file INI batch:

- `real-world/package.json` (424 bytes): production-shaped strict JSON.
- `xml/maven-pom.xml` (1,032 bytes): namespaced Maven POM.
- Batch corpus: 100 byte-identical copies of `ini/desktop-settings.ini`
  (177 bytes each), regenerated from the fixture between apply samples.

Operations measured (3 samples each; medians below; sample spread retained
deliberately):

1. **inspect** — `consema inspect <fixture>`: cold start + file facts
   (bytes/digest/BOM/markers/candidates) without parse.
2. **inspect --profile** — adds formation under the explicit profile and
   structure counts (`cli.parse-facts@1`), the parse path of `inspect`.
3. **query (human)** — `consema query --profile json.strict
   --request-file q.json` with a fixed `cli.request@1`/`core.query-
   definition@1` request over package.json: strict request decode + source
   read + parse + default projection + `core.try-object-entries` execution
   + human report render.
4. **query --json** — same pipeline plus the `core.cli-output@1` envelope
   canonical-JSON encode on stdout (the machine-output path).
5. **batch plan** — `consema plan` over 100 INI files with one
   `ini.edit.replace-semantic-value@1` operation each, manifest to
   `--output` (read-only: the source files are never written).
6. **batch apply** — `consema apply plan.json` over the same 100-file
   plan: per-file digest re-verification, original-bytes precondition,
   same-directory temp file + atomic rename, read-back target-digest
   verification, result manifest write. The batch corpus is regenerated
   before every sample.
7. **envelope round-trip** — `consema conformance`: the embedded
   self-check performs two full `core.cli-output@1` envelope round-trips
   per invocation (canonical JSON encode/decode + PVCE/1 encode/decode +
   byte-determinism re-encode) plus the redaction self-check; the figure
   is 2 round-trips per invocation.

## Results

Per-invocation operations: 1,000 iterations per sample.

| Operation | Sample 1 ns/op | Sample 2 ns/op | Sample 3 ns/op | Median ns/op |
|---|---:|---:|---:|---:|
| inspect package.json (424 B) | 11,335,953 | 6,995,464 | 6,399,660 | 6,995,464 |
| inspect package.json --profile json.strict | 6,271,187 | 9,522,649 | 13,870,808 | 9,522,649 |
| inspect maven-pom.xml --profile xml.1.0-safe (1,032 B) | 6,941,766 | 6,850,586 | 10,436,081 | 6,941,766 |
| query package.json (human report) | 6,235,967 | 6,511,110 | 7,186,080 | 6,511,110 |
| query package.json (--json envelope) | 7,012,051 | 6,333,801 | 5,639,119 | 6,333,801 |
| conformance (2 envelope round-trips + redaction check) | 5,095,011 | 5,673,301 | 4,975,421 | 5,095,011 |

Batch operations: 1 batch per sample (single invocation).

| Operation | Sample 1 ns/op | Sample 2 ns/op | Sample 3 ns/op | Median ns/op |
|---|---:|---:|---:|---:|
| plan 100 INI files (1 operation each) | 64,693,000 | 78,558,000 | 63,868,700 | 64,693,000 |
| apply 100 INI files (atomic writes + re-verification) | 4,621,222,100 | 4,630,786,300 | 5,001,254,100 | 4,630,786,300 |

Reading notes:

- Per-invocation cost (~5-10 ms) is dominated by process start and file
  I/O, not by parse or protocol work; `inspect` with formation costs the
  same order as facts-only at this file size, and the query pipeline adds
  the request decode and query execution on top. The `--json` machine path
  is not measurably slower than the human path for this corpus.
- Batch plan costs ~0.65 ms per file (100 files ≈ 65 ms); batch apply
  costs ~46 ms per file (100 files ≈ 4.6 s), dominated by the per-file
  write path: digest re-verification of the current bytes, original-bytes
  precondition check, temp-file write, atomic rename, read-back digest
  verification, and the result-manifest bookkeeping (RFC 0015 §9
  six-step revalidation). Apply is deliberately write-costed; it is not an
  optimization claim.
- The complete sample spread is retained deliberately; the first sample of
  each op often carries one-time OS/disk warmup, and the shared machine's
  background load widens the spread. Future comparisons must use the same
  corpus, operation definitions, release profile, binary build, and
  harness; results from another machine or toolchain must be reported
  separately instead of being merged into this baseline.

## Reproducibility

Build:

```text
cargo build --release --locked -p consema
```

Harness (per-invocation wall clock over N iterations, exit code checked
per iteration):

```powershell
$sw = [System.Diagnostics.Stopwatch]::new(); $sw.Start()
for ($i = 0; $i -lt $N; $i++) { & consema.exe @Args | Out-Null; if ($LASTEXITCODE -ne 0) { throw } }
$sw.Stop(); $sw.Elapsed.TotalMilliseconds * 1e6 / $N
```

Sample command lines (one sample of each operation; `F` is
`conformance/fixtures`, `C` is the scratch corpus directory):

```text
consema inspect <F>\real-world\package.json
consema inspect <F>\real-world\package.json --profile json.strict
consema inspect <F>\xml\maven-pom.xml --profile xml.1.0-safe
consema query --profile json.strict --request-file <C>\query-req.json
consema query --profile json.strict --request-file <C>\query-req.json --json
consema conformance
consema plan <C>\settings-001.ini ... <C>\settings-100.ini --profile ini.portable --request-file <C>\edit-req.json --output <C>\plan.json
consema apply <C>\plan.json --output <C>\result.json
```

The request files (`query-req.json`, `edit-req.json`) are the strict
canonical-tagged-JSON records of RFC 0015 §3.2 (the query request pins
`core.query-definition@1` with `core.try-object-entries` over
`<F>\real-world\package.json`; the edit request pins
`ini.edit.replace-semantic-value@1` on entry `window:width` of every batch
file); the batch corpus is regenerated from the fixture between apply
samples.
