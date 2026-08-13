# RFC 0014: HCL family profiles v1

- Status: Implemented in Consema 0.11.0
- Date: 2026-08-06
- Scope: `hcl.native@1` and `hcl.tfvars@1` profiles; one native syntax
  system shared by both profiles (body, attribute, block, label, expression,
  template facts); unevaluated expressions as first-class native content;
  literal-complete projection with explicit failure or the authorized
  `hcl.expression@1` ExtendedValue; query, projection, materialization,
  structural edit, recovery, security, HashiCorp differential conformance,
  and the semantic-model v6 boundary: HCL query-result wire contracts are not
  part of v6 and follow the RFC 0011 external-locator pattern, registered as
  `core.hcl-query-result@1` in a subsequent semantic-model version
- Depends on: RFC 0011 (error-code registry boundary),
  RFC 0012/0013 (source contract precedent reuse)
- External behavior references:
  [HCL Native Syntax Specification](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md),
  [hashicorp/hcl source (hclsyntax parser and scanner)](https://github.com/hashicorp/hcl),
  [Terraform variable definitions (.tfvars) documentation](https://developer.hashicorp.com/terraform/language/values/variables),
  [Terraform issue #19202 (blocks inside `.tfvars` files)](https://github.com/hashicorp/terraform/issues/19202),
  [Terraform pull #20450 (specialized tfvars diagnostics)](https://github.com/hashicorp/terraform/pull/20450)

## 1. Decision

Consema 0.11.0 publishes two HCL profiles:

```text
hcl.native@1
hcl.tfvars@1
```

They share one syntax system: the HCL Native Syntax as specified by
HashiCorp's `hclsyntax/spec.md`, and one native semantic model
(body/attribute/block/label/expression/template facts, Section 6). This
differs from the plist family (RFC 0013), where two profiles own disjoint
syntax systems over one value model. Here the two profiles own one grammar;
`hcl.tfvars@1` is `hcl.native@1` under one structural restriction: the top
level of a tfvars document admits attributes only, never blocks (Section 5).

The profile is selected by the caller before formation. Neither the `.tf`
nor the `.tfvars` extension ever selects a profile, representation, or
encoding. Terraform's `.tfvars.json` convention is a different syntax system
(JSON-based HCL) and is an explicit v1 exclusion (Section 14).

Both profiles are formation-only documents: Consema parses, preserves, and
queries HCL syntax and structure but never evaluates it. Variables, function
calls, template interpolation, template directives, and for-expressions are
native content with exact source identity; no evaluator exists anywhere in
parse, query, projection, materialization, or edit (hard gate 1, Section 13).
Application semantics — Terraform variable declarations, resource typing,
provider schema, reference resolution, `terraform.tfvars` auto-load
precedence — never enter the generic HCL semantic model (hard gate 2), and
Terraform-specific interpretations are never recorded as HCL format facts
(hard gate 3).

## 2. Source and encoding

Every entry point constructs a bounded `SourceSnapshot` before tokenization.
Unmodified rendering returns the exact original bytes. All public spans
remain half-open raw-byte ranges; decoded scalar locations are derived from
the frozen source index and never replace raw spans.

The HCL Native Syntax Specification is frozen as the source contract:

- Source is Unicode text in UTF-8. "Invalid or non-normalized UTF-8 encoding
  is always a parse error"; no Unicode normalization is performed. Invalid
  UTF-8 bytes therefore make formation FatalFormationFailure (Section 3),
  matching the invalid-byte-decoding precedent of RFC 0012/0013.
- "UTF-8 encoded Unicode byte order marks are not permitted." A leading BOM
  is a valid UTF-8 sequence but a Profile violation: formation is Recovered
  with `hcl.parse.byte-order-mark@1`. A BOM sequence elsewhere in the source
  is likewise Recovered. (The pinned Go oracle silently strips a leading BOM
  — its scanner applies `stripUTF8BOM` before tokenization — instead of
  rejecting it; that divergence is recorded in the differential exclusion
  list, Section 12.)
- A newline is exactly U+000A (LF) or U+000D U+000A (CRLF). A lone CR is not
  a newline; it is an unexpected character and makes formation Recovered.
  The pinned Go oracle rejects a lone CR as well: its scanner's newline rule
  is `'\r'? '\n'`, so a lone CR is an invalid token and a parse error. The
  outcomes are therefore equivalent — a lone CR never appears in a Complete
  document under either parser (Section 12).
- UTF-16, UTF-32, Latin-1, Windows code pages, and any other encoding are
  explicit v1 exclusions. There is no declaration, prolog, or encoding
  negotiation in HCL; the encoding is always UTF-8 and always selected
  before formation.

Newlines are structural: an attribute, block, or one-line block must be
terminated by a newline or by end of file. Inside parentheses, brackets, and
braces delimiting sub-expressions, function arguments, collection values, or
index keys, newline sequences are ignored as whitespace and do not terminate
constructs. A newline also acts as an element separator inside tuple and
object constructors (Section 4.6).

## 3. Formation and recovery

Formation uses the established three-way outcome:

```text
Complete
Recovered
FatalFormationFailure
```

`Complete` requires exhaustive coverage of the admitted source bytes under
the frozen grammar (Section 4), every configured limit, and the chosen
profile's structural rule: `hcl.native@1` admits any body; `hcl.tfvars@1`
additionally requires that no block appears at the top level (Section 5).

`Recovered` retains the immutable source, exhaustive piece coverage, ordered
diagnostics, and every independently proven construct. Recovery happens only
at deterministic boundaries and never asserts unproven semantics: no closing
delimiter, identifier, equals sign, value, or attribute is invented to
fabricate a Complete body. The recovery boundary for an expression that
fails to parse is the end of its line, except that an unterminated
bracket/paren/brace extends the region to the matching close if one exists
and to end of line otherwise; an unterminated quoted string extends to end
of line; an unterminated heredoc extends to end of file (bounded by the
heredoc size limit). After an expression region ends, body parsing resumes
at the next line. An unterminated interpolation or directive inside a
template is an error region covering the remainder of the template. A
Recovered Document remains queryable over its proven parts (Section 7) but
cannot be projected, materialized, or edited (Sections 8-10).

The HCL grammar's own structural constraint is frozen at formation: "Each
distinct attribute name may be defined no more than once within a single
body." A second attribute with the same name in one body makes formation
Recovered with `hcl.parse.duplicate-attribute@1`, matching the
`hclsyntax` "Attribute redefined" diagnostic; the duplicate occurrence
remains an inspectable proven syntax piece, never a native attribute.

Fatal conditions follow RFC 0012 Section 4: invalid UTF-8 byte decoding,
impossible source coordinates, allocation or host-size overflow, or the
inability to construct exhaustive coverage. All other syntax errors form
Recovered when the complete source can still be covered without asserting
unproven native semantics.

## 4. `hcl.native@1` Profile

The grammar below is frozen from the HCL Native Syntax Specification. The
specification is the primary contract; where the reference implementation's
documented behavior differs from the simplified grammar, the implementation
behavior is frozen and the divergence is recorded in Section 12. This
mirrors the plist family precedent (RFC 0013), where the documented contract
is the semantic authority and Foundation's actual behavior is recorded
where it differs.

### 4.1 Token facts

- **Identifiers** follow UAX #31: `Identifier = ID_Start (ID_Continue | "-")*`.
  Unicode letters and unambiguous punctuation start identifiers; digits,
  combining marks, and the hyphen continue them. `foo-bar` is a valid
  identifier. Identifiers name attributes, blocks, naked labels, variables,
  and functions.
- **Numbers** are decimal only: `decimal+ ("." decimal+)? (expmark decimal+)?`
  with `expmark = ("e" | "E") ("+" | "-")?`. There is no leading sign in a
  literal (`-` is a unary operator, and `+` is not a unary operator at all),
  no hexadecimal, octal, or binary form, and no underscore separator. A
  literal that violates these rules is Recovered with
  `hcl.parse.invalid-number@1`. (This RFC deliberately freezes the
  specification's decimal-only rule; a common misconception that HCL accepts
  hex or underscore-separated literals is not supported by the spec.)
- **Keywords** are exactly `true`, `false`, and `null`. They are literals
  only in expression term positions (Section 4.3); their spellings remain
  valid identifiers under `Identifier = ID_Start (ID_Continue | "-")*`, so
  `true = 1` is a valid attribute name and keyword spellings are likewise
  admitted as block types and labels. The specification also permits the
  keywords as static traversal roots — they "can also be interpreted as
  static traversals, behaving as if they were references to variables of
  those names" — and Consema preserves both readings without ever
  evaluating either. There are no other reserved words: `for`, `if`, `in`
  are contextual.
- **Line comments** begin with `//` or `#` and end at the next newline
  sequence; a line comment is equivalent to a newline for grammar purposes,
  so a line comment terminates the attribute or block it follows.
- **Inline comments** begin with `/*` and end with `*/`, may contain newline
  sequences (which are not newline tokens and do not terminate constructs),
  and count as whitespace. Comments cannot nest, cannot appear inside a
  comment, and cannot appear inside template literal text except within
  interpolation or directive sequences.
- **Whitespace** is space (U+0020) and tab (U+0009); newline sequences are
  not whitespace (Section 2). Trivia between body items is ignored except
  where the grammar requires a newline terminator.
- **Traversal facts**: a variable expression "can be interpreted as a static
  traversal" per the spec — `foo`, `foo.bar`, `foo[0]`, `foo.*.bar` are
  static traversal facts, never resolved.

### 4.2 Body grammar

```text
Body             = (Attribute | Block | OneLineBlock)*
Attribute        = Identifier "=" Expression Newline
Block            = Identifier (StringLit | Identifier)* "{" Newline Body "}" Newline
OneLineBlock     = Identifier (StringLit | Identifier)* "{" (Identifier "=" Expression)? "}" Newline
```

- An attribute is `identifier = expression`; whitespace around `=` is
  flexible; the terminator is a newline or end of file.
- A block is a type identifier, zero or more labels (each a quoted literal
  string without interpolation, or a naked identifier), and a nested body in
  braces. Blocks with the same type and labels may repeat; block order and
  identity are preserved native facts.
- A one-line block contains at most one attribute and no nested blocks.
- The body's only uniqueness constraint is the per-body duplicate-attribute
  rule of Section 3. An attribute and a block may share a name in one body;
  the grammar does not forbid it, and the Profile preserves both as native
  facts rather than importing the schema-decode layer's ambiguity rules
  ("The meaning of this association is defined by the calling application"
  per the spec). The pinned Go parser also accepts the collision at parse
  time — attributes and blocks are collected in separate structures — so
  the differential manifest records an expected-no-divergence exclusion
  (Section 12).
- End of file terminates an attribute, block, or one-line block without a
  trailing newline. An empty source is a valid empty body.

### 4.3 Expression grammar

The expression grammar is frozen as:

```text
Expression        = ExprTerm | Operation | Conditional
Conditional       = Expression "?" Expression ":" Expression
Operation         = binaryOp
binaryOp          = ExprTerm binaryOperator ExprTerm
binaryOperator    = "==" | "!=" | "<" | ">" | "<=" | ">="
                  | "+" | "-" | "*" | "/" | "%" | "&&" | "||"
unaryOp           = "-" | "!"
ExprTerm          = unaryOp* (LiteralValue | CollectionValue | TemplateExpr
                  | VariableExpr | FunctionCall | ForExpr
                  | ExprTerm Index | ExprTerm GetAttr | ExprTerm Splat
                  | "(" Expression ")")
LiteralValue      = NumericLit | "true" | "false" | "null"
GetAttr           = "." Identifier
Index             = "[" Expression "]"
Splat             = attrSplat | fullSplat
attrSplat         = "." "*" GetAttr*
fullSplat         = "[" "*" "]" (GetAttr | Index)*
FunctionCall      = Identifier "(" arguments ")"
```

Operator precedence, highest to lowest (binary operators are left-associative
within a level):

```text
unary - !            (highest)
*  /  %
+  -
>  >=  <  <=
==  !=
&&
||                   (lowest)
```

- There is no exponentiation operator. `**` is two `*` operators and is
  invalid as a binary chain in practice; an expression like `2 ** 3` is a
  syntax error (Recovered).
- The conditional `? :` is a separate production and never binds tighter
  than `||`. The conditional expression is the only *unparenthesized* colon
  context at the expression level; object-constructor keys and
  for-expression introductions place `=` or `:` inside their own
  productions, so no confusion arises.
- Unary `-` and `!` are parsed at the expression-term layer, matching the
  pinned Go parser (whose `parseExpressionTerm` handles them before the
  base term, with a comment that `-46+5 should parse as (-46)+5`). They
  therefore bind more tightly than every binary operator, and that binding
  naturally covers the binary operations that follow: `-1 + 2`, `2 * -1`,
  and `-1 * 2` are all valid, parsing as `(-1) + 2`, `2 * (-1)`, and
  `(-1) * 2`. Unary operators chain over terms: `!!x` is `!(!x)` and is
  valid. Unary `+` does not exist; `+1` is a syntax error (Recovered).
- A variable expression is a traversal root (Section 4.1); `true`, `false`,
  and `null` are also valid traversal roots.
- Function-call arguments admit trailing commas and an optional `...`
  expansion marker, and newlines are ignored as whitespace between them.
- Parentheses ignore newlines as whitespace.

### 4.4 Templates

- A quoted template is a single-line double-quoted string. Literal newline
  sequences are not permitted; newlines must be escaped. Escape sequences
  are `\n`, `\r`, `\t`, `\"`, `\\`, `\uNNNN` (BMP), and `\UNNNNNNNN`
  (supplementary plane).
- Interpolation is `${ Expression }`, with the same optional strip markers
  as directives on either brace:
  `TemplateInterpolation = ("${" | "${~") Expression ("}" | "~}")`. The
  `${` sequence is escaped as `$${` and produces literal `${` text.
- Directives are `%{ if Expression }`, `%{ else }`, `%{ endif }`,
  `%{ for Identifier , Identifier in Expression }`, and `%{ endfor }`;
  the `%{` sequence is escaped as `%%{`. The for-directive's key
  identifier is optional: the specification's TemplateFor production
  requires both identifiers, while the pinned Go parser reads a key only
  when a comma follows, and Consema freezes the implementation behavior —
  `%{ for x in list }` is valid (the divergence is recorded in
  Section 12). Directives may use the optional strip markers `~` on either
  brace (`%{~ if }`, `%{~ endif ~}`), which trim adjacent literal
  whitespace — a source fact preserved, never applied.
- An interpolation or directive may contain nested templates as
  expressions.
- A template consisting of a single interpolation unwraps to the
  interpolation's value verbatim without string conversion under
  evaluation; this is evaluation semantics. Consema never evaluates
  (Section 6), so the unwrap is documented but never performed.
- Template literal text and escapes are exact source facts; `\n` in source
  is not the same native string as a literal newline (which cannot occur in
  a quoted template anyway).

### 4.5 Heredocs

- A heredoc template is introduced by `<<` or `<<-` followed by a bare
  identifier marker and a newline, and ends when the same identifier
  appears again on a line of its own. The closing line may be preceded by
  any number of spaces or tabs, and trailing whitespace after the marker
  is ignored: the pinned Go parser trims the line with `bytes.TrimSpace`
  before comparing it to the marker, and Consema freezes that behavior,
  which is deliberately broader than the specification's "arbitrary number
  of spaces preceding" the marker (the divergence is recorded in
  Section 12). A line containing the marker followed by any other content
  is not a closing line — the specification's "line of its own" and the Go
  parser agree — so the whole line is literal heredoc content.
- The marker is an identifier only; the quoted-marker form (`<<"EOT"`) does
  not exist in the current specification and is Recovered.
- `<<-` removes the minimum number of leading spaces from each line's
  leading literal text. The mode (`<<` vs `<<-`), the marker spelling, the
  closing line's leading spaces, and the indentation analysis are preserved
  representation facts; the stripping is performed only when the template's
  literal value is read, never destructively.
- Interpolation and directive syntax is available inside heredoc content,
  with the same `$${` and `%%{` escapes.
- An unterminated heredoc is Recovered with
  `hcl.parse.unterminated-heredoc@1`; the error region covers the heredoc
  content up to the heredoc size limit (Section 11).

### 4.6 Constructors, for-expressions

```text
CollectionValue   = tuple | object
tuple             = "[" (Expression (("," | Newline) Expression)* ","?)? "]"
object            = "{" (objectelem (("," | Newline) objectelem)* ","?)? "}"
objectelem        = (Identifier | Expression) ("=" | ":") Expression
ForExpr           = forTupleExpr | forObjectExpr
forTupleExpr      = "[" forIntro Expression forCond? "]"
forObjectExpr     = "{" forIntro Expression "=>" Expression "..."? forCond? "}"
forIntro          = "for" Identifier ("," Identifier)? "in" Expression ":"
forCond           = "if" Expression
```

- Tuple and object elements are separated by comma or newline; a trailing
  comma is admitted. Object keys are an identifier (literal name), a quoted
  template, or a parenthesized expression, joined to the value by `=` or
  `:`.
- A first tuple element or object key literally spelled `for` must be
  parenthesized or quoted, because the for-expression interpretation has
  priority.
- Object constructors may contain duplicate keys; they are preserved as
  ordered native facts (Section 6), never collapsed. (Rejecting duplicate
  keys happens at evaluation time in HashiCorp's stack, never at parse
  time; Consema has no evaluation layer.)
- The for-expression's `if` guard and the object form's `...` grouping
  marker are source facts; no iteration or grouping is ever performed.

## 5. `hcl.tfvars@1` Profile

`hcl.tfvars@1` is the Terraform variable-definitions-file contract expressed
as a structural restriction of `hcl.native@1`. It is not an independent
grammar: every token, expression, template, and comment rule of Section 4
applies unchanged, including the per-body duplicate-attribute rule.

The profile restriction is: the top-level body of a tfvars Document admits
only attributes. A block anywhere at the top level makes formation Recovered
with `hcl.tfvars.block-not-allowed@1`. This is Terraform's documented file
contract: Terraform v0.12 and later reject blocks in `.tfvars` files —
`hclsyntax.Body.JustAttributes` reports "Blocks are not allowed here."
when a block appears in an attribute-only body (Terraform issue #19202) —
and the specialized diagnostics of Terraform pull #20450 confirm the
intended reading that a `.tfvars` file assigns values to already-declared
variables and declares nothing. Because
the restriction is structural, no nested body can exist in a Complete tfvars
Document.

Two boundaries are deliberately not replicated:

- Terraform's static-only evaluation rule for `.tfvars` values (function
  calls and variable references are rejected by Terraform's loader with
  "Functions may not be called here" / "Variables not allowed") is
  application-layer evaluation policy, not a grammar rule. Formation under
  `hcl.tfvars@1` accepts the full native expression grammar; a derived
  expression is a native fact and fails at literal projection, never at
  formation (Section 8). Replicating the static rule at formation would
  import Terraform's evaluator into the parser and violate hard gate 3.
- Terraform's "value for undeclared variable" rule requires a variable
  declaration schema; no schema exists in Consema (hard gate 2).

Materialization and edit under the tfvars profile refuse any output that
would contain a block (Sections 9-10), keeping the profile rule closed under
every operation.

## 6. Native semantic model

The semantic model is the schema-free HCL body tree. It is not a JSON
Object tree, not a Terraform typed object, and not an evaluated value.

```text
HclDocument
HclBody                  ordered body items
HclAttribute             name + equals + expression
HclBlock                 type + labels + nested body
HclBlockLabel            label text + quote/naked fact
HclExpression            kind + exact source text + children
HclTemplatePart          Literal | Interpolation(expression) | Directive(if/for)
HclNumber                exact source text + canonical decimal + limits
HclErrorRegion
HclSyntaxPiece
```

Semantics that are frozen:

- the root Document owns one body; body items preserve source order;
  attribute and block identity are per-occurrence, never merged;
- duplicate attributes are already excluded at formation (Section 3);
  duplicate object-constructor keys, duplicate block occurrences, and
  attribute/block name sharing are preserved as ordered native facts with
  independent spans — the native model never collapses or resolves them;
- an expression is a first-class native role. It is retained as an AST
  (kind, ordered children, exact spans) and its exact source text is a
  derived fact from the immutable source span — no re-encoding is needed
  and no information is lost. Both representations are always available:
  the AST for structure and the raw text for exactness;
- templates retain ordered parts; a literal part keeps its exact escaped
  text, an interpolation keeps its expression AST, a directive keeps its
  condition/intro AST and its source shape, including `~` strip markers;
- a number keeps its exact source spelling and a canonical decimal value
  (Section 8); numeric equality is canonical-decimal equality, so `1.50`,
  `1.5`, and `15e-1` compare equal as values while remaining distinct
  source facts;
- heredoc mode, marker spelling, and closing-line facts are representation
  facts (Section 4.5);
- unevaluated is the default contract: the model contains syntax, never
  computed values. No variable binding, function table, template expansion,
  or iteration exists; "evaluation" is not a Consema operation (Section 14);
- no application types exist: there is no variable declaration, resource,
  provider, schema, or type-checking role in the model (hard gate 2).

Expression structural equality (used by query filters, projection
comparison, and the `hcl.expression@1` contract) is recursive over kind and
children: number equality is canonical-decimal equality, template equality
is part-wise with exact literal text and structural interpolation/directive
comparison, constructor equality is element-wise, and node identity is never
part of value equality.

## 7. Query contracts

### 7.1 Native domain

`hcl.native-semantic-query@1` supports:

```text
hcl.document-body@1            hcl.body-items@1
hcl.body-attributes@1          hcl.body-blocks@1
hcl.body-block-type-equals@1
hcl.attribute-name@1           hcl.attribute-name-equals@1
hcl.attribute-expression@1     hcl.attribute-literal-value@1
hcl.block-type@1               hcl.block-type-equals@1
hcl.block-labels@1             hcl.block-label-equals@1
hcl.block-nested-body@1
hcl.expression-kind-is@1       hcl.expression-is-literal@1
hcl.expression-text@1          hcl.expression-children@1
hcl.template-parts@1           hcl.tuple-elements@1
hcl.object-entries@1           hcl.error-regions@1
```

Results preserve source order. `hcl.attribute-literal-value@1` is a family
of typed accessors (`as-string`, `as-integer`, `as-real`, `as-boolean-is`,
`as-null-is`): each validates that the attribute's expression is
literal-complete (Section 8) and of the requested type before returning; a
non-literal expression or a type mismatch is a query failure, never a null,
empty, or converted result. `hcl.expression-is-literal@1` answers the
literal-completeness predicate exactly as defined in Section 8.
`hcl.template-parts@1` exposes ordered literal/interpolation/directive
parts; `hcl.tuple-elements@1` and `hcl.object-entries@1` expose constructor
content. `hcl.error-regions@1` exposes the ordered error regions of a
Recovered document (Section 3) as document-level facts, one match per
`hcl.parse.*@1`-coded region in source order; a Complete document yields
none. No operator evaluates, resolves, or executes anything (hard gate 1).

### 7.2 Lossless syntax domain

`hcl.lossless-syntax-query@1` provides exact kind and decoded-text filters
over pieces of the raw source; every non-empty raw byte belongs to exactly
one ordered structural piece with a format-owned syntax kind. The v1 kind
set is:

```text
Whitespace, LineBreak,
LineComment, InlineComment,
Identifier, Equals, Number,
StringOpen, StringContent, StringClose,
InterpolationOpen, InterpolationContent, InterpolationClose,
DirectiveOpen, DirectiveContent, DirectiveClose,
HeredocOpen, HeredocContent, HeredocClose,
BraceOpen, BraceClose, BracketOpen, BracketClose,
ParenOpen, ParenClose, Comma, Colon, QuestionMark, Operator,
ErrorRegion
```

There is no `Bom` kind: a BOM is excluded at formation (Section 2).
`HeredocOpen` covers the `<<`/`<<-` introducer and the marker identifier;
`HeredocClose` covers the closing marker line. Domain/operator/role/profile
validation occurs before the first result; common ordered selection,
limits, cancellation, and terminal-state rules apply unchanged.

## 8. Projection

### 8.1 Literal-complete boundary

An expression is **literal-complete** when its value is uniquely determined
by the source text alone — no evaluation, no context — and it is exactly one
of:

- a number literal (any decimal spelling);
- `true`, `false`, or `null`;
- a quoted or heredoc template containing zero interpolation and zero
  directive sequences (escaped `$${` and `%%{` text counts as literal
  text; for `<<-` heredocs the literal value is the indentation-stripped
  content);
- a tuple constructor whose elements are all literal-complete;
- an object constructor whose keys are identifiers, number literals,
  quoted literal templates, or parenthesized literal-complete expressions,
  and whose values are all literal-complete (duplicate keys remain ordered
  native facts in the projection record);
- a unary minus applied to a number literal;
- a parenthesized literal-complete expression.

Everything else is **derived**: variable and traversal expressions, function
calls, binary operators (`1 + 2` included — no arithmetic folding), the
conditional operator, index and splat operators, for-expressions, templates
with any interpolation or directive, and unary operators over anything but a
number literal. The boundary is deliberately purely syntactic: it is
decidable without any evaluator, and no arithmetic is ever computed
(Section 14).

### 8.2 Targets

The default exact target is:

```text
hcl.projection.body@1
```

It produces the versioned `hcl.body@1` PortableValue record: one ordered
body of items, each an attribute (name string + value) or a block (type,
ordered labels, nested `hcl.body@1`), where every attribute value is
literal-complete and rendered as a typed member — string (exact code
points), integer or real (exact canonical decimal), boolean, null, tuple,
or object. Attribute order, block order, label order, and duplicate
object-constructor keys are preserved exactly.

A derived expression has no default rendering. Projection of a body
containing a derived expression fails atomically with
`hcl.projection.non-literal-expression@1` unless the caller supplies the
explicit `ProjectExpression` policy; under that policy each derived
expression is projected as the authorized ExtendedValue:

```text
hcl.expression@1
```

`hcl.expression@1` carries the expression kind, its exact source text, and
its structural fingerprint; equality follows the structural equality
contract of Section 6, and the encoding is versioned with its own
conformance vectors, per the ExtendedValue discipline of roadmap §5.5. The
projection reports one `Transformed` event per substituted expression with
value and expression provenance. No other transformation exists in v1: no
expression-to-string rendering, no error-to-value substitution, no
contextual guessing (hard gate 4). A Recovered Document never projects.

## 9. Materialization

Materialization consumes a validated `hcl.body@1` record (or, under the
tfvars profile, an attribute-only `hcl.body@1`) and creates a new Document.
It is not a formatter for an existing source.

The canonical style is:

```text
hcl.canonical-document@1
```

It emits UTF-8 without BOM, LF line endings, two-space indentation per body
nesting level, `name = value` attributes, block headers as
`type "label" {`, and a trailing newline after the final item. Additional
rules:

- strings are re-quoted with double quotes and minimal deterministic
  escapes (`\n`, `\r`, `\t`, `\"`, `\\`, and `\uNNNN`/`\UNNNNNNNN` for
  characters that would otherwise be ambiguous or control characters);
- numbers emit their canonical decimal spelling (the normalized value:
  no leading zeros, no trailing fraction zeros, exponent folded into the
  decimal point position; `0` for zero), so `1.50` and `15e-1` both
  materialize as `1.5`;
- booleans and null emit `true`, `false`, and `null`;
- tuples and objects emit with comma separators, deterministic one-item-
  per-line layout at the chosen indentation, and `=` keys;
- `hcl.expression@1` ExtendedValues emit their canonical text and must
  reparse to the same structural fingerprint;
- labels are always quoted with double quotes.

`hcl.body@1` input accepts either spelling for every attribute value and
every nested object-constructor value: the raw typed member that projection
emits (Section 8.2) — a plain string, integer, real, boolean, null, tuple,
or object value — or the equivalent value record with a string `kind`
member (`string` with `text`; `integer`, `real`, and `boolean` with
`value`; `null`; `tuple` with `elements`; `object` with `entries`;
`expression` with an `hcl.expression@1` record). Both spellings validate to
the same promised semantics and materialize identical bytes; the
value-record spelling is the form pinned by the conformance vectors, while
the raw typed member is the form the projection publishes. The raw object
member is the ordered entry-mapping form the projection emits, so repeated
object-constructor keys (Section 6) remain expressible.

The tfvars profile accepts only attribute-only records; a record containing
a block fails `hcl.materialization.unrepresentable@1` for the tfvars
target.

Every style validates the complete input before proportional allocation,
encodes, reparses the exact generated bytes under the promised Profile, and
compares the reparsed native model to the promised input semantics — numbers
by canonical-decimal value equality, everything else by the structural
equality of Section 6. Failure returns no target Document, partial bytes, or
partial provenance. Limits apply to input size, output size, node counts,
and all arithmetic.

## 10. Structural edit

Both profiles publish the same snapshot-bound operations, typed per profile:

```text
hcl.edit.set-attribute-value@1
hcl.edit.insert-attribute@1
hcl.edit.remove-attribute@1
hcl.edit.rename-attribute@1
hcl.edit.insert-block@1
hcl.edit.remove-block@1
```

- `set-attribute-value` replaces the target attribute's expression span
  with the canonical rendering of a supplied typed literal-complete value;
- `insert-attribute` adds an attribute (name + typed literal-complete
  value) to a target body at a position anchor (first, last, or after an
  exact NodeRef);
- `remove-attribute` removes the attribute's name, equals, expression, and
  owned trivia;
- `rename-attribute` changes the attribute name;
- `insert-block` adds a block (type, labels, and a nested body whose
  attributes are typed literal-complete values) to a target body;
- `remove-block` removes a block by exact NodeRef.

Values are supplied as typed native facts or validated literal-complete
values, never as raw markup and never as unevaluated expression text.
Expression-AST editing and inserting derived expressions are explicit v1
non-goals (Section 14). The tfvars profile does not publish the block
operations.

Edits operate on the source like RFC 0012: they replace text only within
operation-owned spans, keep every untouched byte, reparse the target, and
verify the promised HCL semantics. Conflict validation covers wrong
profile/role/snapshot, missing or duplicate target, stale anchors,
overlapping source ownership, duplicate-attribute creation,
`hcl.tfvars@1` block insertion, unrepresentable values, limit failure, and
reparse failure. Success returns the new Document, ChangeSet,
`UntouchedByteProof`, and a replayable `SourcePatch`; failure returns none.
Dry-run and commit have identical replacement sets and target digest. No
operation writes a filesystem path, and none evaluates anything (hard
gate 1).

## 11. Resource and failure contract

`HclParseLimits` bounds at least:

- raw bytes and decoded scalars;
- body nesting depth (blocks), expression depth, and template nesting
  depth;
- attribute, block, label, and body-item counts;
- identifier, string, number (canonical-decimal digit count), template,
  and heredoc byte lengths;
- tuple/object element counts and for-expression extent;
- recovery regions, error regions, and diagnostics;
- projection, materialization, and edit node counts and report events.

All size arithmetic is checked before allocation, and limit failure never
masquerades as an empty body, truncated expression, shortened query,
partial target, or successful edit (hard gate 4 discipline). Both profiles
are side-effect free: formation, query, projection, materialization, and
edit never evaluate an expression, resolve a variable or function, execute a
template directive or for-expression, fetch a URI, read environment or
locale state, consult a Terraform schema, write files, or invoke application
code.

Stable diagnostics cover source contract violations (BOM —
`hcl.parse.byte-order-mark@1`, invalid UTF-8 —
`hcl.parse.invalid-utf8@1`, lone CR — `hcl.parse.lone-cr@1`), token and
grammar errors, duplicate attributes, unterminated
strings/heredocs/interpolations, unclosed delimiters, expression errors,
the tfvars block restriction, every limit, projection non-literalness and
unrepresentability, materialization representability, and edit
conflicts. The `hcl.*` diagnostic codes are registered by this RFC and are
part of the `hcl.native@1` and `hcl.tfvars@1` contracts. Codes follow the
`hcl.<phase>.<name>@1` naming pattern of the RFC 0011 registry:
`hcl.parse.*@1` covers native grammar diagnostics,
`hcl.tfvars.*@1` covers the tfvars profile restriction,
`hcl.limit.*@1` covers resource limits, and
`hcl.projection.*@1`, `hcl.materialization.*@1`, and `hcl.edit.*@1` cover
their operations. They do not enter the `consema-protocol` core error
registry, which covers only core/protocol and line-format contract codes
(RFC 0011 Section 10); when HCL diagnostics are externalized through the
protocol they follow RFC 0011's error-code classification rules, exactly as
RFC 0012 Section 12 does for `xml.*`.

## 12. Rust backend boundary and differential contract

There is no third-party HCL parser backend. The tokenizer, body/expression
grammar, recovery, and all downstream operations are Consema-owned; no
backend type, token, span, AST, or error crosses the public API, and no
dependency change can change a Profile, diagnostic, query order, projection,
generated byte, or conformance result. (The `hcl-rs` crate was considered
and rejected: it is not a HashiCorp release, tracks a partial spec surface,
and would make the contract backend-defined. The rejection does not turn
on its maintenance state — the crate remains actively maintained (v0.19.7,
a single maintainer) — because the binding constraints are that the
contract must be Consema-owned, not defined by a third-party release, and
unevaluated by design, whereas `hcl-rs` is evaluation-oriented (it models
cty-style values).)

The mandatory differential gate runs against the pinned Go
`hashicorp/hcl` parser (`hclsyntax.ParseConfig` / `hclparse.ParseHCL`, and
`hclsyntax.ParseExpression` for expression fixtures) at a pinned commit
with a pinned Go toolchain on a pinned runner. The oracle is used for
syntax acceptance/rejection only: parse outcome versus the Profile's
Complete/Recovered outcome on every fixture, expression acceptance, and
token-level disagreement reports. cty evaluation is never invoked; the
oracle never produces a value, and Consema never compares evaluated
results. Oracle platform, toolchain version and digest, invocation flags,
input digests, expected outputs, and every exclusion are pinned.

The exclusions record the documented divergences of this RFC. Shape-level
exclusions — recovery-region boundary shape (Consema's deterministic
expression recovery of Section 3 versus the Go parser's internal recovery),
duplicate-attribute treatment (both reject; exclusion only if piece shapes
differ), and attribute/block name sharing (both parse-time structures
accept it; expected-no-divergence exclusion) — are recorded in the
manifest. The spec-vs-implementation divergence inventory is:

- **Leading BOM** — the oracle strips it silently (`stripUTF8BOM` in
  `scanTokens`); Consema forms Recovered with
  `hcl.parse.byte-order-mark@1` (Section 2), because the specification
  forbids BOMs.
- **Lone CR** — the oracle rejects it (`Newline = '\r'? '\n'`, so a lone CR
  is an invalid token and a parse error); Consema forms Recovered with
  `hcl.parse.lone-cr@1` (Section 2). The outcomes are equivalent: a lone CR
  never appears in a Complete document under either parser.
- **Invalid UTF-8** — the oracle reports a parse error; Consema makes
  formation FatalFormationFailure with `hcl.parse.invalid-utf8@1`,
  following the invalid-byte-decoding precedent of RFC 0012/0013
  (Section 2). Both parsers refuse the source.
- **`_foo` underscore-leading identifiers** — the oracle accepts them (its
  scanner's `Ident` rule admits a leading underscore); Consema rejects them
  as a grammar error (Recovered), because the specification's
  `Identifier = ID_Start (ID_Continue | "-")*` excludes `_` as a start
  character.
- **`foo.0` numeric attribute access** — the oracle accepts it in
  expressions as an HIL-inherited form (a number after a dot is an
  attribute step, "a weird way of writing [n]"); Consema rejects it as a
  grammar error (Recovered), because the specification's
  `GetAttr = "." Identifier` admits only identifiers.
- **`foo::bar()` namespaced function calls** — the oracle accepts function
  names that are "a series of valid identifiers separated by `::`";
  Consema rejects them as a grammar error (Recovered), because the
  specification's `FunctionCall = Identifier "(" arguments ")"` has no
  namespace form.
- **Single-identifier for-directive** — the oracle accepts `%{ for x in
  list }` (the key is read only when a comma follows); Consema freezes the
  implementation behavior, so the single-identifier form is valid
  (Section 4.4), although the specification's TemplateFor production
  requires both identifiers.
- **Heredoc closing-line whitespace** — the oracle matches the closing
  line with `bytes.TrimSpace`, accepting tabs and trailing whitespace;
  Consema freezes the implementation behavior (Section 4.5), which is
  broader than the specification's "arbitrary number of spaces preceding"
  the marker.
- **EOF-terminated body item** — the implementation accepts end of file as
  the terminator of the last attribute, block, or one-line block, although
  the specification's grammar shows a `Newline` terminator; Consema
  freezes the implementation behavior (Section 4.2).

This inventory is exhaustive for the divergences stated in this RFC. A
differential disagreement cannot be resolved by changing Consema behavior
without an RFC or by adding an untracked allowlist. Terraform's
loader-level rules (static-only tfvars values, undeclared-variable
rejection, block rejection messages) are recorded in the manifest as
application-layer behavior, not oracle outcomes (hard gate 3).

## 13. Conformance evidence and hard gates

The 0.11.0 release gate requires language-neutral vectors covering at
least:

- token facts: identifier matrix (ASCII, Unicode letters, digits, hyphen,
  leading-digit and leading-underscore rejection, keyword spellings as
  attribute and block names such as `true = 1`), number matrix
  (decimal/exponent/sign edges, hex/octal/binary/underscore rejection,
  `+1` rejection), keywords, comments (`#`, `//`, `/* */`, nesting
  rejection, comment-as-newline, inline comment spanning lines), newline
  matrix (LF, CRLF, lone CR);
- body: attributes, blocks, labels (quoted/naked), one-line blocks,
  duplicate attributes, attribute/block name sharing, empty bodies,
  EOF termination;
- expressions: every operator and precedence edge, the unary compound
  matrix (`-1 + 2`, `2 * -1`, `-1 * 2`, `!!x`), unary minus/`!`, `? :`,
  parens with embedded newlines, function calls with trailing comma and
  `...`, traversals, index, both splat forms, for-expressions with guards
  and grouping, tuple/object constructors with newline separators and
  trailing commas, duplicate object keys, the `for`-as-key ambiguity;
- templates and heredocs: escapes (`\u`, `\U`, invalid escapes),
  interpolations with and without strip markers (`${...}`, `${~...~}`),
  directives with strip markers, the single-identifier for-directive,
  `$${`/`%%{` escapes, `<<` and `<<-` modes, marker rules (including
  TrimSpace closing-line matching), unterminated forms;
- tfvars: attribute-only bodies, block rejection, full-expression grammar
  inside values;
- recovery: every Section 3 boundary and error region shape;
- query, projection (literal-complete matrix, derived-expression failure,
  `ProjectExpression` policy with `hcl.expression@1`), both canonical
  materializations with reparse closure, all six edit operations with
  dry-run/commit equivalence, untouched proof, and patch replay;
- adversarial gates: expression depth, template and heredoc size,
  number digit count, body nesting, item counts, arithmetic overflow;
- production-shaped fixtures: Terraform-like `.tf` and `.tfvars`
  documents (module, resource, variable, locals shapes) and HCL-using
  project files (Packer, Nomad, Vault shapes) without secrets or unclear
  licenses;
- the differential manifest of Section 12.

The four roadmap hard gates (roadmap §14.10) map to sections as follows:

1. **Parse/project/query/edit never execute variable, function, or
   template** (Sections 2-10): expressions are AST facts with exact source
   text; no evaluator exists in any operation; literal-completeness is a
   purely syntactic predicate (Section 8.1); materialization and edit
   reparse-verify without evaluating.
2. **Application schema does not enter the generic HCL semantic model**
   (Sections 1, 5, 6, 7): the model is schema-free; there are no variable
   declarations, types, providers, or Terraform roles; projection is
   structural, with no schema-driven mapping.
3. **Terraform-specific interpretation never masquerades as HCL format
   facts** (Sections 2, 5, 11, 12): the tfvars block restriction is a
   profile rule with documented Terraform provenance; Terraform's
   static-only and undeclared-variable rules are recorded as application
   behavior and never replicated at formation; differential exclusions are
   exhaustive for the divergences stated in this RFC.
4. **Projection of non-literal expressions explicitly fails or uses an
   authorized ExtendedValue** (Section 8): failure is atomic with
   `hcl.projection.non-literal-expression@1`; the only authorized path is
   the explicit `ProjectExpression` policy producing `hcl.expression@1`,
   with report events; no silent degradation exists.

## 14. Explicit non-goals

Consema 0.11.0 HCL support does not provide:

- evaluation of any kind: variable lookup, function calls, template
  interpolation and directives, conditional evaluation, arithmetic, or
  for-expression iteration; "evaluation" is not a Consema operation;
- the `cty` value system, arbitrary-precision arithmetic beyond the
  bounded canonical-decimal contract, or any value-level type checking;
- application schema: variable declarations, resource/data/module typing,
  provider schema, `terraform`/`required_providers` interpretation, or any
  Terraform config loading (`terraform.tfvars` auto-load, `.auto.tfvars`
  naming, `-var-file` precedence are CLI/application-layer conventions,
  never Consema facts);
- Terraform's static-only tfvars rule and undeclared-variable rejection at
  formation (Section 5);
- the JSON-based HCL syntax (`.tf.json`, `*.auto.tfvars.json`, the `hcl
  json` package), which is a separate syntax system;
- HCL1 (the legacy `github.com/hashicorp/hcl` v1 grammar) and quoted
  heredoc markers, which are absent from the current specification
  (Section 4.5);
- expression-AST editing, derived-expression insertion, and editing that
  would require evaluation;
- formatting existing sources, semantic diff/merge, incremental parse,
  include/import resolution, filesystem transactions, stable process
  plugins, or Go (Go arrives with roadmap phase 0.18.0);
- any projection convention that renders derived expressions as strings or
  silently folds them into values (roadmap §5.3).

## 15. Rejected alternatives

- **Treat HCL as a JSON superset and parse it into a generic Object
  tree:** rejected because HCL has no JSON type correspondence (blocks and
  labels are not key/value pairs, expressions are not strings), and the
  unevaluated-expression identity the roadmap requires (roadmap §9.7)
  would be destroyed by any value-tree mapping.
- **Keep expressions only as raw text spans:** rejected because query
  (kind, children, literal predicate) and structural equality need the AST;
  the model keeps both the AST and the exact span-derived text (Section 6).
- **Keep expressions only as AST and lose raw spelling:** rejected because
  exactness of trivia, escapes, heredoc markers, and number spelling is a
  format fact the immutable source provides for free.
- **Project derived expressions as strings by default:** rejected because
  a string rendering pretends evaluation happened (roadmap §5.3: HCL
  expressions are never placed into a String and passed off as evaluated).
- **Fold constant arithmetic (`1 + 2`) into the literal-complete set:**
  rejected because that requires an evaluator and silently computes;
  literal-completeness stays a syntactic, evaluation-free predicate
  (Section 8.1).
- **Freeze Terraform's static-only rule at tfvars formation:** rejected
  because the rule is Terraform's evaluation policy; rejecting function
  calls at formation would make Terraform's loader behavior a format fact
  (hard gate 3) and would require an evaluator to classify expressions.
- **Allow blocks in `hcl.tfvars@1`:** rejected because Terraform rejects
  them ("Blocks are not allowed here"); the profile exists to model the
  Terraform variable-file document type, and a block would be a
  contradiction in a Complete tfvars Document.
- **Adopt the Go parser or `hcl-rs` as the backend:** rejected because
  the contract must be spec-frozen and Consema-owned; the Go parser serves
  as a pinned differential oracle only (Section 12).
- **Freeze a lenient source contract (accept BOM, lone CR):** rejected
  because the specification excludes both; strictness is deterministic and
  recorded as differential exclusions.
- **Add hex, octal, binary, or underscore-separated numbers:** rejected
  because the specification defines decimal-only numeric literals;
  inventing extra literals would make Consema accept files HashiCorp's
  parser rejects.
- **Evaluate templates during parse to normalize heredoc indentation:**
  rejected because `<<-` stripping and directive processing are evaluation;
  mode, marker, and indentation are preserved representation facts
  (Section 4.5).
- **Model one `hcl@1` profile with a lenient mode for tfvars:** rejected
  because the tfvars structural restriction is a hard document-type fact
  with its own diagnostics, limits, and operations; one profile would blur
  the distinction the roadmap's mandatory pair requires.

## 16. Roadmap mapping

- §4.2: the two mandatory profiles `hcl.native@1` and `hcl.tfvars@1` and
  their core truths — body, attribute, block, expression, template, no
  implicit evaluation — map to Sections 1, 4-6.
- §4.4: the document/value/program separation is realized by the
  unevaluated contract (Section 6) and the literal-complete boundary
  (Section 8); evaluation languages and executable configuration remain
  outside the format core.
- §4.5: the admission criteria are answered by this RFC: frozen grammar
  (Section 4), realistic usage (Terraform-family fixtures, Section 13),
  native semantic view (Section 6), lossless syntax coverage (Section
  7.2), PortableValue/ExtendedValue relationship (Section 8), the four
  operation boundaries (Sections 7-10), legal/invalid/recovery/malicious
  corpora (Section 13), dual-language implementability (Rust now, Go at
  0.18.0), no permanent-invariant breakage, maintenance/versioning policy
  (RFC 0011 registry discipline, Section 11), static-format identity
  (Section 14), and no pseudo-lossless round trip (reparse closure,
  Section 9).
- §5.3: HCL expressions never enter PortableValue as strings; derived
  expressions live only in the native view or in `hcl.expression@1`
  (Section 8).
- §5.5 and §14.10: `hcl.expression@1` is the explicitly preserved
  unevaluated-expression ExtendedValue with formal TypeId, version,
  equality, and encoding contracts and its own conformance vectors.
- §7.1: `hcl.lossless-syntax-query@1` is provided (Section 7.2) alongside
  the native domain.
- §9.7: the preservation list — body/attribute/block type/labels/nested
  body (Section 4.2), full expression and template syntax identity
  (Sections 4.3-4.6), literal-versus-derived distinction (Section 8.1),
  comments/trivia/source ranges (Sections 2, 7.2), HCL's own duplicate
  attribute constraint (Section 3), and block order and identity (Section
  6) — is implemented; the non-default list (no variable lookup, function
  call, template interpolation, include/import, provider/schema
  interpretation, or application evaluation) is Section 14.
- §14.10: the 0.11.0 deliverable list maps to Sections 4-10 and 12-13,
  including the differential suite and the expression-depth/template/
  heredoc adversarial corpus; the four hard gates are mapped in
  Section 13.
