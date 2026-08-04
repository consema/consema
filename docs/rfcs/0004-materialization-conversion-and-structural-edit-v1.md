# RFC 0004: Materialization, conversion, and structural edit v1

- Status: Accepted for Consema 0.5.0 implementation
- Date: 2026-08-04
- Scope: portable-value materialization, audited conversion composition, format operation registry, structural edit transactions, dry-run plans, untouched-byte proof, and SourcePatch derivation

## 1. Decision

Consema 0.5.0 closes three operation chains without conflating them:

```text
PortableValue + MaterializationRequest
  -> complete new target Document + report + input-to-output provenance

source Document -> Projection -> PortableValue -> Materialization
  -> target Document + composed ConversionReport

immutable Document + format-owned edit operations
  -> validated dry-run plan -> atomic commit
  -> new Document + ChangeSet + UntouchedByteProof + SourcePatch
```

Materialization is not formatting an existing source. Conversion is not one
opaque parser-to-writer shortcut. Structural edit is not a universal tree
rewrite language. SourcePatch is not a semantic diff.

## 2. Compatibility and semantic-model v3

The 0.3 and 0.4 registries remain immutable:

- `ContractRegistry::v1()` remains 15 stable payloads plus the transport;
- `ErrorCodeRegistry::v1()` remains 55 codes;
- `core.semantic-model@1` retains that exact identity;
- `ContractRegistry::v2()` remains v1 plus `core.source-patch@1` and
  `core.source-snapshot@1`;
- `ErrorCodeRegistry::v2()` remains 62 codes;
- `core.semantic-model@2` retains that exact identity.

Consema 0.5 publishes `core.semantic-model@3`. `ContractRegistry::v3()` is the
ordered superset of v2 plus:

```text
core.conversion-report@1
core.edit-plan@1
core.format-operation-registry@1
core.materialization-provenance-map@1
core.materialization-report@1
core.materialization-request@1
core.materialization-result@1
```

`RegistryManifest::current()` points to v3 in 0.5.0. Published v1 and v2
conformance runners bind their explicit registry versions and never follow
`current()`.

## 3. Common MaterializationRequest v1

Materialization consumes one complete `PortableValue`; it never consumes a
format AST, process-local handle, partial projection, or arbitrary bytes.

The common immutable request records:

```text
target_profile               exact ProfileId
style                        exact versioned style ID
encoding                     exact SourceEncoding
newline                      None | Lf | CrLf
mapping_policy               RequireObject | UniqueStringEntriesToObject
representability             ExactOnly
limits                       MaterializationLimits
```

The closed v1 `MaterializationLimits` are:

```text
max_input_nodes
max_output_bytes
max_depth
max_report_entries
max_provenance_entries
```

All limits apply before or during allocation. A failure returns no Document,
no partial bytes, and no provenance that can be mistaken for a result.

`ExactOnly` is intentionally the only v1 representability value. It means a
target-native semantic value must round-trip through that target's published
exact projection contract. It does not mean the source spelling survives,
because materialization has no source spelling.

`UniqueStringEntriesToObject` is an explicit, reportable representation
conversion for an `EntryMapping` whose keys are unique strings. It is never a
default, never collapses duplicates, and changes whole-operation fidelity to
`Transformed`. Non-string or duplicate keys still fail.

## 4. Format-owned style and target closure

0.5.0 freezes these style IDs:

```text
json.canonical-compact@1
json.canonical-pretty@1
toml.canonical-document@1
```

Supported target profiles are:

```text
json.strict@1
jsonc.bounded@1
toml.1.0@1
```

The JSON styles support UTF-8 and newline `None`, `Lf`, or `CrLf`. Compact
emits no layout newline except an explicitly requested final newline. Pretty
uses two ASCII spaces per level and the requested newline; `None` is invalid
for pretty output.

The TOML canonical document style supports UTF-8 and requires `Lf` or `CrLf`.
It emits one assignment per root object entry, represents nested objects as
deterministic inline tables, and emits one final newline. It does not infer
table ownership, dotted-key spelling, comments, or historical layout because
no source Document exists.

UTF-16 and Latin-1 are common Source encodings but are not silently enabled as
JSON/TOML materialization encodings. Format-specific support must be frozen by
the owning Profile.

## 5. JSON representability

JSON/JSONC materialization v1 accepts exactly:

```text
Null Boolean Integer Decimal String Sequence Object EntryMapping
```

`Object` keys are strings by construction. `EntryMapping` is accepted only
when every key is String; duplicate keys and source order are preserved.
`mapping_policy` is irrelevant to an exactly representable EntryMapping and
must not cause it to be collapsed.

BinaryFloat32/64, Bytes, temporal values, and unsupported extensions fail.
Finite binary floats are not converted to Decimal by guessing because strict
bit equality would not be recoverable from a JSON number.

All strings and object names use deterministic JSON escaping. Integer and
Decimal values use their canonical exact decimal spelling. JSONC
materialization emits valid JSON; it does not invent comments.

## 6. TOML representability

TOML materialization v1 requires a root `Object`, or an `EntryMapping` accepted
by the explicit `UniqueStringEntriesToObject` policy. It accepts recursively:

```text
Boolean Integer BinaryFloat64 String
Date Time LocalDateTime OffsetDateTime
Sequence Object
```

Integer must fit TOML's signed 64-bit range. BinaryFloat64 must have a legal
deterministic TOML representation without losing payload semantics; canonical
NaN payloads may be represented, non-canonical NaN payloads fail. Temporal
fields must satisfy TOML precision and offset constraints exactly.

Null, Decimal, BinaryFloat32, Bytes, EntryMapping below the root, and
unsupported extensions fail. Root or nested duplicate keys never receive a
first/last-wins interpretation.

## 7. Completion algebra

Format materializers return exactly one of:

```text
CompleteMaterialization {
  document,
  fidelity: Exact | Transformed,
  report,
  provenance
}

FailedMaterializationAttempt {
  failure,
  report,
  analyzed_input_paths
}
```

Failed attempts contain no Document and no partial output bytes. Report events
are stable, ordered, machine-readable diagnostics. Human wording is not a
contract.

## 8. Materialization provenance

Materialization provenance points from portable input locations to the new
Document. It is not the reverse-direction Projection provenance map.

Input locations are:

```text
Value(ValuePath)
Association(AssociationLocation)
```

Output origins contain:

```text
target snapshot identity        process-local only
target NodeRef                  process-local only
target raw Span
relation                       Direct | Reencoded | Generated
```

The process-local Rust map is complete for every emitted value and supported
association. `core.materialization-provenance-map@1` crosses the wire only
after the caller supplies a stable target source ID and target node locator.
Missing locators fail; identities are not silently dropped.

## 9. Conversion composition

Conversion is a library-level orchestration operation:

```text
ProjectionRequest(source profile/native model)
MaterializationRequest(target profile)
```

It has no hidden default mapping policy. The operation stops if projection
fails, if materialization fails, or if either report contains loss not
authorized by the corresponding explicit request.

`ConversionReport` contains complete ordered stages:

```text
projection fidelity and report
materialization fidelity and report
overall fidelity
source and target ProfileId
```

No format crate depends on another format crate. The public facade may
orchestrate independently exposed Projection and Materialization contracts.

## 10. Format operation registry

Every structural operation has an immutable ID/version, target role,
argument schema, and support classification. 0.5.0 freezes:

```text
json.edit.insert-member@1
json.edit.remove-member@1
json.edit.rename-member@1
json.edit.insert-array-element@1
json.edit.remove-array-element@1

toml.edit.insert-entry@1
toml.edit.remove-entry@1
toml.edit.rename-entry@1
toml.edit.insert-array-element@1
toml.edit.remove-array-element@1
```

Existing scalar semantic/literal replacement remains a typed Rust operation
and is declared by the registry as an existing capability; its public
diagnostic codes enter ErrorCodeRegistry v3.

The registry does not claim that operations with similar names have identical
format semantics. It only makes discovery, validation timing, and versioning
uniform.

## 11. JSON structural operations

JSON operations are snapshot-bound:

- insert-member targets an Object value, carries a String name, complete
  `PortableValue`, and placement `Start | End | Before(member) | After(member)`;
- remove-member targets one exact `ObjectMember` identity, so duplicates are
  never ambiguous;
- rename-member targets one exact `ObjectMember` and replaces only its key
  literal;
- insert-array-element targets an Array value and placement
  `Start | End | Before(element) | After(element)`;
- remove-array-element targets one exact `ArrayElement` identity.

Inserted values use the target profile's canonical materialization fragment.
Existing surrounding whitespace and comments are preserved. Delimiter edits
own only the necessary comma plus inserted/removed association span. JSONC
comment ownership is explicit: a comment outside the removed association span
is not deleted merely because it is adjacent.

## 12. TOML structural operations

TOML operations use native ownership:

- insert-entry targets a table/inline-table item, carries one direct key
  segment, a representable `PortableValue`, and a supported placement;
- remove-entry targets one exact `TomlEntry` identity;
- rename-entry targets one exact `TomlEntry`, preserves table ownership, and
  rejects a resulting duplicate key;
- insert-array-element targets a TOML array item;
- remove-array-element targets one exact `TomlArrayElement` identity.

0.5.0 does not move entries between tables, synthesize dotted-key ownership,
or rewrite standard tables into inline tables. Those are distinct future
operations. Inserted literals use canonical TOML fragments; untouched table
headers, comments, whitespace, and existing value spellings remain exact.

## 13. Transaction, precondition, and conflict algebra

One immutable transaction binds one base `SnapshotIdentity`. Every operation
is fully validated before any output is published.

Conflicts include:

```text
WrongSnapshot
WrongRole
TargetNotFound
DuplicateTarget
OverlappingOwnership
AncestorDescendantConflict
PlacementAnchorRemoved
DuplicateKey
UnsupportedOperation
UnrepresentableValue
ResourceLimit
NewDocumentFormationFailed
```

Two independent insertions at one placement boundary are a conflict unless
their operation contract defines an explicit deterministic batch order. v1
does not define such ordering and therefore rejects them.

Validation, source-edit preparation, output allocation, reparse, mapping,
untouched proof, and SourcePatch derivation form one atomic commit. A failure
returns none of the successful artifacts.

## 14. Dry-run EditPlan v1

Dry-run performs every deterministic validation and byte-planning step except
publishing a new Document. Its transferable form contains:

```text
schema                         core.edit-plan@1
source_id                      caller-stable source identity
base_digest                   ContentDigest
profile                       ProfileId
operations                    ordered operation ID/version + safe summary
replacements                  exact SourcePatch replacement facts
target_digest                 precomputed digest
report                        ordered diagnostics/events
```

Secrets use the SourcePatch redaction rules. A dry-run plan is not authority
to write a file and is never applied without rechecking base digest and every
original-byte precondition.

## 15. Untouched-byte proof

Every successful edit commit includes `UntouchedByteProof`. It is an ordered
cover of all old-source intervals outside replacements, mapped to target
intervals. Verification requires:

- old regions exactly cover every non-replaced old byte once;
- new regions exactly cover every non-inserted new byte once;
- each mapped region has equal length and equal bytes;
- region order is monotonic;
- base and target digests match the proof.

The proof says only that bytes outside planned replacements are identical. It
does not assert semantic equivalence of the changed regions.

## 16. SourcePatch derivation

A committed edit derives `core.source-patch@1` from:

- the exact old SourceSnapshot;
- prepared non-overlapping source edits;
- the exact new SourceSnapshot;
- operation IDs and redaction metadata.

The derived patch must reapply to the old snapshot and reproduce the exact new
digest during tests and conformance. ChangeSet remains the document-level
change fact; SourcePatch remains the portable raw-byte application fact.

## 17. Registry v3 error codes

ErrorCodeRegistry v3 extends v2 with the existing stable edit failure surface
and the following new operation codes:

```text
core.conversion.materialization-failed@1
core.conversion.projection-failed@1
core.conversion.unauthorized-loss@1

core.edit.conflicting-edits@1
core.edit.duplicate-key@1
core.edit.exact-literal-requires-literal@1
core.edit.formation-failed@1
core.edit.incomplete-target@1
core.edit.invalid-literal@1
core.edit.operation-unsupported@1
core.edit.precondition-failed@1
core.edit.representation-incompatible@1
core.edit.resource-limit@1
core.edit.semantic-unavailable@1
core.edit.target-not-found@1
core.edit.unsupported-value@1
core.edit.wrong-role@1
core.edit.wrong-snapshot@1

core.materialization.formation-failed@1
core.materialization.invalid-request@1
core.materialization.resource-limit@1
core.materialization.unrepresentable@1
core.materialization.unsupported-encoding@1
core.materialization.unsupported-newline@1
core.materialization.unsupported-profile@1
core.materialization.unsupported-style@1
```

Protocol shape failures continue to use `core.protocol.*@1`.

## 18. Wire closure

All new payloads use fixed-field PortableValue schemas and canonical JSON/PVCE
transport. Rust enums, display text, parser nodes, and process-local identities
never cross the wire.

`core.materialization-result@1` distinguishes present complete results from
failure without overloading PortableValue Null. A materialized Document crosses
the wire as its verified `core.source-snapshot@1`, exact target ProfileId,
report, and externally bound provenance; the receiver may reparse it.

## 19. Security and resource behavior

- materialization counts input nodes and depth before recursive allocation;
- output growth is checked before buffer reserve and at every append;
- report and provenance limits fail the whole operation;
- structural operations never evaluate expressions, resolve imports, access
  files, or perform network I/O;
- caller strings are escaped by the target Profile, never interpolated as raw
  syntax;
- dry-run and SourcePatch debug output honor redaction;
- base digest and original bytes are both checked before patch application;
- no failure returns a partial new Document or applyable partial plan.

## 20. Conformance gates

Consema 0.5 must prove with language-neutral vectors:

- JSON compact/pretty materialization for every representable core kind;
- JSON exact EntryMapping duplicate preservation and non-string-key rejection;
- TOML materialization for scalar, temporal, array, nested object, limit, and
  unrepresentable cases;
- explicit mapping conversion succeeds only for unique string entries and is
  reported as Transformed;
- materialization output reparses and projects to the required portable value;
- provenance covers every emitted value/association within limits;
- JSON member and array insert/remove/rename around empty, singleton,
  duplicate, first/middle/last, comment, and trailing-comma cases;
- TOML entry and array insert/remove/rename with table ownership and duplicate
  conflict cases;
- multi-operation wrong-snapshot, overlap, duplicate target, ancestor conflict,
  placement-anchor removal, allocation limit, and reparse failure are atomic;
- untouched-byte proof verifies and detects any tampering;
- derived SourcePatch reapplies to the base and reproduces the committed bytes;
- dry-run and commit produce the same replacement set and target digest;
- JSON-to-TOML and TOML-to-JSON conversion reports contain both stages and
  reject every unapproved representation change;
- semantic-model v1/v2 registries remain byte-for-byte unchanged while v3
  payloads round-trip over canonical JSON and PVCE;
- malicious depth, node count, output growth, offset, replacement, and string
  escaping inputs fail within configured limits.

## 21. Explicit non-goals

- formatting or reformatting an existing Document;
- semantic diff, merge, fuzzy patch, three-way reconciliation, or patching an
  unrelated snapshot;
- JSON5, YAML, INI, Properties, XML, plist, or HCL materialization;
- table moves, generic reorder, TOML dotted-key synthesis, or comment reflow;
- schema-driven default insertion or validation;
- file discovery, locking, temporary writes, fsync, rename, permissions, or
  recovery manifests;
- universal syntax templates or a universal CST;
- Go implementation, which still waits for the Rust feature-complete gate.

## 22. Rejected alternatives

- **Serialize a format AST:** rejected because it leaks implementation details
  and cannot compose across languages.
- **Use one generic Map writer:** rejected because duplicate associations,
  temporal values, EntryMapping, and target-native constraints differ.
- **Let materialization pick defaults:** rejected because style, encoding,
  newline, mapping conversion, and loss authorization are observable policy.
- **Represent all structural edits as delete+insert:** rejected because target
  identity, ownership, conflict, and untouched guarantees would be lost.
- **Return best-effort bytes on failure:** rejected because partial output can
  be mistaken for a valid configuration.
- **Make SourcePatch the edit API:** rejected because byte application does not
  define format semantics or structural intent.
