# XML 0.9.0 performance baseline

## Environment

- Windows 11 Pro 10.0.26200, x86-64
- Rust 1.97 stable, `--release` profile, `cargo run --locked --offline --release -p consema-conformance --example xml_baseline -- <iterations>`
- Commit: 0.9.0 development workspace (unreleased)

## Corpus and operations

Both inputs are repository-authored production-shaped fixtures under
`conformance/fixtures/xml/`, pinned byte-for-byte by the fixture gate:

- `maven-pom.xml` (1,032 bytes): namespaced root, `xsi:schemaLocation`,
  nested properties/dependencies/plugins, comments.
- `namespaced-service.xml` (635 bytes): three namespace prefixes, prefixed
  attributes, mixed content, nested backends, a processing instruction.

Operations measured per iteration:

1. **parse** — `xml.1.0-safe@1` formation under default limits with
   byte-exact render closure;
2. **projection** — exact `xml.element-tree@1` record projection;
3. **materialization** — canonical `xml.safe-canonical-document@1` including
   the mandatory reparse closure verification, returning no Document on any
   mismatch.

## Results (5,000 iterations)

| Operation | fixture | ns/op |
|---|---:|---:|
| parse | maven-pom.xml (1,032 B) | 237,837 |
| projection | maven-pom.xml | 149,218 |
| materialization | maven-pom.xml | 266,460 |
| parse | namespaced-service.xml (635 B) | 124,823 |

Materialization dominates because the contract reparses the exact generated
bytes and compares the native tree against the promised input semantics
before publishing; the cost is the price of the closure guarantee. The
parser is debug-safety instrumented and deliberately favors bounded
allocations over speed; the baseline is a reproducibility gate, not an
optimization claim.

## Reproducibility

```text
cargo run --locked --offline --release -p consema-conformance --example xml_baseline -- 5000
```

The fixture gate (`consema-rs/consema-conformance/tests/xml_fixtures.rs`；拆分前布局为 `crates/consema-conformance/tests/xml_fixtures.rs`)
independently requires byte-exact unmodified rendering, exhaustive lossless
coverage, exact projection, and the projection→materialization→reparse→
projection fixed point for every pinned fixture; the baseline never runs on
a corpus whose closure contract is broken.
