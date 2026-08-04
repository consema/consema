# JSON5 v2.2.3 upstream reference gate

Consema 0.6.0 pins the official [JSON5 repository](https://github.com/json5/json5) at tag `v2.2.3`, commit `c3a75242772a5026a49c4017a16d9b3543b62776`. This gate is external evidence for the accepted and rejected Standard JSON5 syntax surface; it does not import JavaScript evaluation, binary64 rounding, duplicate-member collapse, or implementation-private AST behavior.

## Stored evidence

- `conformance/corpora/json5-v2.2.3.json` records 43 accepted and 39 rejected inputs derived from upstream `test/parse.js` and `test/errors.js`;
- `conformance/fixtures/json5/package-json5-v2.2.3.json5` stores the complete upstream `package.json5` as a realistic accepted fixture;
- `conformance/corpora/licenses/json5-MIT.txt` stores the upstream MIT license;
- upstream tag commit: `c3a75242772a5026a49c4017a16d9b3543b62776`;
- upstream fixture Git blob SHA-1: `322bed5576031badba3383fe7343d39d21292942`;
- stored fixture Git blob SHA-1: `d22ccc6cfbe4fec92c31d0512e311a7638a4ac4c`;
- stored fixture SHA-256: `ef3136abec4e0a19f610e39c7654dda5a06fee242ab8012df87d7ad9911411ad`.

The upstream fixture uses CRLF. Repository `.gitattributes` normalizes it to LF; the line-ending code points are the only content difference. Both blob identities and the transform are recorded instead of presenting the normalized file as byte-identical upstream content.

## Acceptance rule

`consema_conformance::run_json5_reference_corpus()` must:

1. accept all 43 valid inputs as complete `json5.standard@1` documents;
2. reject all 39 invalid inputs without panic or partial success;
3. parse and render the complete fixture byte-exactly in its stored LF form;
4. validate suite identity, upstream metadata, case identity, counts, digests and license location.

The 0.6.0 release gate passes all 83 checks. The external corpus also exposed an invalid escaped identifier-continuation panic during development; the parser now rejects that path normally, and a dedicated regression test prevents recurrence.
