# Official YAML test-suite acceptance gate

Consema 0.7.0 pins the official
[`yaml/yaml-test-suite`](https://github.com/yaml/yaml-test-suite) data tag
`data-2022-01-17`. The annotated tag object is
`5f49729577242103ae23838ac2ad4d9145aec126`; its peeled commit is
`6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`.

The pinned export contains 402 distinct directories with `in.yaml`. The gate
discovers all of them recursively, including numbered subtests, and rejects an
empty or duplicate case inventory. It does not use a hand-selected allowlist.

## Verified result

Last full verification on 2026-08-04:

```text
yaml-test-suite data-2022-01-17 (6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f)
cases: 402
valid accepted byte-exactly: 307
invalid rejected atomically: 94
profile-contract exclusions: 1
result: conformant
```

Every one of the 401 included cases is executed:

- an upstream valid case must form a complete Consema document and
  `Document::render()` must equal the exact input bytes;
- an upstream case carrying the `error` marker must fail before a document
  exists;
- an explicit `%YAML 1.1` directive selects `yaml.1.1-compat@1`; all other
  included cases select `yaml.1.2-core@1`.

The sole exclusion is upstream case `BEC7`. It asks processors to accept a
future `%YAML 1.3` directive with a warning. Consema's two frozen profiles do
not claim YAML 1.3 forward compatibility, so the adapter requires this case to
fail specifically with `yaml.profile.version-directive@1`. It is recorded as
an explicit profile-contract exclusion, not silently skipped or counted as an
upstream acceptance pass.

## Reproducible adapter

Run on Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run-yaml-test-suite.ps1
```

（注：六仓拆分后母仓根无 Cargo.toml——本脚本第一步 `cargo build --locked
-p consema-conformance --bin consema-yaml-test-adapter` 在母仓原位必然失败
（exit 101）；需先从 consema-rs 检出运行，或在本仓 scripts/ 原位仅作记录
载体；无 CI job 执行本脚本。）

The script clones the exact data tag when absent, verifies the peeled commit,
builds `consema-yaml-test-adapter` from the locked workspace, and writes a TSV
record for all 402 cases under `target/`. Each row contains the case ID,
upstream expectation, selected Consema profile, passed/failed/excluded status,
and exact reason. Any missing case, wrong expectation, non-byte-exact accepted
input, unexpected exclusion, or mismatched failure makes the command fail.

This external gate proves syntax acceptance/rejection and unmodified-source
retention. It deliberately does not equate yaml-test-suite's implementation
event DSL or JSON loader result with Consema's native graph, arbitrary-key,
duplicate-key, tag, alias, or scalar model. Those public semantics are frozen
by the language-neutral Consema YAML vectors and RFCs instead.

The stored upstream license is
`conformance/corpora/licenses/yaml-test-suite-MIT.txt`. An upstream tag change
must be a separate reviewed commit containing the new tag object, peeled
commit, complete case accounting, exclusion decisions, license evidence, and
full gate output.
