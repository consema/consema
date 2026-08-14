# RFC 0015: CLI machine protocol and batch apply v1

- Status: Implemented in Consema 0.12.0
- Date: 2026-08-07
- Scope: the machine-readable protocol of the `consema` CLI (envelope,
  exit-code classification, batch-plan/batch-result manifests, detection

- 引用约定（2026-08-15 追加）：本文件对路线图、SECURITY.md、IMPLEMENTATION.md 的引用一律以节标题/语义句为锚，不再标注行号（行号可能漂移；本文件其余「line N」如指向 append-only 账本 waves.log 除外）。
  facts, secret redaction, fsio write policy, resource limits, error
  algebra) and the semantic-model v7 registration boundary; the machine
  schemas of all 11 official commands are frozen as v1 candidates (roadmap
  §15.6「API 与产品门禁」); roadmap §27 R-17 (`0.12.0`)
- Depends on: RFC 0011 (semantic-model v6 registration and error-code
  discipline), RFC 0012/0013/0014 (source-contract and registry-boundary
  precedent), roadmap §10 (product-level CLI), §14.11 (0.12.0 scope and
  hard gates), §12.3 item 13 (RFC-first), §15.6 (freeze as v1 candidate),
  §19.2 (side-effect-free security boundary), §26.6 (stale-digest and
  original-bytes dual preconditions), `docs/cli-implementation-plan.md`
  (the 0.12.0 execution plan; this RFC is its M1 deliverable)
- External behavior references: none; the only external contracts are the
  existing `consema-protocol` transports (canonical JSON and PVCE/1) and
  the facade public API

## 1. Decision

Consema 0.12.0 publishes the official `consema` CLI (a `[[bin]]` target of
`consema-rs/consema`) and freezes its machine-readable protocol as a v1
candidate. The machine protocol consists of three registered contracts and
several command-level payload records:

```text
core.cli-output@1     the machine envelope for every command (fixed-field
                      PortableValue, dual transport)
core.batch-plan@1     the batch-plan manifest produced by `consema plan`
                      (read-only artifact)
core.batch-result@1   the batch-result manifest produced by `consema apply`
                      (carries interruption-recovery facts)
```

The three contracts enter the `ContractRegistry` of semantic-model v7
(38 → 41 records) and the `cli.*` error family enters
`ErrorCodeRegistry::v7()` (166 → 186 codes), with the exact lists frozen by
this RFC (Section 13). (0.13.0 errata: the audit-F3 fix registered
`json.projection.incomplete-document@1`, emitted by the 0.13.0 json
Recovered-document gate, in v7 — 187 codes total; the Section 13.1
`cli.*` list itself is unchanged.) Command-level payload records
(`cli.inspect@1`,
`cli.capabilities@1`, `cli.explain@1`, `cli.conformance@1`,
`cli.convert@1`, `cli.edit@1`, and the detection-facts record) appear only
as envelope payloads and are **not registered** (Section 6).

The CLI is the product entry point, but not the normative authority and not
a third implementation (roadmap §2「目标、产品与标准的关系」——「CLI 是产品入口，但不是规范权威，也不是第三个实现」句): the machine protocol is a
language-neutral semantic-model payload, and the Go CLI (0.19.0, roadmap
§22.6) implements the same protocol; the Rust CLI binary is only the first
driver of that contract. All of the CLI's format knowledge comes from the
facade public API (hard gate 1, Section 2).

## 2. Scope and non-goals

### 2.1 Scope

- The machine-readable protocol covers **all 11 official commands**
  (inspect, capabilities, query, project, materialize, convert, edit, plan,
  apply, conformance, explain) and **every outcome**: success (including
  Recovered reports, ambiguity reports, and unauthorized-loss reports),
  usage errors, data errors, limit errors, precondition errors, internal
  errors, and user interruption.
- The protocol covers the stdout machine output (`--json` envelope), the
  `plan`/`apply` manifest files, request input (`--request-file`/stdin as
  canonical JSON or PVCE), exit-code classification, stdout/stderr
  separation, secret-redaction presentation facts, detection facts and
  ambiguity, the batch state machine, the write policy, and CLI-layer
  resource limits.
- Human output (tables/indented text) is not a cross-language contract and
  does not enter the semantic model (roadmap §11.2「Go 不是 Rust 的翻译」;
  implementation plan §11 item 5); but human and machine output must draw
  from the same facade call, differing only in rendering (implementation
  plan §2.4).

### 2.2 Non-goals (explicit v1 exclusions)

- No new parse/query/project/materialize/edit/convert implementation code:
  `src/bin/consema/` contains none of that semantics; every command is a
  thin driver of "arguments → facade call → rendering" (hard gate 1;
  implementation plan §0.3, §11).
- No new evaluation, import, network, or environment-read path: the CLI
  never executes programs embedded in configuration during parse/query/
  project (roadmap §10「产品级 CLI」). The single exception is the documented
  `apply` testing/CI injection seam of Section 5.4
  (`CONSEMA_APPLY_INTERRUPT_AFTER`, `CONSEMA_APPLY_WRITE_FAILURE`): it
  reads exactly those two variables, is scoped to the `apply` command
  only, and is documented in `--help`.
- No "try every dialect" automatic detection: detection returns only facts
  or ambiguity and never emits a single "this is X format" conclusion
  (hard gate 2; Section 7).
- No invented format-semantic defaults: duplicate/lossy/encoding/
  EntryMapping/RequireObject policies are always given by explicit
  arguments or request payloads (roadmap §10「产品级 CLI」).
- No cross-filesystem multi-file atomicity claim: fsio promises only
  single-file atomic replacement; the "batch atomicity" of `apply` is the
  recoverability of the manifest state machine, not a filesystem
  transaction (roadmap §10「产品级 CLI」; Section 10).
- CLI file I/O never returns to the Document core or backend crates:
  fsio/plan/apply all live in the bin layer (roadmap §6「统一操作链条」;
  §19.2「无副作用安全边界」).
- No new external dependencies: argument parsing, pretty JSON, fsio, and
  redaction are all self-written; clap/tempfile/serde_json are rejected
  (Section 17).

### 2.3 Hard gates

```text
hard gate 1   compile-time enforcement: bin and lib share one crate; the
              bin may access only the facade public API; src/bin/consema/
              contains no format-semantics implementation code
hard gate 2   detection facts never produce a conclusion: no parse
              authorization, no conclusion output, no side effects
hard gate 3   redaction is presentation-only: it never removes the byte
              preconditions required to apply a SourcePatch
hard gate 4   no command writes a target file without an explicit
              confirmation argument (read-only/dry-run by default)
hard gate 5   machine output is byte-deterministic: identical input +
              identical state → identical bytes (Section 3.3)
```

## 3. Transport and determinism

### 3.1 Transport contracts (existing; referenced, not redefined)

All registered contracts and envelope payloads are fixed-field
`PortableValue` trees carried by the existing dual transports:

- canonical JSON: `encode_json`/`decode_json`
  (`consema-rs/consema-protocol/src/value_transport.rs`), outer envelope
  fixed as `{"schema":"core.portable-value-json@1","value":...}`; objects
  are ordered `entries` arrays `[{key, value}]`; integers are stringified;
  Bytes are lowercase hex; unknown/missing/reordered fields, non-canonical
  representations, and whitespace are strictly rejected; the decoded value
  must re-encode to the exact input bytes.
- PVCE/1: `encode_pvce`/`decode_pvce` (`value_transport.rs`),
  rejecting non-canonical varints and integers.
- The two transports are equivalent within the semantic model: the
  dual-transport bytes of one `PortableValue` are proven by the
  `consema.cli.conformance@1` vectors (Section 16).

The envelope follows the existing envelope discipline
(`consema-rs/consema-protocol/src/contract.rs`): the payload object's
first field must be `schema` with a value equal to `(id@version)`;
dispatch keys on the exact `(contract.id, contract.version)` pair and never
selects a version from field content (RFC 0011 Section 11).

### 3.2 Request input

`query`/`project`/`materialize` requests arrive via `--request-file <path>`
or stdin, accepted as canonical JSON or PVCE (distinguished by file magic:
a leading `PVCE` magic means PVCE/1, otherwise strict canonical JSON
decode), strictly decoded to the existing contracts:

```text
core.query-definition@1            query command (protocol query.rs)
core.projection-request@1          project command (protocol projection.rs)
core.materialization-request@2     materialize command (protocol materialization.rs)
```

A request that fails strict decode is a data error (exit 2,
`cli.data.invalid-request@1`), except decode `ResourceLimit`, which is a
limit error (exit 3). Decoded requests must pass typed-decoder revalidation
of cross-constraints; the `schema` field alone never bypasses validation
(RFC 0011 Section 11; SECURITY.md——行号可能漂移，以语义句为锚).

### 3.3 Byte determinism

For identical input and identical state, the `--json` stdout, the
`--output` files, and the manifest files are **byte-identical**. Frozen
rules:

- Output must never contain: timestamps, process IDs, random nonces,
  environment values, locale, hostname, path canonicalization (the `path`
  field carries the user-supplied spelling verbatim; no canonicalization,
  no cwd joining), memory addresses, or `SnapshotIdentity` integers (these
  must be externalized to caller-stable locators; SECURITY.md——行号可能漂移，以语义句为锚).
- `product_version` is the release version string (workspace version),
  without git hashes or build metadata.

> **2026-08-10 revision (product-version validation extended to full SemVer
> syntax)**: the product-version validation is extended from strict
> `MAJOR.MINOR.PATCH` to the full SemVer 2.0 core syntax — prerelease
> suffixes such as `1.0.0-rc.1` and `1.0.0-beta.2` are accepted; all other
> constraints are unchanged (no git hashes, no build metadata; the `+`
> suffix is rejected). Rationale: the roadmap §13/§12.1 product-version
> sequence ships `1.0.0-rc.n` as prerelease versions; the cli-v1 vectors
> pin no prerelease rejection, so the vectors stay valid. Implemented by
> the identical `is_semantic_version` extension in
> `consema-rs/consema-protocol/src/cli.rs` and `go/protocol/cli.go`.
- Ordering: `files` arrays follow the command-line argument order;
  diagnostics follow a deterministic order (source order/argument order);
  `DiagnosticMessage.arguments` is a sorted map (existing contract
  guarantee).
- Human output is equally deterministic. Under `--json`, stdout carries
  exactly one line of canonical JSON envelope ending in one LF (0x0A) and
  nothing else; without `--json`, stdout carries only command-result data;
  all diagnostics, progress, and redaction notices go to stderr (roadmap
  §10「产品级 CLI」).
- `--json --pretty` performs pure whitespace indentation on canonical JSON
  bytes (self-written deterministic indenter, no parse/reorder); canonical
  semantics are unchanged (implementation plan §5.2).

## 4. `core.cli-output@1` envelope

### 4.1 Fixed fields

```text
core.cli-output@1 (Stable, dual transport):
  schema            String   "core.cli-output@1" (first field)
  command           String   inspect | capabilities | query | project | materialize
                             | convert | edit | plan | apply | conformance | explain
  exit_class        String   success | usage | data | limit | precondition | internal
  product_version   String   semantic version (e.g. "0.12.0")
  payload           Object   command-level record (Section 6 table; exactly one
                             schema per command)
  diagnostics       [core.diagnostic@1]
  redaction         { redacted: Boolean, count: Integer(u64) }
```

### 4.2 Presence rules

- Every field is always present; `diagnostics` may be an empty sequence;
  `redaction` is always present and `redacted == (count > 0)`.
- **Usage-class failures (exit 1) never produce an envelope**: unknown
  commands, unknown arguments, missing arguments, invalid `--format`,
  `--apply` without a prior plan, and so on are rejected before command
  execution; stdout carries no bytes and stderr carries diagnostics.
  Envelopes therefore carry `exit_class` in {success, data, limit,
  precondition, internal} on the wire; `usage` appears only as the process
  exit code. The closed set still contains all six values (for the Go CLI
  and future versions, identically).
- **Interruption (SIGINT/SIGTERM) never produces an envelope**: after
  interruption, stdout receives no further bytes (Section 5.4).
- Command-level payload records carry their own `schema` as the first
  field (`cli.inspect@1`, etc.), consistent with the fixed-field
  discipline.

### 4.3 Decoder revalidation (implemented in M2)

The `core.cli-output@1` typed decoder revalidates cross-constraints:

- `command` is in the closed set; `exit_class` is in the closed set;
- `product_version` is shaped like a semantic version
  (`MAJOR.MINOR.PATCH` with an optional `-prerelease` suffix per SemVer
  2.0; no leading zeros in numeric segments; no build metadata);
- `redaction.redacted == (count > 0)`;
- the payload's schema matches `command` (inspect → `cli.inspect@1`,
  query → the corresponding query-result contract, ...); unknown or
  mismatched schemas are rejected;
- every `diagnostics` item strictly decodes as `core.diagnostic@1`
  (codes validated under `ErrorCodeRegistry::v7()`);
- `ProtocolLimits` apply throughout
  (`consema-rs/consema-protocol/src/limits.rs`).

### 4.4 Normative example (canonical JSON bytes)

`consema inspect app.conf --json` (success: `app.conf` is a 43-byte file
whose first line is `[section]`, no `--profile` given):

```text
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.cli-output@1"}},{"key":"command","value":{"type":"String","value":"inspect"}},{"key":"exit_class","value":{"type":"String","value":"success"}},{"key":"product_version","value":{"type":"String","value":"0.12.0"}},{"key":"payload","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.inspect@1"}},{"key":"path","value":{"type":"String","value":"app.conf"}},{"key":"bytes","value":{"type":"Object","entries":[{"key":"size","value":{"type":"Integer","value":"43"}},{"key":"digest","value":{"type":"Object","entries":[{"key":"algorithm","value":{"type":"String","value":"sha256"}},{"key":"hex","value":{"type":"String","value":"2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"}}]}}]}},{"key":"bom","value":{"type":"Null"}},{"key":"symlink","value":{"type":"Boolean","value":false}},{"key":"markers","value":{"type":"Sequence","items":[{"type":"String","value":"[section]"}]}},{"key":"candidates","value":{"type":"Sequence","items":[{"type":"Object","entries":[{"key":"profile","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"ini.portable"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"reason","value":{"type":"String","value":"leading [section] line"}}]}]}},{"key":"ambiguous","value":{"type":"Boolean","value":false}},{"key":"ambiguity_reasons","value":{"type":"Sequence","items":[]}},{"key":"parse","value":{"type":"Null"}}]}},{"key":"diagnostics","value":{"type":"Sequence","items":[]}},{"key":"redaction","value":{"type":"Object","entries":[{"key":"redacted","value":{"type":"Boolean","value":false}},{"key":"count","value":{"type":"Integer","value":"0"}}]}}]}}
```

These bytes are pinned by the `consema.cli.conformance@1` vectors (Section
16); under `--json` the output line is followed by one LF.

## 5. Exit-code classification (v1 candidate freeze)

### 5.1 Classification table

The exit code expresses "whether the operation produced a complete
result", **not the health of the data** (implementation plan §2.2). The
classification function is a pure function (an exhaustive mapping from
error objects to exit classes, implemented in consema-protocol in M2,
vector-testable; the bin only applies the mapping).

| Class | Code | Trigger (stable mapping; no free interpretation) |
|---|---|---|
| success | 0 | The command completed and produced its complete result — **including** Recovered-status reports, ambiguity-fact reports, and unauthorized-loss reports (the report itself is the result); also including `plan` producing a complete manifest that contains per-file `failed` entries (the manifest is the complete result; per-file failures are its content, never disguised success) |
| usage | 1 | argument/syntax errors, unknown command, unknown-argument or abbreviation guessing rejected, `--format` missing or invalid, parse-class commands without `--profile`/`--format`, `--apply` without a prior plan, invalid `--redact-keys` pattern |
| data | 2 | `FatalFormationFailure` (including `core.source.invalid-utf8@1` and the other fatal diagnostics), encoding source-contract conflicts, an operation requiring an explicit choice the user did not give (unresolvable ambiguity), request/plan files failing strict decode (non-ResourceLimit class, `cli.data.invalid-request@1`), input-file read failures (`cli.data.io@1`) |
| limit | 3 | any resource limit: `ParseLimits`/`ProtocolLimits`/`SourcePatchLimits` and other SDK limits, CLI-layer file-size limits (Section 12), batch file-count limits, manifest-size limits, and decode `ResourceLimit` |
| precondition | 4 | stale base digest, original-bytes precondition mismatch (`core.source.patch-base-mismatch@1`/`core.source.patch-original-mismatch@1`), edit conflicts (`core.edit.precondition-failed@1` and the edit conflict family), permission/disk failures, read-only targets, symlink-policy rejection, items not continuable after `apply` interruption, SIGINT/SIGTERM |
| internal | 5 | unclassified internal error (bug; the diagnostic template must include the command name, the file involved, and the diagnostic code) |

### 5.2 Error-family → code mapping rules

- `cli.usage.*` → 1; `cli.data.*` and `cli.detection.ambiguous@1` → 2;
  `cli.limit.*` → 3; `cli.write.*` and `cli.interrupted.signal@1` → 4;
  `cli.internal.unclassified@1` → 5 (Section 13 error table).
- Existing format-layer and core-layer error families: any
  `*resource-limit@1` (core or format-local) → 3; edit/patch precondition
  families (`core.edit.*` conflicts, `core.source.patch-*-mismatch@1`)
  → 4; `core.protocol.*` decode failures → 2 (except
  `core.protocol.resource-limit@1` → 3); `FatalFormationFailure`
  diagnostics (`core.source.*`) → 2. The CLI passes format-layer codes
  through unchanged (implementation plan §2.3).
- `consema inspect` exits 0 on a Recovered file (the report is complete);
  `consema query` exits 2 on input that cannot form a Complete document.
- **apply per-file outcomes**: any `failed` or `skipped-stale` file
  → exit 4 (regardless of that file's failure_code, including a per-file
  limit — file-level failures are uniformly treated as unfulfilled write
  preconditions); all `completed` → 0. CLI-layer/transport-level limits
  (e.g. an oversized manifest) → 3.
- **plan per-file failures do not change plan's exit code**: `plan`
  always produces a complete manifest (per-file `failed` is manifest
  content); plan's exit code is determined only by CLI-layer errors
  (1/2/3/4/5).

### 5.3 Reserved-range policy

- The classification set is closed at {0, 1, 2, 3, 4, 5}; **6-255 are all
  reserved** and v1 never emits them. Any addition or redefinition requires
  a new RFC or a new contract version; the meaning of an emitted code may
  never change in a patch.
- Scripts must treat any unrecognized exit code as failure and must hold no
  expectations for codes above 5.
- Changing a frozen meaning breaks the v1-candidate freeze (roadmap §15.6「API 与产品门禁」).

### 5.4 User interruption

SIGINT (Ctrl+C) and SIGTERM trigger graceful shutdown:

- `apply`/`edit --write`: the manifest is written first per the ordering of
  Section 9.3 (the in-flight file stays `pending`), then the process exits
  with code 4 and `cli.interrupted.signal@1` on stderr.
- Other commands: no further bytes are written to stdout (including the
  envelope); `cli.interrupted.signal@1` goes to stderr; exit code 4.
- The shell convention code 130 is not adopted: 130 would break the closed
  0-5 classification (Section 17, rejected alternatives).
- The re-run recovery semantics of `apply` are in Section 9.4.
- **The signal-handling seam (std-only, `unsafe` forbidden)**: the binary
  is std-only with `unsafe_code = forbid` (workspace lint), so a real OS
  signal handler cannot be installed; on such platforms the CLI exposes
  two documented environment-variable injection points as the
  deterministic stand-in for OS signals, scoped to the `apply` command
  only and intended for testing/CI use:
  `CONSEMA_APPLY_INTERRUPT_AFTER=<n>` (0-based file index) fires the
  graceful-shutdown sequence at the exact code point a SIGINT/SIGTERM
  would be handled — after the in-flight file's pending manifest
  (Section 9.3 step 3) and before its target write (step 4) — and
  `CONSEMA_APPLY_WRITE_FAILURE=permission|io` fails the first atomic
  target write with the named `cli.write.*` error. These two variables
  are the CLI's only environment reads (Section 2.2, Section 15); they
  are documented here and in `--help`; an absent, malformed, or
  out-of-range value disables the injection, and no other command reads
  the environment.

## 6. Command-level payload records

### 6.1 Overview

| Command | Envelope payload (schema first field) | Notes |
|---|---|---|
| inspect | `cli.inspect@1` | file facts + detection facts + optional parse facts (Section 7) |
| capabilities | `cli.capabilities@1` | capability inventory (all data derived from facade types; never redeclared) |
| query | existing query-result record | `core.query-result@1`, or `core.ini-query-result@1`/`core.java-properties-query-result@1`/`core.yaml-query-result@1`/`core.graph-query-result@1` (by domain) |
| project | `core.projection-result@1` record | its `report`/`provenance` fields already embed the report and provenance (protocol projection.rs); no wrapper needed |
| materialize | `core.materialization-result@2` record | Complete embeds `core.source-snapshot@2`; Failed carries failure/report/analyzed_input_paths |
| convert | `cli.convert@1` | `{ schema, report: core.conversion-report@1, target: core.source-snapshot@2 }` |
| edit | `cli.edit@1` | `{ schema, plan: core.edit-plan@1, change_set: core.change-set@1, committed: Boolean }`; dry-run by default (`committed=false`), `true` under `--write` |
| plan | `core.batch-plan@1` record | embedded in the envelope; `--output` writes the same record (Section 8) |
| apply | `core.batch-result@1` record | embedded in the envelope; the result manifest is the same record (Section 9) |
| conformance | `cli.conformance@1` | embedded self-check subset report (Section 16.4) |
| explain | `cli.explain@1` | contract/error-code/profile/capability record |

All embedded existing records keep their original contract definitions
unchanged; this RFC does not redefine their fields. The CLI only assembles
them.

### 6.2 CLI-local records (not registered; envelope payloads only)

The following records freeze their fixed fields in this RFC and are pinned
by the `consema.cli.conformance@1` vectors, but **do not enter the
`ContractRegistry`**: they may appear only as `core.cli-output@1` payloads
and are not individually addressable or transferable; if future
addressability is needed, a new contract is registered in a later
semantic-model version (Section 14).

```text
cli.capabilities@1:
  schema:       "cli.capabilities@1"
  families:     [{id, version}]          the 8 FormatFamilyIds (consema-core)
  profiles:     [{id, version}]          facade ProfileId inventory (ini.portable,
                                         java-properties.reader, xml.1.0-safe,
                                         plist.xml, hcl.native, etc., all from
                                         existing constants)
  query_domains: [{id, version}]         QueryDomain constructor inventory
  operations:   [core.format-operation-registry@1 records]  per-Profile operation
                                         registries
  error_codes:  [String]                 every ErrorCodeRegistry::v7() code
                                         (strictly sorted)
```

```text
cli.explain@1:
  schema:  "cli.explain@1"
  kind:    "contract" | "error-code" | "profile" | "capability"
  id:      String
  version: Integer(u32)
  record:  Object
```

The fixed fields of `record` are frozen per `kind`: contract →
`{id, version, stability: "Stable"|"Transport"}`; error-code →
`{code, category, introduced, description}` (the `ErrorCodeDescriptor`
fields); profile → the `core.profile-descriptor@1` record; capability →
the `core.capability-declaration@1` record. An unknown `kind` is rejected
by the decoder.

```text
cli.conformance@1:
  schema: "cli.conformance@1"
  suite:  String   "consema.cli.conformance@1"
  passed: [String]
  failed: [{id: String, message: String}]
```

```text
cli.convert@1:
  schema: "cli.convert@1"
  report: core.conversion-report@1 record
  target: core.source-snapshot@2 record
```

```text
cli.edit@1:
  schema:     "cli.edit@1"
  plan:       core.edit-plan@1 record
  change_set: core.change-set@1 record
  committed:  Boolean
```

Human and machine output draw from the same facade call (implementation
plan §2.4, §11 item 2); the machine-output byte-equality gate (the CLI
`--json` envelope == the envelope constructed SDK-side under the same
redaction settings) is asserted by e2e tests from milestone M5 onward
(implementation plan §10).

## 7. Detection facts and ambiguity semantics

### 7.1 Fact inventory

`consema inspect` outputs a fact inventory (`cli.inspect@1`) for the input
file, every item deterministically marked; it **never emits a single "this
is X format" conclusion** (hard gate 2; roadmap §14.11「`0.12.0`：Rust 产品集成」;
implementation plan §3.2).

```text
cli.inspect@1:
  schema:           "cli.inspect@1"
  path:             String (user-supplied spelling, verbatim)
  bytes:            { size: Integer(u64), digest: {algorithm:"sha256", hex} }
  bom:              null | "Utf8" | "Utf16Le" | "Utf16Be" (BOM detection fact;
                    no codepage guessing)
  symlink:          Boolean (symlink/junction fact, for the write policy)
  markers:          [String] (signature facts determinable from leading bytes,
                    facts only, never conclusions: "bplist00" header, XML
                    declaration/`<?xml`, first non-whitespace `{`/`[`,
                    `[section]` line, `key=value` line, `%YAML`, `a = 1`
                    shape, etc.; the set and the judgments are pinned by the
                    M9 vectors)
  candidates:       [{ profile: {id, version}, reason: String }] (candidate
                    set derived from markers, each with a reason; an empty
                    array means no candidate)
  ambiguous:        Boolean (candidate set > 1)
  ambiguity_reasons:[String]
  parse:            null | cli.parse-facts@1 (only when --profile is explicit)
```

```text
cli.parse-facts@1 (nested, CLI-local):
  schema:           "cli.parse-facts@1"
  profile:          {id, version}
  formation_status: "Complete" | "Recovered"
  diagnostics:      [core.diagnostic@1]
  structure_counts: Object<String, Integer> (format-owned stable-key
                    structure counts; keys and values pinned per format by
                    the M9 vectors)
```

### 7.2 Mandatory rules

1. Extension, magic, and BOM are facts only; none selects a Profile,
   representation, or encoding (plist precedent: CHANGELOG 0.10.0).
2. Any command that needs parsing requires an explicit `--profile` (or
   `--format`): absence is a usage error (exit 1), never "try and see"; no
   "try every dialect" automatic attempts exist (INI precedent:
   IMPLEMENTATION.md——行号可能漂移，以语义句为锚).
3. On ambiguity, parse-class operations fail (exit 2,
   `cli.detection.ambiguous@1`) and stderr lists the candidates, reasons,
   and usage hints; `consema inspect` itself reports ambiguity
   successfully (exit 0, the report is the result).
4. Detection facts carry no execution authorization: detection never
   parses, never opens anything beyond the file, and has no side effects
   (roadmap §19.2).
5. Candidate-marker collisions (INI vs Properties, JSON vs JSON5, XML vs
   plist.xml, TOML table vs INI section) produce a first-class
   `ambiguous: true` result and are never silently resolved (the
   implementation-plan §3.2 matrix is pinned by the M9 vectors).

## 8. `core.batch-plan@1`

### 8.1 Semantics

`consema plan` is **read-only**: per file, parse → `EditTransaction`
dry_run → aggregate manifest. The plan manifest is an artifact, not a file
write authorization (IMPLEMENTATION.md——行号可能漂移，以语义句为锚; roadmap §10「产品级 CLI」); dry-run and the future commit must produce identical replacements
and target digest (SECURITY.md——行号可能漂移，以语义句为锚). `plan` never writes any target
file (the manifest file may be written only via `--output`, and only to
stdout or that path).

### 8.2 Fixed fields

```text
core.batch-plan@1 (Stable, dual transport):
  schema           String   "core.batch-plan@1"
  product_version  String
  command          String   "plan"
  files            [FileEntry]
```

```text
FileEntry (in command-line argument order):
  path:          String (verbatim spelling)
  status:        "planned" | "failed"
  profile:       {id, version} | null                   only when planned
  source_digest: {algorithm:"sha256", hex} | null       only when planned;
                  == source_patch.base_digest
  operations:    [{operation: {id, version}, summary: Object<String,String>}]
                 | null                                  only when planned
                 (same shape as the core.edit-plan@1 operations records)
  source_patch:  core.source-patch@2 record | null      only when planned
                 (carries base_digest, target_digest, encoding, ordered
                  replacements, redact_original/redact_replacement,
                  metadata)
  failure_code:  String | null                           only when failed
  diagnostics:   [core.diagnostic@1] | null              only when failed
```

Presence rules: when `status` is `planned`, profile/source_digest/
operations/source_patch are all present and failure_code/diagnostics are
null; when `status` is `failed`, the converse holds. The decoder
revalidates: `source_digest == source_patch.base_digest`; `source_patch`
strictly decodes as `core.source-patch@2` (revalidating digest
representation, encoding facts, replacement order/overlap/original-bytes
lengths); replacement ordering and target-digest semantics follow the
`core.source-patch@2` contract (RFC 0011 Section 5). One failing file does
**not fail the batch** (the other files remain `planned`).

### 8.3 File output and input

- `consema plan <files...> [--output <path>]`: the manifest defaults to
  stdout (under `--json`, that is the envelope payload line); with
  `--output`, it is written to that path (the same `core.batch-plan@1`
  record, without envelope wrapping).
- `consema apply <plan-file> [--output <result-path>]`: `plan-file` is a
  manifest previously produced by `plan` (strictly decoded; naked
  operations and non-plan files are rejected); the result manifest defaults
  to `{plan-file}.result.json` (e.g. `batch.plan.json` →
  `batch.plan.json.result.json`), overridden by `--output`.
- The on-disk plan manifest is **never redacted** (Section 11.4: redaction
  never touches patch byte preconditions).

### 8.4 Normative example (fixed-field notation; the on-wire form is the
canonical tagged JSON/PVCE of exactly these fields in this order)

```text
core.batch-plan@1:
  schema:          "core.batch-plan@1"
  product_version: "0.12.0"
  command:         "plan"
  files: [{
    path: "app.conf",
    status: "planned",
    profile: {id: "ini.portable", version: 1},
    source_digest: {algorithm: "sha256",
                    hex: "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"},
    operations: [{
      operation: {id: "ini.edit.set-entry-value", version: 1},
      summary: {name: "password"}
    }],
    source_patch: {
      schema: "core.source-patch@2",
      base_digest: {algorithm: "sha256",
                    hex: "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"},
      target_digest: {algorithm: "sha256",
                      hex: "9cf4e2b5d1f0c6a3b8e7d2f0a4c6b8e1f3a5c7d9b0e2f4a6c8d0b1e3f5a7c9d2"},
      encoding: {schema: "core.source-encoding@1", kind: "Utf8", windows_code_page: null},
      replacements: [{
        old_start: 16, old_end: 19,
        original: {"type":"Bytes","hex":"6f6c64"},          ← true bytes (precondition facts)
        replacement: {"type":"Bytes","hex":"6e6577"},
        redact_original: true, redact_replacement: true
      }],
      metadata: {}
    },
    failure_code: null,
    diagnostics: null
  }]
```

## 9. `core.batch-result@1` and the apply state machine

### 9.1 Semantics

`consema apply` is the **only** batch write command (`edit --write` reuses
the same engine): it consumes `core.batch-plan@1` and, per file, executes
"revalidate → atomic write → read-back target-digest verification",
producing `core.batch-result@1`. `apply` performs no naked operations
outside the manifest (roadmap §10「产品级 CLI」).

### 9.2 Fixed fields

```text
core.batch-result@1 (Stable, dual transport):
  schema           String   "core.batch-result@1"
  product_version  String
  command          String   "apply"
  files            [ResultEntry] (same order as the input plan's files)
```

```text
ResultEntry:
  path:          String
  status:        "completed" | "failed" | "pending" | "skipped-stale"
  failure_code:  String | null      only when failed / skipped-stale
  target_digest: {algorithm:"sha256", hex} | null      only when completed
  redacted:      Boolean (this file's edit operations contain at least one
                 key name matching a redaction pattern; true bytes on disk
                 are unchanged)
```

Presence rules: `completed` → target_digest present and failure_code null;
`failed`/`skipped-stale` → failure_code present and target_digest null;
`pending` → both null. The decoder revalidates: the status set, per-status
field presence, and the always-present `redacted`. Legal state-machine
transitions are in Section 9.3 (the decoder validates snapshot-internal
consistency; transition legality is pinned by the M9 vectors with positive
and negative cases).

### 9.3 Pre-write revalidation and interruption-recovery ordering

The per-file processing order **must** be (risk point R-5; pinned by
tests):

```text
1. re-read the file, recompute the digest, compare against the plan's
   source_digest                              ← stale → skipped-stale
     (failure_code = core.source.patch-base-mismatch@1), no write at all
2. verify each replacement's original-bytes precondition
   (SourcePatch semantics; failure_code = core.source.patch-original-mismatch@1)
3. mark this file pending and write the manifest (atomic replacement,
   Section 10 fsio)
4. atomically write the target file (Section 10)
5. read back and verify the target digest (mismatch → failure_code =
   core.source.patch-target-mismatch@1 plus the cli.write.io@1 environment
   diagnostic; the file has been replaced and is not rolled back — the
   fact that the true bytes are damaged must be recorded truthfully, never
   disguised as success)
6. mark this file completed and write the manifest (failed on failure)
```

At the end of `apply`, the read-back verification concludes: exit 0 only
when every `completed` file's bytes match its `target_digest`; any
`failed`/`skipped-stale` → exit 4 (Section 5.2). `pending` appears only in
manifests written by interruption/crash; a completed run's manifest
contains no `pending`.

### 9.4 Interruption recovery (re-run semantics)

After a crash/interruption, re-run `consema apply <plan-file>` (the same
plan); per file, branch on the **current disk bytes**:

```text
current digest == source_digest  → untouched: execute the full flow again
                                   (Section 9.3)
current digest == target_digest  → already effective: mark completed,
                                   skip (no rewrite)
any other digest                 → skipped-stale (exit 4)
```

- "completed (digest matches) skipped, failed re-reported, pending
  redone" follows from this three-way rule: a crash before the write
  (pending was written first) leaves the file at source_digest → redo; a
  crash after the write but before the completed mark leaves the file at
  target_digest → mark completed and skip; an external concurrent
  modification → the third branch, skipped-stale.
- There is no cross-process file lock: digest precondition revalidation is
  the only concurrency defense (R-10; implementation plan §4.1 makes no
  cross-filesystem atomicity claim). When two `apply` runs write the same
  file concurrently, the later one becomes skipped-stale because the
  digest no longer matches.
- Interruption exits 4 (Section 5.4); after a successful re-run with all
  `completed`, exit 0.
- The interruption and write-failure injection points of Section 5.4
  (`CONSEMA_APPLY_INTERRUPT_AFTER`, `CONSEMA_APPLY_WRITE_FAILURE`) are the
  deterministic, testing/CI-only stand-in for OS signals on platforms
  where the std-only binary cannot install a signal handler (Section 5.4).
  They exercise exactly the recovery paths above — pending-left-behind,
  failed-file re-report, completed-file skip — and must never change the
  three-way rule itself.

### 9.5 Normative example (ResultEntry)

```text
{
  path: "app.conf",
  status: "completed",
  failure_code: null,
  target_digest: {algorithm: "sha256",
                  hex: "9cf4e2b5d1f0c6a3b8e7d2f0a4c6b8e1f3a5c7d9b0e2f4a6c8d0b1e3f5a7c9d2"},
  redacted: true
}
```

## 10. fsio write policy

- **Temporary files**: a unique temporary file
  `{name}.consema-{pid}-{nonce}.tmp` is created in the target's directory
  (pid/nonce appear only in the temporary file name, never in any output
  record, Section 3.3); it is created with restricted permissions (POSIX
  0600); residue cleanup runs via Drop/exit hooks, and on interruption the
  manifest is written first (Section 9.3).
- **Atomic replacement**: write rendered bytes → flush → atomic replacement
  per OS semantics (POSIX `rename`; Windows `std::fs::rename`
  REPLACE_EXISTING semantics) → read back and verify the target digest.
- **Permissions/ownership**: before replacement, the target file's existing
  permissions/ownership (when the OS supports it) are copied to the
  temporary file; Windows read-only attribute and ACL behavior is measured
  during implementation and recorded; full cross-platform verification is
  the 0.13.0 gate (roadmap §15.4「安全门禁」), and **0.12.0 must work on
  Windows** (R-3).
- **Symlink policy**: write paths reject symlink/junction targets by
  default (`cli.write.symlink-policy@1`, exit 4); `--follow-symlinks`
  authorizes explicitly; `inspect` reports the symlink fact (Section 7.1).
- **Newline and encoding policy**: the CLI never transcodes and never
  rewrites newlines — raw bytes enter the `SourceSnapshot` and the raw
  rendered bytes are written (`Document::render()` is byte-exact,
  IMPLEMENTATION.md——行号可能漂移，以语义句为锚); UTF-16/ISO-8859-1 files pass through
  unchanged per their encoding facts (R-11).
- **Read-only targets**: replacement rejects read-only targets
  (`cli.write.read-only@1`); a target that is a directory →
  `cli.write.target-is-directory@1`; permission denial →
  `cli.write.permission@1`; other I/O failures (e.g. disk full) →
  `cli.write.io@1`. All exit 4.
- **No cross-filesystem multi-file atomicity is claimed** (Section 2.2):
  fsio promises only single-file atomic replacement; `apply`'s "batch
  atomicity" is the manifest state machine's recoverability (Section 9.4).
- **Temporary-file races**: same directory + unique nonce + exclusive
  creation; the only concurrency defense is digest revalidation
  (Section 9.4).

## 11. Secret redaction contract

### 11.1 Scope

Redaction is **presentation-only** (roadmap §10「产品级 CLI」; §19.2「无副作用安全边界」;
SECURITY.md——行号可能漂移，以语义句为锚): it affects only stderr diagnostics, human output, and
stdout envelope presentation; it **never removes the byte preconditions
required to apply a SourcePatch** (hard gate 3). Redaction results are
reproducible and testable (vectors + hardening).

### 11.2 Detection (frozen v1 list)

- Key-name pattern set (case-insensitive regex, matched whole or as a
  substring of key names):
  `(?i)(password|passwd|secret|token|api[_-]?key|private[_-]?key|access[_-]?key|credential|auth)`.
- `--redact-keys <glob>` appends key names explicitly; an invalid pattern
  is a usage error (exit 1, `cli.usage.redaction-pattern@1`).
- Value-shape inference is off by default (to prevent false positives); v1
  provides no switch to enable it.
- False-positive direction: redact more rather than miss a secret
  (conservative default).

### 11.3 Placeholder and facts

- In machine output, a hit value is replaced by the string `"$REDACTED$"`
  (a value that is literally `"$REDACTED$"` is indistinguishable — an
  accepted v1 presentation-layer limitation; `--show-secrets` reveals the
  truth).
- The envelope `redaction` record: `{redacted: Boolean, count: Integer(u64)}`;
  `redacted == (count > 0)` (decoder-revalidated); `count` is the number of
  values replaced with `$REDACTED$` in this output.
- The per-file `redacted: Boolean` of batch-result (Section 9.2): the
  file's edit operations contain at least one key name matching a
  redaction pattern.

### 11.4 Sole opt-out and on-disk boundary

- `--show-secrets` is the **sole** opt-out and affects only the
  presentation layer (stderr/human output/stdout envelope).
- **On-disk plan/result manifests are never redacted**: the manifest is
  `apply`'s input and recovery contract, and its `original`/`replacement`
  bytes are precondition facts (Sections 8.3, 9.2); `apply` validation and
  writing always use the true bytes. Assertion: patch application bytes
  are unchanged by any redaction setting (M6 acceptance gate).
- `SourcePatch`'s `redact_original`/`redact_replacement` are existing
  SDK-layer markers, independent of the CLI presentation-layer redaction;
  neither changes the precondition bytes.

## 12. Resource limits

CLI-layer budgets (frozen defaults; exceeding one is a limit-class error,
exit 3, **never truncated disguised success**; R-9; roadmap §3.4):

| Limit | Default | Argument | Code |
|---|---|---|---|
| per-file read cap | 64 MiB (matching `ProtocolLimits::default().max_bytes`) | `--max-bytes` | `cli.limit.file-size@1` |
| plan/apply batch file-count cap | 1000 | `--max-files` | `cli.limit.batch-count@1` |
| plan-manifest / request-input size cap | 64 MiB (transport via `ProtocolLimits`) | `--max-bytes` also applies | `cli.limit.manifest-size@1` |

SDK-layer limits (`ParseLimits`/`ProtocolLimits`/`SourcePatchLimits`, etc.)
keep applying and are reported by the existing codes
(`core.parse.resource-limit@1` etc. → exit 3); the CLI passes them through
unchanged. A per-file limit failure in `apply` is recorded as that file's
`failed` → exit 4 (Section 5.2).

## 13. Error algebra and registration (semantic-model v7)

### 13.1 The `cli.*` error family (frozen by this RFC, 20 codes, strictly
sorted)

```text
cli.data.invalid-request@1        Encoding   request/plan file fails strict decode
                                             (non-ResourceLimit)
cli.data.io@1                     Encoding   input-file read failure (missing/
                                             unreadable/invalid path)
cli.detection.ambiguous@1         Semantic   ambiguity unresolvable (parse-class ops)
cli.internal.unclassified@1       Semantic   unclassified internal error
cli.interrupted.signal@1          Semantic   user interruption (SIGINT/SIGTERM)
cli.limit.batch-count@1           Resource   batch file-count limit
cli.limit.file-size@1             Resource   CLI-layer file-read cap
cli.limit.manifest-size@1         Resource   manifest/request-input size cap
cli.usage.invalid-argument@1      Syntax     invalid value for a known argument
cli.usage.invalid-format@1        Syntax     --format missing or invalid
cli.usage.missing-plan@1          Syntax     --apply without a prior plan
cli.usage.missing-required@1      Syntax     parse-class commands missing
                                             --profile and other required arguments
cli.usage.redaction-pattern@1     Syntax     invalid --redact-keys pattern
cli.usage.unknown-argument@1      Syntax     unknown argument / abbreviation
                                             guessing rejected
cli.usage.unknown-command@1       Syntax     unknown command
cli.write.io@1                    Edit       write I/O failure (disk full, etc.)
cli.write.permission@1            Edit       permission denied
cli.write.read-only@1             Edit       read-only target
cli.write.symlink-policy@1        Edit       symlink/junction policy rejection
cli.write.target-is-directory@1   Edit       target is a directory
```

The class mapping is in Section 5.2. Format-layer and core-layer
diagnostics continue to use the existing 166 codes plus format-local code
constants, passed through unchanged by the CLI (implementation plan §2.3);
`cli.*` covers only CLI-owned errors and never duplicates existing codes
(RFC 0011 Section 10 discipline).

### 13.2 v7 registration increments (additive)

- `ContractRegistry::v7()`: the 38 v1-v6 records stay exactly unchanged;
  three records are appended (all `Stable`):

```text
core.cli-output@1
core.batch-plan@1
core.batch-result@1
```

- `ErrorCodeRegistry::v7()`: the 166 v6 codes stay exactly unchanged; the
  20 codes of Section 13.1 are appended (186 total; 0.13.0 errata: the
  audit-F3 fix additionally registered `json.projection.incomplete-document@1`
  for the json Recovered-document gate, so the live v7 registry holds 187
  codes — the frozen Section 13.1 list is unchanged).
- `RegistryManifest::v7()`; `current()` points to v7 (precedent:
  registry_manifest.rs).
- Old registries reject every new contract and code (RFC 0011 Section 10);
  the v1-v6 frozen-assertion tests are reused (implementation plan M2
  acceptance gate).
- Command-level payload records (Section 6.2) are **not registered**; the
  `cli.*` codes are addressable within the `cli.*` family registry
  (`explain` can interpret them).
- The RFC 0014 reservation that "`core.hcl-query-result@1` is left for a
  later semantic-model version" does not conflict with v7: CLI payloads
  arrive in v7 first, and format-level wire contracts keep their own RFC
  schedules (implementation plan §1.2).

## 14. Versioning and migration

- Once `@1` payloads are frozen, their canonical JSON and PVCE bytes are
  byte-for-byte immutable (Section 3.1); dispatch keys on the exact
  `(id, version)` pair (RFC 0011 Section 11).
- Registering `@2` never reinterprets `@1` (RFC 0011 Section 1). A `@2`
  (or later) payload may: extend the field set (appending after the
  existing fields in canonical order), add closed-set enumeration values,
  relax or tighten presence rules, or swap embedded sub-contract versions;
  it must **not** change the meaning of `@1` fields or add fields under the
  old schema (an old decoder must reject a `@2` payload unambiguously —
  guaranteed naturally by strict exact-fields decoding).
- The CLI and the SDK always stay on the same semantic entry: CLI machine
  output = SDK protocol encoding + deterministic presentation transforms
  (redaction/indentation); the machine-output byte-equality gate is a
  standing test (implementation plan §10, §11 item 2). When a new semantic
  model lands, the CLI emits the correspondingly versioned envelope under
  the new registry; consumers bind by `(id, version)` and never by
  `product_version`.
- Withdrawing old contracts follows the published lifecycle policy
  (roadmap §12.2); registered contracts remain recognized.

## 15. Security boundary

- **No side-effect chain**: the CLI adds no evaluation, import, network,
  or environment-read path (roadmap §10「产品级 CLI」; §19.2「无副作用安全边界」); the core's no-filesystem/no-env/no-network invariant is
  unaffected by the CLI layer (CLI file I/O is an explicit application
  operation, §19.2「无副作用安全边界」). The one exception is the documented
  `apply` testing/CI injection seam (`CONSEMA_APPLY_INTERRUPT_AFTER`,
  `CONSEMA_APPLY_WRITE_FAILURE`, Section 5.4): it reads exactly those two
  variables, exists for no other command, and is documented in `--help`;
  the two variables never change output determinism when unset.
- **Path traversal**: `path` fields are used verbatim as supplied, without
  canonicalization; write paths reject symlink/junction by default
  (Section 10); `apply` re-reads and writes the same path spelling.
- **Temporary-file races**: same directory + unique nonce + restricted
  permissions + exclusive creation; no cross-process lock; digest
  revalidation is the only concurrency defense (Section 9.4; R-10).
- **No half-success for complete artifacts** (roadmap §3.4): Document,
  PortableValue, and batch operations either succeed completely or fail
  explicitly; limits, failures, and interruption never produce disguised
  success (the manifest records per-file status truthfully).
- **No execution of programs embedded in configuration**: no command of
  the CLI executes any code from source-file content, request content, or
  manifest content.

## 16. Conformance integration

### 16.1 Vector suite

The suite `consema.cli.conformance@1` (repository-level:
`conformance/vectors/cli-v1.json` + `consema-rs/consema-conformance/src/cli_v1.rs`,
following the `consema.plist.conformance@1` pattern; total suite count
17 → 18). Case `capability` dispatch:

```text
cli.envelope@1       envelope dual-transport equivalence (canonical JSON ↔
                     PVCE byte equality), fixed fields, presence rules,
                     decoder cross-constraints (command/exit_class/payload
                     consistency, redaction consistency, product_version
                     shape), non-canonical/tampered rejection
cli.exit-code@1      exhaustive exit-classification matrix (every error
                     family → code; Recovered/ambiguity → 0; apply per-file
                     outcomes → 4)
cli.batch-plan@1     batch-plan fixed fields, source_digest == base_digest
                     cross-constraint, per-file planned/failed presence,
                     illegal-transition negatives
cli.batch-result@1   batch-result fixed fields, legal status set,
                     pending/completed/failed/skipped-stale field presence,
                     recovery three-way rule data-driven
cli.redaction@1      $REDACTED$ placeholder, redaction record,
                     presentation-only assertion (patch bytes unchanged),
                     --show-secrets sole opt-out
cli.detection@1      marker → facts/candidates/ambiguity matrix (including
                     marker-collision ambiguity cases: INI vs Properties,
                     JSON vs JSON5, XML vs plist.xml, TOML table vs INI
                     section)
cli.limit@1          file-size/batch-count/manifest-size caps and
                     --max-bytes override
```

The protocol-layer vectors execute library-side in `cli_v1.rs` (v7 type
decode → revalidation → dual-transport comparison; exit classification via
the classification function; state machine via the manifest types),
data-driven (changing an expectation must fail); hardening must not panic
and must not write the wrong target.

### 16.2 Normative examples

The bytes/records of Sections 4.4, 8.4, and 9.5 are the normative forms
pinned by the vectors; the canonical tagged JSON encoding rules follow
`core.portable-value-json@1` (`value_transport.rs`), and the vectors record
the full bytes.

### 16.3 Process-level e2e

`consema-rs/consema/tests/cli_*.rs` launches the binary via
`env!("CARGO_BIN_EXE_consema")`: stdout/stderr separation assertions,
exit-code matrix, full plan→apply flow, failure injection
(stale/conflict/permission/disk/read-only/interruption), and machine-output
byte equality with the SDK encode (Section 3.3; implementation plan §8.3,
§10). Process-level interruption/write-failure injection drives the
documented environment-variable seam of Section 5.4
(`CONSEMA_APPLY_INTERRUPT_AFTER`, `CONSEMA_APPLY_WRITE_FAILURE`; the
recovery semantics are in Section 9.4) — the deterministic stand-in for OS
signals on the std-only binary.

### 16.4 conformance command boundary

`consema conformance` executes the embedded self-check subset in the
release artifact (envelope round-trip, exit classification, redact
self-check — no repository fixtures) and outputs `cli.conformance@1`
(machine) plus a human report (exit 0, or classified by failure count);
the full language-neutral suite stays repository-level
(`cargo test -p consema-conformance`). Release artifacts do not include
`conformance/vectors` (precedent: consema-conformance `publish = false`,
IMPLEMENTATION.md——行号可能漂移，以语义句为锚).

## 17. Rejected alternatives

- **A fully CLI-local schema, not through semantic-model v7**: rejected —
  the Go CLI (0.19.0, roadmap §22.6) must emit the same machine-readable
  output schema; only the established path of fixed-field PortableValue +
  canonical JSON/PVCE dual transport + typed-decoder revalidation can be
  proven by language-neutral vectors (precedent: protocol-v1/v2 dual
  transport equivalence, IMPLEMENTATION.md——行号可能漂移，以语义句为锚; implementation plan
  §2.3). CLI convenience layers (human output, detection-facts display)
  stay local, and the detection-facts semantics (facts-only, ambiguity as a
  first-class result) remain part of the cross-language contract.
- **Adopting clap / tempfile / serde_json dependencies**: rejected — under
  the deny.toml `[sources]` crates.io-pinned policy and the zero-new-
  dependency tradition (plist base64/date self-written precedent), they are
  unacceptable; the argument surface is fixed and narrow (11 commands × few
  sub-arguments), a self-written deterministic parser (~250-350 lines)
  rejects unknown arguments and abbreviation guessing; the pretty-JSON
  indenter is self-written (pure formatting, canonical semantics
  unchanged); fsio is self-written (R-1).
- **Shell convention exit code 130 for SIGINT**: rejected — it would break
  the closed 0-5 classification and the single semantics of "exit code
  expresses whether a complete result was produced"; interruption is frozen
  per Section 5.4 (graceful shutdown writes the manifest first, then exits
  4).
- **Detect then parse automatically ("try every dialect")**: rejected —
  detection returns only confidence facts or ambiguity (hard gate 2);
  parse-class commands require an explicit `--profile`, whose absence is a
  usage error; nothing is guessed silently (roadmap §3.3「默认不猜测」、§14.11「`0.12.0`：Rust 产品集成」).
- **Redacting the on-disk plan manifest too**: rejected — the manifest is
  `apply`'s input contract and its `original`/`replacement` bytes are
  precondition facts; redaction applies only to the presentation layer
  (hard gate 3, Section 11.4).
- **Value-shape inference on by default in redaction**: rejected — false
  positives (normal values redacted) violate "deterministic and
  explainable"; v1 does conservative key-name matching only (Section 11.2;
  R-6 both directions).
- **Multi-file filesystem transactions in apply**: rejected — roadmap §10「产品级 CLI」
  explicitly disclaims them; batch atomicity is the manifest state
  machine's recoverability (Section 9.4).
- **JSON-only machine schema transport**: rejected — both request input and
  machine output require PVCE and strict JSON dual transport (roadmap §10「产品级 CLI」); a single transport would break Go alignment and vector
  equivalence proofs.
- **An envelope for usage errors too**: rejected — usage errors are
  rejected before command execution and have no result to report; an
  envelope would force scripts to parse a "result of no result" (Section
  4.2). Usage appears only as the process exit code.

## 18. Roadmap and plan mapping

- roadmap §10「产品级 CLI」: the 11 commands (Sections 2.1, 6.1),
  read-only/dry-run by default with explicit confirmation arguments
  (hard gate 4; Sections 8.1, 9.1, 10), stdout/stderr/exit code (Sections
  3.3, 5), human and machine dual output with versioned schema (Sections
  4, 6), requests via PVCE or strict JSON input (Section 3.2), batch
  manifests (Sections 8, 9), digest/precondition revalidation before every
  write (Section 9.3), same-directory temporary files and atomic
  replacement (Section 10), no multi-file atomicity claim (Section 10),
  interruption-based determination of completed/failed/not-executed
  (Section 9.4), secret redaction (Section 11), symlink/permission/newline/
  encoding policy (Section 10), no execution of programs embedded in
  configuration (Section 15), convenience choices never become core
  semantic defaults (Section 2.2).
- roadmap §12.3 item 13（RFC-first 范围）: the ten-part RFC kit — motivation
  (Sections 1-2), non-goals (Section 2.2), data model (Sections 4, 6, 8,
  9), state machine (Section 9), error algebra (Sections 5, 13), resource
  limits (Section 12), security (Section 15), versioning (Section 14),
  conformance (Section 16), rejected alternatives (Section 17) — is
  complete.
- roadmap §14.11「`0.12.0`：Rust 产品集成」: all-format registry (Section 6.2),
  auto-detection safety boundary (Section 7), official CLI (Section 1),
  machine-readable CLI protocol (Sections 4-9), per-file atomic write and
  batch manifests (Sections 8-10), secret redaction (Section 11), and the
  five hard gates (Section 2.3 mapping).
- roadmap §15.6「API 与产品门禁」: exit code, stdout/stderr, and machine
  schema frozen as v1 candidate (Sections 4, 5); patch/apply covered by
  interruption, conflict, permission, and disk-error tests (Section 16.3;
  implementation plan M8).
- roadmap §22.6「产品」: dry-run by default with write
  preconditions (hard gate 4; Section 9.3), stable machine-readable output
  schema (Section 4), batch manifests/conflicts/interruption/recovery
  (Sections 8-9).
- implementation plan M2-M10 depend on this RFC: v7 registration (M2,
  Section 13.2), the pure exit-classification function (M2, Section 5),
  envelope and manifest types (M2, Sections 4, 8, 9), fsio (M6, Section
  10), redact (M6, Section 11), plan/apply (M7/M8, Sections 8, 9), vectors
  and hardening (M9, Section 16), documentation and release (M10, Sections
  13.2, 16).

## 19. Acceptance gates (verifiable claims of this RFC)

- The envelope bytes of Section 4.4 and the records of Sections 8.4/9.5
  match the vectors byte-for-byte (changing an expectation must fail);
- the exhaustive exit-classification matrix: every `cli.*` code, every
  existing error family, and every per-file outcome maps to exactly one
  class (Section 5.2);
- the state machine: plan planned/failed → result pending →
  completed/failed, and skipped-stale as terminal; illegal transitions
  (completed → pending, etc.) are rejected by the decoder;
- the recovery three-way rule (Section 9.4) holds under process-level kill
  injection (M8 acceptance gate);
- the redaction matrix: key-name hits/false-positive direction/placeholder/
  redaction record/sole opt-out/patch-bytes-unchanged assertion (M6
  acceptance gate);
- dual-transport equivalence: the three v7 payloads are byte-equivalent
  between canonical JSON and PVCE and round-trip (M2 acceptance gate);
- v1-v6 registry frozen assertions stay green; v7 is 41 contracts / 186
  codes, strictly sorted (M2 acceptance gate; 0.13.0 errata: the audit-F3
  fix registered `json.projection.incomplete-document@1` in v7, 187 codes
  total, pinned by the error_registry test);
- the total suite count reaches 17 → 18 all green (M9/M10).
