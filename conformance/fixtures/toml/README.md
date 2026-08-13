# TOML corpus fixtures

The `.toml` files here are the inputs of the `consema.toml.conformance@1`
cases (conformance/vectors/toml-v1.json), referenced by repository-relative
path. All five language runners (Rust, Go, TypeScript, Python, Kotlin) read
these files directly; this directory is the single authority.

- `all-values.toml` — `toml.parse.exact-roundtrip`, `toml.native.*`,
  `toml.projection.all-core-kinds` and related cases.
- `application.toml` — `toml.parse.lossless-byte-coverage`.
- `trivia-and-strings.toml` — `toml.parse.lossless-byte-coverage`.
- `invalid-duplicate.toml` — `toml.parse.reject-invalid`.
- `pyproject.toml` — `toml.corpus.pyproject`.
- `Cargo.toml` — `toml.corpus.cargo-manifest`. This is the consema-rs
  workspace root manifest (six-repo split assembly, version
  1.0.0-rc.1), kept here because the workspace root of every other
  repository no longer carries a Cargo.toml. The five language runners
  read `conformance/fixtures/toml/Cargo.toml`; no provision step copies a
  Cargo.toml into any workspace root anymore. The content is
  byte-identical to the committed consema-rs root Cargo.toml
  （如实注记：全链无逐字节比对机制——唯一消费者
  consema-rs/consema-conformance/src/toml_v1.rs:96 对
  `toml.corpus.cargo-manifest` case 只做 parse/round-trip，不比对字节；
  版本 bump 后夹具可能静默漂移，须人工同步）。

The `toml.corpus.cargo-manifest` case requires the fixture to be a real,
parseable TOML document that renders byte-exact: keep it byte-identical to
the consema-rs root manifest when that manifest changes (a split-assembly
commit in consema-rs updates this file; the byte-identity claim above is
maintained by manual discipline, not by a comparison test).
