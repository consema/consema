# RFC 0020: 1.0 compatibility and support policy v1

- Status: Accepted（2026-08-10 于 0.19.0 接受；路线图 §27 R-20，最晚完成版本
  `0.19.0`；`1.0.0` 发布前强制生效，`1.0.0` 起约束所有发布）
- Date: 2026-08-10
- Scope: the normative 1.0 compatibility and support policy. It freezes,
  effective from `1.0.0` (and governing the `0.x` tail from acceptance), the
  patch/minor/major semantic boundaries, the compatibility surfaces, the
  Rust MSRV window, the Go version window, the TypeScript/Python/Kotlin
  version windows, the supported OS/architecture
  matrix, the security fix policy with response SLA, the previous-minor
  branch support period, the deprecation notice period, the
  contract/Profile retirement process, and the toolchain freeze timing
  (roadmap §21.4's seven mandatory public items + the freeze clause). It
  does **not** define any format-family behavior; family contracts keep
  their own RFCs (0001-0014).
- Depends on: roadmap §12 (版本治理；§12.1 破坏性变更五条、§12.2 契约与产品
  版本正交、§12.3 RFC-first 字段）、§11.4（发布版本关系）、§15（Feature-
  Complete Gate，MSRV 冻结时点）、§16.6/§18.4（缺陷等级）、§19.4（发布
  供应链）、§21.1（Rust API，第 1820 行 MSRV 不进入 patch）、§21.2（Go API）、
  §21.3（稳定承诺）、§21.4（支持周期七必公开项）、§26.4（过早冻结风险）、
  §27（R-20）；RFC 0015 §5.3（exit code 分类冻结）；RFC 0016 §9（Go
  module 与产品 release train 关系）；`SECURITY.md`（资源与安全行为、
  披露渠道与响应 SLA）；`docs/go-implementation-plan.md` §1.3（go.mod
  最低版本冻结）；`docs/fc-manifest-0.13.0.json`（`rust_compiler_msrv`
  冻结记录）；`docs/support-policy.md`（0.1 草案，本文为其契约化版本）
- External behavior references: none. This RFC constrains the already
  frozen public surfaces (Rust crates API, Go module API, TypeScript,
  Python, and Kotlin package APIs, the CLI machine
  protocol of RFC 0015, the semantic-model contract registry, the shared
  conformance vectors) rather than defining new runtime behavior; the
  external contracts are the conformance vectors and the published support
  statements that `1.0.0` consumers rely on

## 1. Decision

Consema commits, publicly, to a single compatibility and support contract
that takes effect at `1.0.0`. Roadmap §21.4 requires seven items to be
public before `1.0.0` — Rust MSRV window, Go version window, supported
OS/architectures, security fix policy, previous-minor branch support
period, deprecation notice period, and the contract/Profile retirement
process — plus the toolchain freeze timing (§21.4, line 1863). Per the
2026-08-11 five-language equal-status decision
(docs/multi-language-implementation-plan.md), the TypeScript, Python, and
Kotlin version windows join the same commitment (Sections 9.3-9.5). This
RFC is the normative statement of all of them, fulfilling roadmap §27 R-20
(due `0.19.0`).

### 1.1 Motivation

- `1.0.0` is the point at which the stable public API, protocol, and
  product promises begin (roadmap §12.1). Users must be able to predict
  which releases may change their builds, their machine outputs, and their
  stored contract identities — and which releases may not.
- The compatibility boundaries of §21.3 (output order, default loss
  policy, format acceptance/recovery) are behavioral contracts that cannot
  be policed by API diffing alone; they must be stated, and they must be
  enforced by the conformance suite (Section 13).
- §12.2 makes contract identity orthogonal to product version: published
  contracts are immutable, and retirement must follow a public lifecycle
  policy. This RFC is that policy.
- §26.4 names the opposite risk — freezing production promises too early.
  This RFC therefore fixes the *rules* now and fixes the *toolchain
  numbers* only at the two freeze points already defined by §21.4
  (Rust Feature-Complete — done at 0.13.0 — and Go RC — pending). The
  TypeScript/Python/Kotlin declared minimums are manifest-embedded and
  CI-verified at pinned versions ("really verified in CI" by construction,
  five-language-ci-design §1.2); their freeze follows the same
  release-train discipline (Section 9.7).

### 1.2 Normative standing

**This RFC is the normative source of the Consema support policy.**
`docs/support-policy.md` is the public summary of it: it carries the same
content in a shorter, outward-facing form, is maintained in lockstep, and
must not contradict this RFC. `SECURITY.md` remains the operational
document for security behavior and disclosure mechanics (SLA, contact,
report requirements); this RFC restates it and makes it part of the
published contract. Where this RFC and any other document disagree, this
RFC wins and the discrepancy must be reported (see Section 15).

### 1.3 §12.3 field mapping

§12.3 requires RFCs to cover motivation, non-goals, data model, state
machine, error algebra, resource limits, security, versioning,
conformance, and rejected alternatives. Mapping for this policy RFC:

| §12.3 field | Where covered |
|---|---|
| Motivation | Section 1 |
| Non-goals | Section 2 |
| Data model | Section 3 (compatibility surfaces) |
| State machine | Section 5 (branch and contract lifecycles) |
| Error algebra | Section 6 |
| Resource limits | Section 7 |
| Security | Section 8 |
| Versioning | Sections 4, 9, 11, 12 |
| Conformance | Section 13 |
| Rejected alternatives | Section 14 |

## 2. Scope and non-goals

### 2.1 Scope

- The patch/minor/major semantic boundaries and the five-point
  breaking-change discipline (Section 4).
- The compatibility surfaces and their change classes (Section 3).
- The branch support lifecycle (latest / previous / security-only / EOL)
  and the contract lifecycle (published / deprecated / retired)
  (Section 5).
- The Rust MSRV window, the Go version window, and the
  TypeScript/Python/Kotlin version windows, including the freeze
  timing (Section 9).
- The supported OS/architecture matrix (Section 9.6).
- The security fix policy, response SLA, and disclosure process
  (Section 8).
- The deprecation notice period and the contract/Profile retirement
  process (Sections 10-11).
- The conformance consequences of compatibility changes (Section 13).

### 2.2 Non-goals

- Per-family acceptance/recovery detail: format acceptance and recovery
  boundaries belong to each family's Profile compatibility and are frozen
  by the family RFCs (0001-0014) and the Profile contracts; this RFC only
  classifies them as compatibility (Section 4.2).
- The CLI machine protocol schemas and exit-code classification: frozen by
  RFC 0015; this RFC only declares their stability class (Section 3).
- The release process and supply-chain checklist: roadmap §19.4 and the
  release checklist own it; this RFC consumes their security artifacts
  (Section 8.5).
- Concrete future toolchain versions: per §21.4, numbers are frozen at the
  Rust Feature-Complete and Go RC freeze points, not pre-written in a
  multi-year policy (Section 9.7).
- The Go module publish path and module topology: RFC 0016 §3 owns them.
- Any new format-family capability, Profile, or contract: those still
  require their own RFC (§12.3).

## 3. Compatibility surfaces (data model)

A change is compatible or breaking only with respect to a surface. Consema
defines five public surfaces, each with a stability class:

| Surface | Contents | Stability class |
|---|---|---|
| Rust public API | `consema` facade and all backend crates' public items | frozen at `1.0.0` (breaking ⇒ major) |
| Go public API | `consema.dev/consema` module public items (RFC 0016) | frozen at `1.0.0` (breaking ⇒ major) |
| TypeScript public API | `@consema/consema` package public items (consema-ts) | frozen at `1.0.0` (breaking ⇒ major) |
| Python public API | `consema` package public items (consema-py) | frozen at `1.0.0` (breaking ⇒ major) |
| Kotlin public API | `dev.consema:consema-kotlin` module public items (consema-kt) | frozen at `1.0.0` (breaking ⇒ major) |
| Machine protocol | RFC 0015 envelope, batch manifests, exit classes, command schemas | frozen as v1 candidates at 0.12.0; stable from `1.0.0` |
| Contract registry | `namespace.contract@N` records, error codes, constructors | published records frozen forever (Section 11) |
| Conformance vectors | `conformance/vectors/` (shared authority, roadmap §17) | versioned; additions additive, corrections only via the §11.3 process |

Class rules:

- **Frozen surface**: no change without the release type the boundary
  requires (Section 4). Behavior changes on a frozen surface are breaking
  even if no signature changes — this is what makes §21.3's behavioral
  boundaries (below) real.
- **Published contract**: immutable identity; change means a new `@N`
  (Section 11).
- **Diagnostic message text**: explicitly improvable in any release;
  stable `code`/`category`/`fields` do not change casually (§21.3,
  line 1846; RFC 0011 registry validation).

> **2026-08-11 revision (yaml dry-run surface boundary recorded)**: on the
> Go public API surface, the yaml family intentionally has no dry-run
> entry point in this window — `PlanEdit` explicitly rejects yaml
> transactions with the registered `core.edit.operation-unsupported@1`
> (RFC 0004 §17; `crates/consema-protocol/src/error_registry.rs:502`).
> The Rust yaml family publishes `dry_run`
> (`crates/consema-yaml/src/edit.rs:554`); the Go-side boundary is a
> deliberate, documented API shape (go-implementation-plan §2.6 G5.5;
> go/edits.go). Adding a Go yaml dry-run surface is a feature for the
> post-1.0.0 window, not a blocker — recorded per the 2026-08-10 P2-2
> judgment (docs/rc-1.0.0-candidate.md §5).

## 4. Version semantics from 1.0.0

From `1.0.0` (§21.3):

### 4.1 patch (`1.0.x`)

bug or security fixes only. A patch release must not:

- change any public API signature, type, or semantics;
- change defined behavior on any surface of Section 3;
- change any published `namespace.contract@N`;
- change output order, default loss policy, or format
  acceptance/recovery boundaries;
- raise the Rust MSRV or any declared minimum version — Go,
  TypeScript, Python, or Kotlin (§21.1, line 1820; Section 9).

### 4.2 minor (`1.x.0`)

backward-compatible additions only: new capabilities, new Profiles, new
contracts, new query domains, new operation registries. Within a minor,
the following are explicitly **compatibility** and therefore cannot be
changed:

- **output order** of any public result (query matches, object entries,
  diagnostics, reports, batch manifests) (§21.3, line 1847);
- **default loss policy** of any projection/materialization/query
  operation (§21.3, line 1848);
- **format acceptance/recovery boundaries** of any published Profile
  (§21.3, line 1849) — including recovered-document capabilities;
- stable diagnostic `code`/`category`/`fields` (message text may improve,
  §21.3, line 1846).

### 4.3 major (`2.0.0` and later)

unavoidable breaking public changes only. A major must deliver, for every
break:

- the breaking-change analysis of Section 4.4 (impact list per surface);
- a migration note in the documented migration-guide form
  (`docs/migration-guide.md`);
- updated conformance vectors reflecting the new behavior (Section 13);
- an explicit statement of which previously-published contracts are
  affected — published contracts are never reinterpreted, so a major may
  only *retire* them, never redefine them (Sections 4.4.3, 11).

### 4.4 Breaking-change discipline

A breaking change — in `0.x` per §12.1, and in any major per §21.3 — must
satisfy all five points:

1. land in a **minor** (`0.x.0`) or major, never in a patch;
2. ship a **migration note**;
3. **never reinterpret** a published `namespace.contract@N`;
4. **update conformance** (positive and negative vectors for old and new
   behavior) in the same release;
5. **list the impact** on Rust API, protocol, and CLI schema explicitly
   (the §12.1 impact inventory).

For behavior that exists only in `0.x` and has no published contract, a
breaking change still requires points 1, 2, 4, 5, and the CHANGELOG must
state the lowest version users can stay on.

### 4.5 0.x tail (until 1.0.0)

The rules above bind from acceptance of this RFC. Between now and
`1.0.0`:

- `0.x.0` remains an architecture gate, not a date label (§12.1); breaking
  changes in `0.x` follow the five points of Section 4.4.
- `0.x.y` is fix-only, with the same patch restrictions as 4.1.
- `-alpha.n` / `-beta.n` / `-rc.n` semantics are unchanged from §12.1:
  only blocking defects, security issues, and documentation errors may
  change an `-rc` candidate.
- The MSRV/declared-minimum disciplines of Section 9 bind now, not only
  at `1.0.0`.

## 5. Lifecycle state machines

### 5.1 Product branch lifecycle

Effective from `1.0.0` (during `0.x` only the latest minor is maintained;
older `0.x` minors are handled per Section 5.3):

```text
latest minor ──(new minor releases)──▶ previous minor
   full support                          security + P0/P1 fixes
   (bug + security + docs)               12 months from the new minor
                                              │
                                              ▼
                                    security-announcements-only
                                            (6 months)
                                              │
                                              ▼
                                             EOL
                              (no fixes; EOL date recorded in
                               CHANGELOG and release notes)
```

- **Latest minor**: full support — bug, security, and documentation
  fixes.
- **Previous minor**: support for 12 months after the new minor's
  release; only security fixes and P0/P1 fixes are accepted; after that it
  enters security-announcements-only for 6 months (advisories and
  mitigation notes, no new patch releases).
- **EOL**: no fixes; the EOL date of each minor is recorded in the
  CHANGELOG and release notes.
- Patch releases are backported only within this window; a fix never
  ships to more than the current and previous minor.

### 5.2 Contract lifecycle

```text
published ──(minor: deprecation notice)──▶ deprecated
  (frozen identity,                        (≥ 1 full minor; behavior
   never reinterpreted)                     and machine output unchanged)
                                                │
              ──────────(next minor/major: retirement record)──────────▶
              retired
              (registry record retained; typed-decoder parse paths
               retained; removed from default capability surface;
               `consema capabilities` annotates the retired state)
```

### 5.3 Transition rules

- No lifecycle transition ever occurs in a patch release.
- Deprecation starts only in a minor, and removal happens no earlier than
  the **next full minor** after the deprecation minor (Section 10).
- A contract reaches `retired` only through a retirement record stating
  the reason, the alternative contract ID, and the last product version
  supporting it (Section 11).
- The branch lifecycle of 5.1 applies to product minors; the contract
  lifecycle of 5.2 applies to contract identities and is orthogonal to it
  (§12.2).

## 6. Error algebra

- The CLI exit classification `{0..5}` (success, usage, data, limit,
  precondition, internal — RFC 0015 §5.1 class names) is frozen by RFC
  0015 §5.3; it is a frozen
  surface from `1.0.0` and never changes meaning.
- Registered error codes are never redefined. Any new code, or any change
  to a code's category/severity/fields, requires a new RFC or a new
  contract version (RFC 0015 §5.3; support-policy §7). Decoding unknown
  codes or category contradictions is a protocol error (RFC 0011).
- In Go, error text is human presentation only and never participates in
  conformance comparison (RFC 0016 §6); the stable surface is the
  registered `Code()` and the machine fields.

## 7. Resource limits

- Resource limits are an execution policy, not an approximation boundary:
  exceeding `ParseLimits`, `DecodeLimits`, `ProtocolLimits`,
  `QueryLimits`, `ProjectionLimits`, `SourceLimits`, `SourcePatchLimits`,
  or `MaterializationLimits` fails the operation — truncation is never
  disguised as success (SECURITY.md, lines 3-14).
- A security fix may never "fix" a limit failure by reporting partial
  success; limit semantics are part of the security boundary
  (SECURITY.md, line 46) and are frozen surface behavior (Section 4.2).
- Limit values and semantics are carried by the contracts that own them
  and change only through contract versioning (Section 11).

## 8. Security fix policy and disclosure

### 8.1 Defect levels

Defect levels follow roadmap §18.4:

```text
P0  data destruction, silent loss, RCE/external access, wrong file
    writes, cross-snapshot mis-edit
P1  panic/crash/hang, wrong completion status, clear semantic
    inconsistency, limit bypass
P2  functional defect with a safe alternative path, non-core performance
    regression, wrong diagnostic location
P3  documentation, usability, unstable message text, low-risk edge cases
```

- **P0/P1**: block the current milestone; `1.0.0` will not ship with
  unresolved P0/P1 (§18.4). Fixes take the fastest path into a patch
  (during `0.x`, the next `0.x.y`; after `1.0.0`, the next `1.x.y` or
  `1.0.x`) and permanently enter the regression corpus
  (`conformance/corpora/`, §15.3).
- **P2**: individually reviewed and recorded per release judgment (never
  lumped into "known issues", §18.4); fixes ship in the next minor, or in
  a patch when the review so decides.
- **P3**: best effort.

### 8.2 Response SLA

The response SLA is the `SECURITY.md` disclosure section, restated as
contract:

| Level | Confirmation | Fix or mitigation |
|---|---|---|
| P0 | 24 hours | 7 days |
| P1 | 72 hours | 14 days |
| P2 | next release window | per-item public judgment |
| P3 | best effort | best effort |

In addition, critical/high findings are bounded by a 90-day outer
disclosure timeline: a fix is released within 90 days of confirmation, or
the disposition is publicly stated.

### 8.3 Disclosure process

- Coordinated disclosure: reports are acknowledged privately before any
  public disclosure; details are never published before a fix is
  available. No bug bounties are offered.
- Channels: the repository's GitHub Security Advisory (private reporting;
  enabled when the repository is public) is the primary channel; the
  direct channel is the maintainer identity recorded in release tags
  (franckcl1989 <franckcl@icloud.com>). Reports should include affected
  versions, the Profile/contract involved, the triggering capability
  contract (e.g. `core.source-snapshot@1`), a minimal reproduction, and
  observed behavior (§19.4, line 1764).
- Supply-chain findings (dependencies, SBOM, signatures, CI) use the same
  channel.
- Fixes must not relax resource-limit or completion-status semantics
  (Section 7; SECURITY.md, line 46).

### 8.4 Security fix support windows

- Before `1.0.0`: security fixes are promised only for the latest stable
  version and its previous minor (current release tag and its
  predecessor); older versions are not promised fixes unless the impact
  analysis justifies a backport (SECURITY.md, line 48).
- From `1.0.0`: the Section 5.1 branch lifecycle applies — security fixes
  for the latest and previous minor, advisories only for the
  security-announcements-only window.

### 8.5 Dependency hygiene

- Standing gates: `Cargo.lock` and exact-lockfile discipline, RustSec
  `cargo audit` (0 known advisories at the 0.13.0 gate), `cargo deny
  check` (unknown registries/Git sources, wildcards, duplicates, and
  license inventory rejected), and the locked license allowlist
  (SECURITY.md, line 38; §19.3).
- Go: dependency audit is part of the release checklist (§19.4); the Go
  module is stdlib-only (go-implementation-plan §1.3), so the third-party
  surface is the Rust side plus the audited upstream conformance corpora.
- Upstream advisory tracking follows §19.3; upstream corpus version
  changes (e.g. toml-test, yaml-test-suite) require a separate audit
  (SECURITY.md, line 30).

## 9. Toolchain support cycle

### 9.1 Rust MSRV window

- **Declared MSRV**: every release declares the exact `rust-version` in
  the manifest. The current value is `1.85` (consema-rs/Cargo.toml:33,
  edition 2024, `unsafe_code = "forbid"`). "1.85" is a current declared
  value, not a multi-year promise; the committed window is the *policy*,
  the number is frozen per Section 9.7.
- **Support window**: all Rust versions from the MSRV through the current
  stable.
- **Bumps**: MSRV increases happen only in minor releases — never in
  patch (`§21.1`, line 1820) — and follow the manifest change record
  (§12); the CHANGELOG states the lowest version users can stay on.
- **Verification**: the CI `msrv` job (runs the full test matrix on the
  declared MSRV) is the sole authority; local `cargo +<msrv>` is
  re-verification only. Code using syntax above the MSRV is blocked by
  this job before merge.
- **Freeze record**: the Rust-Feature-Complete freeze (0.13.0) recorded
  MSRV 1.85 with measured toolchain rustc 1.97.1 in
  `docs/fc-manifest-0.13.0.json` (`rust_compiler_msrv`); the release
  verification baseline runs both current stable and MSRV
  (root CHANGELOG.md:116-119).

### 9.2 Go version window

- **Declared minimum**: `go.mod` declares the minimum Go version; the
  value is `go 1.26`, frozen at 0.14.0 (go-implementation-plan §1.3, per
  §21.2 lines 1825/1831: minimum version follows the public support
  policy and is CI-verified).
- **Support window**: each Go minor release supports the latest two Go
  minor versions at its time of release (the §21.4 placeholder promise,
  now concrete: with `go.mod` at 1.26, releases support Go 1.26 and 1.27
  once 1.27 is stable, and so on).
- **Bumps**: minimum-version increases follow the same discipline as the
  Rust MSRV — minor-only, never in patch, never reinterpreting published
  contracts, with the CHANGELOG noting the lowest stayable version.
- **Verification**: CI runs the module on the declared minimum and on
  current stable (go vet, static analysis, race detector, fuzz per
  §21.2).
- **Freeze record**: the minimum and the verification toolchain are
  formally frozen at the Go RC freeze point (Section 9.7) and recorded in
  the corresponding release manifest. (Current environment fact: go1.26.5
  at 2026-08-07; the oracle's `go 1.22` directive is a legacy of the
  differential-oracle module, not SDK policy — go-implementation-plan
  §0.1.)

### 9.3 TypeScript / Node version window

- **Declared minimum**: `engines.node` declares the minimum Node version;
  the value is `>= 26` (consema-ts/typescript/package.json:9-10),
  CI-verified at the pinned '26.x' (consema-ts ci-typescript.yml,
  setup-node).
- **Support window**: all Node versions from the declared minimum through
  the current stable toolchain. For the three L5 languages the CI-pinned
  version *is* the declared minimum ("really verified in CI" by
  construction, five-language-ci-design §1.2).
- **Bumps**: minimum-version increases follow the same discipline as the
  Rust MSRV — minor-only, never in patch, never reinterpreting published
  contracts, with the CHANGELOG noting the lowest stayable version.
- **Verification**: CI runs the suite on the declared minimum
  (`npm ci` + `npm run check` + `npm test`).
- **Freeze record**: the declared minimum is manifest-embedded and
  CI-verified; the formal freeze follows Section 9.7.

### 9.4 Python version window

- **Declared minimum**: `requires-python` declares the minimum Python
  version; the value is `>= 3.12` (consema-py/python/pyproject.toml:21),
  CI-verified at the pinned '3.12.x' (consema-py ci-python.yml,
  setup-python).
- **Support window**: all Python versions from the declared minimum
  through the current stable toolchain ("really verified in CI" by
  construction, five-language-ci-design §1.2).
- **Bumps**: same discipline as Section 9.3 — minor-only, never in patch,
  never reinterpreting published contracts.
- **Verification**: CI runs compileall + the full pytest suite plus the
  zero-dependency assertion on the declared minimum (ci-python.yml).
- **Freeze record**: the declared minimum is manifest-embedded and
  CI-verified; the formal freeze follows Section 9.7.

### 9.5 Kotlin / JVM version window

- **Declared minimum**: the Gradle build declares Kotlin `2.2.0` on JVM 17
  (consema-kt/kotlin/build.gradle.kts:6-7, 24, `jvmToolchain(17)`),
  CI-verified with Temurin 17 (consema-kt ci-kotlin.yml, setup-java).
- **Support window**: from the declared Kotlin/JVM minimum through the
  current stable toolchain ("really verified in CI" by construction,
  five-language-ci-design §1.2).
- **Bumps**: same discipline as Section 9.3 — minor-only, never in patch,
  never reinterpreting published contracts.
- **Verification**: CI runs `./gradlew --no-daemon test` on the declared
  minimum (ci-kotlin.yml).
- **Freeze record**: the declared minimum is manifest-embedded and
  CI-verified; the formal freeze follows Section 9.7.

### 9.6 Supported OS / architectures

The formally supported matrix is CI-verified on every release (full test
matrix):

| OS | Architecture | CI verification |
|---|---|---|
| Windows (Windows 11 Pro baseline) | x86-64 | windows-latest full matrix |
| Linux | x86-64 | ubuntu-latest full matrix |
| macOS | x86-64 / arm64 | macos-latest full matrix |

- All other platforms/architectures are best-effort: they do not block
  releases, and accepted critical fixes are verified on the three
  supported platforms.
- Release artifacts are verified by `scripts/verify-package-archives.ps1`
  (path safety, checksums, unpacked content, MSRV leg).
- CLI platform-dependent behavior (Windows read-only/ACL, POSIX
  permissions, symlink policy, temp-file permissions) is verified
  per-platform on the supported targets (RFC 0015 §9.6).

### 9.7 Toolchain freeze timing

Per §21.4 (line 1863), concrete toolchain versions are frozen at two
points, not pre-written in this policy:

- **Rust Feature-Complete (0.13.0)**: done. MSRV 1.85 and the measured
  verification toolchain (rustc 1.97.1) are recorded in
  `docs/fc-manifest-0.13.0.json` (`rust_compiler_msrv`).
- **Go RC (`1.0.0-rc` window)**: pending. The Go minimum version and
  verification toolchain are frozen then, per §21.2, and recorded in the
  corresponding release manifest.
- **TypeScript/Python/Kotlin**: the declared minimums are
  manifest-embedded and CI-verified (Sections 9.3-9.5); the five-language
  package versions are unified at `1.0.0-rc.1` (2026-08-13 decision,
  five-language-ci-design §10 version policy), and minimum changes between
  releases follow Sections 9.3-9.5.

Between freezes, all MSRV/declared-minimum changes follow Sections
9.1-9.5. Freezing is done at these points to avoid §26.4's
premature-commitment risk; the freeze records (manifests) are the audit
trail.

## 10. Deprecation and EOL process

- **Notice period**: any deprecation of a public API, Profile, contract,
  or CLI behavior is announced in one minor (CHANGELOG deprecation
  section + rustdoc/documentation annotation) and is removed no earlier
  than **one full minor later**, in a subsequent minor or major.
- **Deprecated is not breaking**: during the notice period, behavior and
  machine output are unchanged; a `deprecation` diagnostic may be added,
  but exit code, code, and payload fields do not change (support-policy
  §6).
- **Removal**: follows the Section 4.4 five points (in `0.x`) or the
  Section 4.3 major rules (after `1.0.0`), and names an equivalent
  replacement path in the migration guide.
- **EOL recording**: branch EOL dates are recorded in the CHANGELOG and
  release notes (Section 5.1); a deprecation/removal may never silently
  change format acceptance/recovery behavior (Profile compatibility,
  Section 4.2).

## 11. Contract version governance

- **Published `namespace.contract@N` is never reinterpreted** (§21.3,
  line 1845; §12.2). The frozen registry arrays and constructors remain
  byte-exact: v1-v6 are frozen and v7 is an additive superset
  (IMPLEMENTATION.md ch. 12); a published record's identity, payload
  schema, and decoder behavior do not change.
- **New capability = new identity**: evolution ships a new
  contract/version pair (e.g. `core.materialization-request@2`,
  `json.lossless-syntax-query@2`); the old version stays as a frozen
  identity. One product version may support multiple contract versions
  simultaneously (§12.2).
- **Retirement**: when a contract/Profile stops being part of the default
  capability surface:
  1. a one-minor deprecation notice (Section 10);
  2. a retirement record with the reason, the alternative contract ID,
     and the last product version supporting it;
  3. the registry record and the typed-decoder parse paths are **never
     deleted** — historical data must remain auditable;
  4. `consema capabilities` annotates the retired state, and format
     family/Profile parse compatibility boundaries (acceptance/recovery)
     are not silently changed by retirement (support-policy §7).
- **Error codes are never redefined** (Section 6); additions and
  redefinitions require a new RFC or a new contract version.
- The 0.13.0 Feature-Complete Manifest closes this process as its first
  registered instance (no retirement has occurred yet; this RFC is the
  policy, not a history record).

## 12. Versioning and migration of this policy

- This RFC is versioned by the `docs/rfcs/` numbering; it is
  `0020-compatibility-and-support-policy-v1`. Amendments are new RFCs
  (or, for contract-level behavior, new contract versions) — policy
  changes never edit this document in place beyond errata.
- All policy changes are recorded in the CHANGELOG.
- Product releases follow the release train (roadmap §11.4): product
  `1.0.0` = Rust crates 1.0.0 + Go module v1.0.0 + TypeScript/Python/
  Kotlin packages 1.0.0 + Specification v1
  release set + Conformance release set 1.0.0; before that, the language
  modules are v0.x (RFC 0016 §9; the five-language package versions are
  unified at `1.0.0-rc.1` in the rc window — five-language-ci-design §10
  version policy). Package versions never substitute contract
  versions (§11.4, line 889).
- The support-policy summary document (`docs/support-policy.md`) is
  updated in the same release as any change to this RFC; the RFC is the
  normative source (Section 1.2).

## 13. Conformance integration

- The shared vectors (`conformance/vectors/`) are the authority for
  language-neutral behavior (roadmap §17); all five implementations
  (Rust, Go, TypeScript, Python, Kotlin) run the same vectors through
  their own runners (RFC 0016 §7; five-language-ci-design §2).
- **Compatibility is enforced by vectors, not by prose**: the Section 4.2
  compatibility boundaries (output order, default loss policy,
  acceptance/recovery) are represented by vectors; any release that
  touches them must add or update vectors in the same release, and any
  breaking change must update old and new behavior vectors together
  (Section 4.4 point 4).
- When a public behavior change is discovered (including by any language
  implementation — roadmap §11.3), the process is: stop the affected
  capability, build the minimal cross-language counterexample, classify
  (implementation / test / spec), fix spec and conformance first, publish
  a new contract ID if public behavior changes, let Rust pass the revised
  vectors first, then resume the other languages (RFC 0016 §7).
- The conformance suite itself is part of the release train: the
  conformance release set is versioned with the product (Section 12), so
  consumers can pin the exact vectors a release was verified against.

## 14. Rejected alternatives

- **LTS-style multi-stream support (N-1 in `0.x`)**: rejected. In `0.x`
  only the latest minor is maintained (support-policy §5); the
  `1.0.0`-onward previous-minor window with a security-only tail is the
  chosen trade-off between maintenance load and upgrade safety.
- **No MSRV policy (track whatever rustc ships)**: rejected — MSRV
  stability is part of the production promise (§21.1, line 1820; §21.4);
  a declared, CI-enforced MSRV is the only way users can plan upgrades.
- **Allowing MSRV/Go-minimum bumps in patch releases**: rejected —
  §21.1 line 1820 is a hard rule; a patch must never force a toolchain
  upgrade.
- **Pre-writing concrete toolchain versions for years in this policy**:
  rejected — §21.4 (line 1863) and §26.4 require freezing at the
  Rust-Feature-Complete and Go RC points, where the stable ecosystem is
  known; a fixed multi-year number would be an unverifiable promise.
- **Deleting registry records or decoder paths on retirement**: rejected
  — historical data must remain auditable; retirement changes the default
  capability surface, not the record (Section 11, point 3).
- **Deprecation and removal in the same minor**: rejected — the
  one-full-minor notice period (Section 10) is the minimum window users
  need to migrate.
- **Reinterpreting `@N` instead of publishing `@N+1`**: rejected —
  §21.3 line 1845 and §12.2 make published contracts immutable; any
  reinterpretation would silently break stored data and pinned consumers.
- **Keeping only `docs/support-policy.md` without an RFC**: rejected —
  §12.3 requires RFC-first governance for public commitments and §21.4
  requires them to be public before `1.0.0`; the RFC is the reviewable
  normative source, the summary document is the outward face
  (Section 1.2).
- **A per-release "compatibility matrix" as the contract (instead of
  rules)**: rejected — a matrix documents history but does not bind
  future releases; the rules of Sections 4-11 bind, and the matrix
  (CHANGELOG/release notes) records what happened.

## 15. Relationship to existing documents

| Document | Relationship |
|---|---|
| `docs/support-policy.md` | Public summary of this RFC. Same content, shorter form; maintained in lockstep; this RFC is normative. |
| `docs/five-language-ci-design.md` | CI toolchain pins for TypeScript/Python/Kotlin ('26.x' / '3.12.x' / Temurin 17) and the version policy; Sections 9.3-9.5 and 9.7 adopt them. |
| `SECURITY.md` | Operational security document; its disclosure section (SLA, channels, support windows) is restated and made contractual by Section 8. |
| `README.md` | No support-policy statements of its own beyond capability listings; version-change record points to the CHANGELOG. No conflicts found. |
| `docs/go-implementation-plan.md` §1.3 | go.mod minimum freeze (`go 1.26` at 0.14.0) is adopted by Section 9.2. |
| `docs/fc-manifest-0.13.0.json` | `rust_compiler_msrv` freeze (1.85 / 1.97.1) is the Rust-FC freeze record of Section 9.7. |
| RFC 0015 §5.3 | Exit-code classification frozen; Section 6 adopts it. |
| RFC 0016 §9 | Go module release-train relationship; Section 12 adopts it. |

Consistency check results at acceptance: no contradictions found with
`SECURITY.md`, `README.md`, RFC 0015 §5.3, RFC 0016 §9,
`go-implementation-plan.md` §1.3, or `fc-manifest-0.13.0.json`. One
drift, resolved in favor of this RFC: `docs/support-policy.md` §2 still
describes the Go window as a placeholder "frozen at Go RC" while the
implementation has already declared `go 1.26` in `go.mod` (frozen at
0.14.0 per the implementation plan); Section 9.2 records both facts —
the declared minimum is frozen at 0.14.0, the formal minimum +
verification-toolchain freeze happens at Go RC. The summary document
should be updated to match on its next revision.

## 16. Acceptance gates

This RFC is Accepted when all of the following hold, and remains in force
through `1.0.0`:

1. All seven §21.4 items are stated (MSRV window — §9.1; Go version
   window — §9.2; TypeScript/Python/Kotlin version windows — §9.3-9.5;
   supported OS/arch — §9.6; security fix policy — §8;
   previous-minor branch support — §5.1; deprecation notice period — §10;
   contract/Profile retirement — §11) plus the freeze timing (§9.7).
2. The §21.3 compatibility boundaries (patch/minor/major, `@N` never
   reinterpreted, output order / default loss policy /
   acceptance-recovery as compatibility) are stated and enforceable via
   conformance (Sections 4, 13).
3. The content is consistent with `SECURITY.md` (SLA and disclosure),
   RFC 0015 §5.3 (exit classes), RFC 0016 §9 (release train), and the
   frozen toolchain records (fc-manifest, go.mod, consema-ts
   package.json engines, consema-py pyproject.toml requires-python,
   consema-kt build.gradle.kts).
4. `docs/support-policy.md` carries the same content as its public
   summary (any drift is corrected on its next revision per Section 15).
5. This RFC's own doc (motivation, non-goals, data model, state machine,
   error algebra, resource limits, security, versioning, conformance,
   rejected alternatives) covers the §12.3 field list (Section 1.3).
6. It is recorded in the roadmap §27 as R-20 delivered at `0.19.0` —
   i.e. before `1.0.0`, satisfying the §21.4 "must be public before
   `1.0.0`" requirement.
