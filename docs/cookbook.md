# Consema CLI Cookbook（0.12.0）

本文是任务导向的 `consema` CLI 配方集。每条配方的命令都在 0.12.0 开发工作区
（Windows 11 Pro 10.0.26200，`target/release/consema.exe`）上实际执行过，
输出按原样粘贴。命令与输出中的路径以你的实际环境为准；请求文件内容（RFC
0015 §3.2 严格解码的 canonical tagged JSON）逐字节给出，复制即用。

机器可读输出、exit code 语义与命令边界的权威定义见
`docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md`、
`docs/IMPLEMENTATION.md` 第 14 章与 `docs/0.13.0-gate-plan.md` §4 M4 的
API 评审 backlog。

## 1. 前置：构建、版本与帮助

```text
cargo build --release --locked -p consema
```

```text
$ consema --version
0.8.0

$ consema --help
consema 0.8.0 — deterministic multi-format configuration tool
Usage:
  consema [global options] <command> [args...]
  consema --help | --version

Commands (RFC 0015 §6.1):
  inspect        file facts (bytes/digest/encoding facts/candidate profiles)
  capabilities   facade capability inventory
  query          native/lossless query (request via --request-file or stdin)
  project        explicit projection request
  materialize    explicit materialization request
  convert        two-phase cross-format conversion
  edit           single-file structural edit (dry-run; --write commits)
  plan           batch plan manifest (read-only)
  apply          batch apply from a prior plan manifest
  conformance    embedded protocol self-check subset
  explain        authoritative contract/error-code/profile explanation

Global options:
  --json              emit the core.cli-output@1 machine envelope on stdout
  --pretty            indent the envelope JSON (requires --json)
  --profile <id>      explicit profile selection (required for parse-class
                      commands); --format is an alias
  --output <path>     result or manifest write target
  --request-file <path>  strict request input (query/project/materialize/
                         convert/edit/plan)
  --max-bytes <n>     CLI-layer per-file read budget in bytes
  --max-files <n>     CLI-layer batch file-count budget
  --redact-keys <glob>  extra redaction key-name patterns
  --show-secrets      reveal secret values (sole presentation opt-out)
  --write             commit an edit (edit only)
  --help              print this help and exit 0
  --version           print the product version and exit 0

Exit codes (RFC 0015 §5.1): 0 success, 1 usage, 2 data, 3 limit,
4 precondition, 5 internal; 6-255 reserved.
```

两个全局纪律（RFC 0015 §3.3）：`--json` 下 stdout 只有一行规范 JSON
信封，其余一切走 stderr；没有任何命令在无显式参数时写目标文件。

## 2. 检查一个文件：`consema inspect`

`inspect` 只报告**事实**，从不猜测格式（硬门禁 2）。对
`application.json5`（前导字节是 `{`）：

```text
$ consema inspect application.json5
consema inspect application.json5
  bytes: 410 bytes sha256:30c07b89db0fecd9b465835e8bf5a06e69d68ff8a195a1be3a18fbbfe0b1fa1a
  bom: none
  symlink: no
  markers: first non-whitespace '{'
  candidates: json.strict@1 (first non-whitespace byte is '{'); json5.standard@1 (first non-whitespace byte is '{'); jsonc.bounded@1 (first non-whitespace byte is '{')
  ambiguous: yes: first non-whitespace '{' is consistent with multiple profiles of the json family
```

歧义是一等结果：报告完整，exit 0。对 `key=value` 形状的文件，候选是
INI 与 Java Properties 五个 Profile：

```text
$ consema inspect json5ish.conf
consema inspect json5ish.conf
  bytes: 40 bytes sha256:a7deff2dc8337cae8e071c31a012e06e336c7143877f300dfb897d0ace8c0fb2
  bom: none
  symlink: no
  markers: key=value line
  candidates: ini.portable@1 (leading key=value line); ini.python-configparser@1 (leading key=value line); ini.windows@1 (leading key=value line); java-properties.latin1@1 (leading key=value line); java-properties.reader@1 (leading key=value line)
  ambiguous: yes: key=value line is consistent with format families: ini, java-properties
```

显式 `--profile` 时附加 parse 事实（formation 状态、诊断、结构计数）：

```text
$ consema inspect package.json --profile json.strict
consema inspect package.json
  bytes: 424 bytes sha256:06d760863d6c0c66e119747d74a116c12a365315cb423ce3108f4f2b10089a13
  bom: none
  symlink: no
  markers: first non-whitespace '{'
  candidates: json.strict@1 (first non-whitespace byte is '{'); json5.standard@1 (first non-whitespace byte is '{'); jsonc.bounded@1 (first non-whitespace byte is '{')
  ambiguous: yes: first non-whitespace '{' is consistent with multiple profiles of the json family
  parse (json.strict@1): Complete
    diagnostics: none
    structure counts: json.object_members: 9
```

文件不可读是 data 类失败（exit 2，`cli.data.io@1`）；超出 `--max-bytes`
预算读限是 limit 类失败（exit 3，`cli.limit.file-size@1`）。

## 3. 查询配置：`consema query`

`query` 消费严格请求（`--request-file` 或 stdin，canonical tagged JSON 或
PVCE/1），执行 `core.query-definition@1`。请求格式
（`cli.request@1` 包装，源可以是路径或内联 hex 字节）：

`query-request.json`（源为相对路径 `package.json`；注意：文件不能有尾随
换行，canonical JSON 字节形式是严格判定的）：

```json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.request@1"}},{"key":"source","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"path"}},{"key":"path","value":{"type":"String","value":"package.json"}}]}},{"key":"profile","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"json.strict"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"payload","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.query-definition@1"}},{"key":"domain_id","value":{"type":"String","value":"core.portable-value-query"}},{"key":"domain_version","value":{"type":"Integer","value":"1"}},{"key":"selection","value":{"type":"String","value":"All"}},{"key":"expression","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"Apply"}},{"key":"input","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"Input"}}]}},{"key":"operator","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"core.try-object-entries"}},{"key":"version","value":{"type":"Integer","value":"1"}},{"key":"arguments","value":{"type":"Object","entries":[]}}]}}]}}]}}]}}
```

```text
$ consema query --profile json.strict --request-file query-request.json
match 0: $.name (key name) = "consema-fixture-app"
match 1: $.version (key version) = "1.0.0"
match 2: $.private (key private) = true
match 3: $.type (key type) = "module"
match 4: $.scripts (key scripts) = {build: "tsc -p tsconfig.json", check: "tsc --noEmit", test: "node --test"}
match 5: $.engines (key engines) = {node: ">=20"}
match 6: $.dependencies (key dependencies) = {fastify: "4.28.1"}
match 7: $.devDependencies (key devDependencies) = {typescript: "5.6.3"}
```

选择器 `RequireOne`（恰一个匹配，fail-not-null）违反时是 data 类失败
（exit 2，`core.query.cardinality-violation@1`）。Recovered 文档不可查询
（exit 2，报告完整诊断）。native 查询域（如 `json.native-semantic-query@1`）
与本版本的 xml/plist/hcl 源在 query 上未接线，显式拒绝而非不完整结果
（0.13.0 API 评审项，见第 10 节）。

机器模式：`--json` 时 stdout 只有一行 `core.cli-output@1` 信封：

```text
$ consema query --profile json.strict --request-file query-request.json --json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.cli-output@1"}},{"key":"command","value":{"type":"String","value":"query"}},{"key":"exit_class","value":{"type":"String","value":"success"}},{"key":"product_version","value":{"type":"String","value":"0.8.0"}},{"key":"payload","value":{"type":"Object","entries":[...]}},{"key":"diagnostics","value":{"type":"Sequence","items":[]}},{"key":"redaction","value":{"type":"Object","entries":[{"key":"redacted","value":{"type":"Boolean","value":false}},{"key":"count","value":{"type":"Integer","value":"0"}}]}}]}}
```

## 4. 显式投影：`consema project`

`project` 消费 `core.projection-request@1`，默认 policy 是保守的
exact-or-reject（CLI 不发明 loss 授权）。请求的 `cli.request@1` 包装同
第 3 节，payload 为 `core.projection-request@1`（目标 + 默认 policy +
空 rules/limits）。请求文件 `project-request.json`（目标
`json.projection.best-exact-core@1`）：

```json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.request@1"}},{"key":"source","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"path"}},{"key":"path","value":{"type":"String","value":"package.json"}}]}},{"key":"profile","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"json.strict"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"payload","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.projection-request@1"}},{"key":"target","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"json.projection.best-exact-core"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"default_policy","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"core.projection.exact-or-reject"}},{"key":"version","value":{"type":"Integer","value":"1"}},{"key":"arguments","value":{"type":"Object","entries":[]}}]}},{"key":"rules","value":{"type":"Sequence","items":[]}},{"key":"limits","value":{"type":"Object","entries":[]}}]}}]}}]}
```

```text
$ consema project --profile json.strict --request-file project-request.json
{name: "consema-fixture-app", version: "1.0.0", private: true, type: "module", scripts: {build: "tsc -p tsconfig.json", check: "tsc --noEmit", test: "node --test"}, engines: {node: ">=20"}, dependencies: {fastify: "4.28.1"}, devDependencies: {typescript: "5.6.3"}, tooling: {coverage: true, thresholds: [90, 85, 80]}}
```

机器模式（`--json`）下同一结果的 envelope 开头（payload 为
`core.projection-result@1`：completion + 完整 PortableValue + fidelity +
report + provenance）：

```json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.cli-output@1"}},{"key":"command","value":{"type":"String","value":"project"}},{"key":"exit_class","value":{"type":"String","value":"success"}},{"key":"product_version","value":{"type":"String","value":"0.8.0"}},{"key":"payload","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.projection-result@1"}},{"key":"completion","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.completion@1"}},{"key":"status","value":{"type":"String","value":"Success"}},{"key":"processed","value":{"type":"Integer","value":"1"}},{"key":"produced","value":{"type":"Integer","value":"1"}},{"key":"limit_name","value":{"type":"Null"}},{"key":"failure_code","value":{"type":"Null"}}]}},{"key":"value","value":{"type":"Object","entries":[{"key":"portable_value","value":{"type":"Object","entries":[{"key":"name","value":{"type":"String","value":"consema-fixture-app"}},{"key":"version","value":{"type":"String","value":"1.0.0"}},{"key":"private","value":{"type":"Boolean","value":true}},{"key":"type","value":{"type":"String","value":"module"}},...]}}]}}]}}]}}
```

`project` 的报告/来源外部化本版本只接线 json 与 toml 两家族（其余家族
显式拒绝；TOML 非空报告同样拒绝）——见第 10 节边界清单。

## 5. 跨格式转换：`consema convert`

`convert` 是"投影 + 物化"两阶段的显式组合（facade `convert_*` 组合层，
含 record-consumption gate 与 reparse closure）。源是位置参数，请求是
`cli.convert-request@1`（含两阶段的具体 target）。JSON → TOML 示例：

`convert-request.json`（源 `package.json`，`--profile json.strict`，目标
`toml.1.0`/`toml.canonical-document`，映射政策
`UniqueStringEntriesToObject`）：

```json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.convert-request@1"}},{"key":"projection_request","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.projection-request@1"}},{"key":"target","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"json.projection.best-exact-core"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"default_policy","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"core.projection.exact-or-reject"}},{"key":"version","value":{"type":"Integer","value":"1"}},{"key":"arguments","value":{"type":"Object","entries":[]}}]}},{"key":"rules","value":{"type":"Sequence","items":[]}},{"key":"limits","value":{"type":"Object","entries":[]}}]}},{"key":"materialization_request","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.materialization-request@2"}},{"key":"target_profile","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"toml.1.0"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"style","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"toml.canonical-document"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"encoding","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.source-encoding@1"}},{"key":"kind","value":{"type":"String","value":"Utf8"}},{"key":"windows_code_page","value":{"type":"Null"}}]}},{"key":"newline","value":{"type":"String","value":"Lf"}},{"key":"mapping_policy","value":{"type":"String","value":"UniqueStringEntriesToObject"}},{"key":"representability","value":{"type":"String","value":"ExactOnly"}},{"key":"limits","value":{"type":"Object","entries":[{"key":"max_input_nodes","value":{"type":"Integer","value":"1000000"}},{"key":"max_output_bytes","value":{"type":"Integer","value":"67108864"}},{"key":"max_depth","value":{"type":"Integer","value":"256"}},{"key":"max_report_entries","value":{"type":"Integer","value":"100000"}},{"key":"max_provenance_entries","value":{"type":"Integer","value":"2000000"}}]}}]}}]}}
```

```text
$ consema convert package.json --profile json.strict --request-file convert-request.json
"name" = "consema-fixture-app"
"version" = "1.0.0"
"private" = true
"type" = "module"
"scripts" = { "build" = "tsc -p tsconfig.json", "check" = "tsc --noEmit", "test" = "node --test" }
"engines" = { "node" = ">=20" }
"dependencies" = { "fastify" = "4.28.1" }
"devDependencies" = { "typescript" = "5.6.3" }
"tooling" = { "coverage" = true, "thresholds" = [90, 85, 80] }
```

convert 目标字节只到 stdout：本构建对 `--output` 显式拒绝（usage 类错误
exit 1，`cli.usage.invalid-argument@1`，"file writing lands with fsio in
milestone M6"），落盘请用 shell 重定向。全部 8 个格式家族都可作 convert
源/目标；record 家族（xml/plist/hcl）只能由本家 materializer 消费
内部 record（record-consumption gate），例如 HCL tfvars → HCL canonical：

```text
$ consema convert terraform.tfvars --profile hcl.tfvars --request-file hcl-convert-request.json
region = "us-east-1"
instance_type = "t3.micro"
ami = "ami-0abcdef1234567890"
instance_count = 2
monitoring = true
tags = {
```

### 5.1 loss policy 示例（§22.6：每个可转换组合）

CLI 的默认投影 policy 是 exact-or-reject（未授权 loss 即失败），规则/命名
limit 未接线——因此 loss policy 在 CLI 上的可观察形态是**显式拒绝**与
**报告转换**，没有静默降级：

- **YAML 图 → 树（sharing/cycle 未授权）**：`&root [one, *root]` 转换到
  JSON 原子失败：

```text
$ consema convert cyc.yaml --profile yaml.1.2-core --request-file yaml-to-json-request.json
consema: error: convert: conversion failed atomically (core.conversion.projection-failed@1) (code core.conversion.projection-failed@1)
```

  失败形态：无目标文档、无部分字节；信封携带失败记录
  `{schema: cli.convert@1, report: null, target: null}` 与诊断（第 10 节
  边界 5 的已记录行为）。

- **INI 重复 section（duplicate policy 在 formation 执行）**：`[a]` 重复
  使文档 Recovered，convert 需要 Complete 文档 → 失败：

```text
$ consema convert dup.ini --profile ini.portable --request-file ini-to-toml-request.json
consema: error: convert: source 'dup.ini' is Recovered; the operation requires a Complete document (code ini.formation.duplicate-section@1)
```

- **plist binary UID → 树形 target**：UID 只在显式 `IncludeUid` policy 下
  投影，exact-or-reject 默认拒绝：

```text
$ consema convert com.example.archiver-sample.binary.plist --profile plist.binary --request-file plist-to-json-request.json
consema: error: convert: conversion failed atomically (core.conversion.projection-failed@1) (code core.conversion.projection-failed@1)
```

- **EntryMapping → Object 的报告转换**：materialization 的
  `mapping_policy` 字段显式选择（`RequireObject` 或
  `UniqueStringEntriesToObject`）；转换结果经两阶段 fidelity/report 报告，
  成功时输出目标字节（第 5 节 JSON→TOML 例即该路径）。

## 6. 批量修改：`consema plan` + `consema apply`

`plan` 是只读的批量规划器：逐文件 parse + edit dry-run，产出
`core.batch-plan@1` manifest（`--output` 落盘或 stdout）。单文件失败作为
manifest 内容如实记录（`failed` 条目），`plan` 仍 exit 0——不是整批失败，
也不是伪装成功。**plan manifest 是产物，不是写授权**。

编辑请求（`cli.edit-request@1`，本版本词表是 INI family 操作）：

`edit-request.json`（把 `[window]` 节的 `width` 改为 1600，dry-run
语义 = 与未来 commit 相同的 replacements 与 target digest）：

```json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.edit-request@1"}},{"key":"operations","value":{"type":"Sequence","items":[{"type":"Object","entries":[{"key":"operation","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"ini.edit.replace-semantic-value"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"target","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"entry"}},{"key":"section","value":{"type":"String","value":"window"}},{"key":"key","value":{"type":"String","value":"width"}},{"key":"occurrence","value":{"type":"Integer","value":"0"}}]}},{"key":"arguments","value":{"type":"Object","entries":[{"key":"value","value":{"type":"String","value":"1600"}},{"key":"representation_policy","value":{"type":"String","value":"preserve-compatible"}}]}}]}]}}]}}
```

单文件 dry-run：

```text
$ consema edit desktop-settings.ini --profile ini.portable --request-file edit-request.json
edit dry-run (ini.portable): desktop-settings.ini
  ini.edit.replace-semantic-value@1 on entry 'window':'width'  value=1600 representation_policy=preserve-compatible
  base b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8 target 98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a replacements: 1
  committed: no
```

100 文件批量规划（文件清单是位置参数；glob 由 shell 展开——Git Bash 展开
`settings-*.ini`，PowerShell/cmd 需显式列出文件或自行展开）：

```text
$ consema plan settings-*.ini --profile ini.portable --request-file edit-request.json --output plan.json
consema plan: 100 file(s)
  settings-001.ini: planned
    ini.edit.replace-semantic-value@1 on entry 'window':'width'  value=1600 representation_policy=preserve-compatible
    base sha256:b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8 target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a replacements: 1
  ...
```

`apply` 消费先前 `plan` 的 manifest（不接受裸操作）：逐文件重读重验
base digest 与 original-bytes 双前置条件，通过后同目录临时文件 + 原子替换
+ 读回验证 target digest，产出 `core.batch-result@1`：

```text
$ consema apply plan.json --output result.json
consema apply: 100 file(s)
  settings-001.ini: completed (target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a)
  ...
```

- 全部 completed → exit 0；任何 Failed/SkippedStale 条目 → exit 4
  （precondition 类）；中断（Ctrl+C）→ exit 4 且 stdout 无输出、pending
  manifest 留在磁盘，重跑同一 plan 恢复（completed 跳过、pending 重做）。
- 写入前文件被外部修改（stale digest）时该文件 `skipped-stale` 且完全不写，
  同批其余文件照常完成（跨文件互不影响）：

```text
$ consema apply plan.json --output result.json
consema: error: apply: settings-001.ini: the current file bytes no longer match the planned base digest; the file was not rewritten (code core.source.patch-base-mismatch@1)
consema apply: 2 file(s)
  settings-001.ini: skipped-stale core.source.patch-base-mismatch@1
  settings-002.ini: completed (target sha256:5ece8247aa85df55df46b6a510497f8807efcfc4f02b5e8c35526aadd2f956d0)
```

  注意：exit 4（该批没有完整应用），但被跳过的文件字节分毫未动。

## 7. secret 脱敏与 `--show-secrets`

默认脱敏（保守键名模式，`password` 命中；human 视图与 plan 视图都适用）：

```text
$ consema edit secret.ini --profile ini.portable --request-file redact-request.json
edit dry-run (ini.portable): secret.ini
  ini.edit.replace-semantic-value@1 on entry 'db':'$REDACTED$'  value=$REDACTED$ representation_policy=preserve-compatible
  base 4f2e9cc28e2ba0e1b0b9303283c1f48410ccfb5750a985d72adf3913c25fe1dd target 935ee0c23b7c89a8a9da9b12fc9c9e138b1edb49496401238d8989b68abe7f5d replacements: 1
  committed: no
consema: edit: redacted 2 value(s) in the human view (--show-secrets reveals)
```

`--show-secrets` 是唯一展示取消通道：

```text
$ consema edit secret.ini --profile ini.portable --request-file redact-request.json --show-secrets
edit dry-run (ini.portable): secret.ini
  ini.edit.replace-semantic-value@1 on entry 'db':'password'  value=hunter3 representation_policy=preserve-compatible
  base 4f2e9cc28e2ba0e1b0b9303283c1f48410ccfb5750a985d72adf3913c25fe1dd target 935ee0c23b7c89a8a9da9b12fc9c9e138b1edb49496401238d8989b68abe7f5d replacements: 1
  committed: no
```

安全边界（硬门禁 3）：脱敏只影响展示；plan manifest 记录本身（apply 的
original/replacement 字节前置条件）永不脱敏；机器输出中脱敏值为
`$REDACTED$` 占位并带 `redaction: {redacted: true, count: N}` 事实。
追加模式用 `--redact-keys <glob>`。

## 8. 能力清单与解释：`capabilities` / `explain`

```text
$ consema capabilities
consema capabilities
  families (8): hcl@1, ini@1, java-properties@1, json@1, plist@1, toml@1, xml@1, yaml@1
  profiles (16): hcl.native@1, hcl.tfvars@1, ini.portable@1, ini.python-configparser@1, ini.windows@1, java-properties.latin1@1, java-properties.reader@1, json.strict@1, json5.standard@1, jsonc.bounded@1, plist.binary@1, plist.xml@1, toml.1.0@1, xml.1.0-safe@1, yaml.1.1-compat@1, yaml.1.2-core@1
  query domains (21): ...
  operations (16 registries): ...
  error codes (187): ...
```

清单全部派生自 facade 类型（`registry.rs` 不重复声明格式知识）；
`--json` 输出同源机器记录。单项权威解释：

```text
$ consema explain core.cli-output@1
consema explain contract core.cli-output@1
  kind: contract
  version: 1
  record:
    id: core.cli-output
    version: 1
    stability: Stable

$ consema explain cli.write.symlink-policy@1
consema explain error-code cli.write.symlink-policy@1
  kind: error-code
  version: 1
  record:
    code: cli.write.symlink-policy@1
    category: Edit
    introduced: 0.12.0
    description: Write path rejected by the symlink policy
```

## 9. 内嵌自检：`consema conformance`

发布物内置的自检子集（信封双传输 round-trip、exit 分类；完整语言无关
suite 保持仓库级执行）：

```text
$ consema conformance
consema conformance (consema.cli.conformance@1)
  [PASS] cli.envelope@1
  [PASS] cli.exit-code@1
  [PASS] cli.redaction@1
  3 passed, 0 failed
```

## 10. 每格式能力矩阵与已知边界

| 格式家族（Profile） | inspect | query | project | edit/plan/apply | convert |
|---|---|---|---|---|---|
| json（strict/jsonc/json5） | ✓ | ✓ | ✓ | — | ✓ |
| toml.1.0 | ✓ | ✓ | ✓ | — | ✓ |
| yaml.1.2-core / 1.1-compat | ✓ | ✓ | — | — | ✓ |
| ini（三 Profile） | ✓ | ✓ | — | ✓（INI 词表） | ✓ |
| java-properties（reader/latin1） | ✓ | ✓ | —（见边界 6） | — | ✓ |
| xml.1.0-safe | ✓ | —（native 域未接线） | — | — | ✓ |
| plist.xml / plist.binary | ✓ | —（native 域未接线） | — | — | ✓ |
| hcl.native / hcl.tfvars | ✓ | —（native 域未接线） | — | — | ✓ |

未接线的格都以显式错误拒绝（绝不输出不完整记录）。已知边界与 API 评审
backlog（2026-08-07 复核，disposition 见 `docs/0.13.0-gate-plan.md` §4 M4）：

1. **query 只接线 `core.portable-value-query@1`**：native 域需要调用方外部化
   的 node locator，facade 尚未暴露该 API（xml/plist/hcl 源因此不可经便携域
   查询）。
2. **materialize/convert 的 provenance map 为空**：同因（facade 无 locator
   API），envelope 携带空 map。
3. **project 报告外部化仅 json/toml**：其余家族显式拒绝；TOML 非空报告
   同样拒绝（exact TOML 投影实践中无事件，report 为空）。
4. **格式本地 code 的注册 fallback**：信封只能携带注册 code，XML/plist/HCL
   本地诊断在信封中绑定 `core.source.invalid-sequence@1`，stderr 行保留真码
   （RFC 0015 §4.3 冻结语义）。
5. **失败记录形态**：失败的 `cli.convert@1` 记录携带 `report: null,
   target: null`（typed decoder 拒绝部分记录 = 如实声明无完整结果），失败
   事实在信封诊断中。
6. **java-properties 的 convert 已修复、project 仍拒绝**（2026-08-07 复核
   更新）：`format_family` 对 java-properties 返回 `properties`，而
   `wire_projection_request` 的族前缀检查曾按 `properties.projection.`
   拒绝 `java-properties.projection.*` 目标——convert 侧已随族前缀特例
   修复（实测 `convert build-tool.properties --profile
   java-properties.reader` → JSON 目标 exit 0，见第 12.5 节）；`project`
   仍按边界 3 拒绝（报告/来源外部化仅 json/toml）。
7. **edit 词表仅 INI family**：`edit --write` 亦未接线（dry-run only，
   `--write` 是 usage 错误），批量写经 plan/apply。
8. **inspect 的 Recovered/fatal 报告**（2026-08-07 复核更新）：`inspect
   --profile` 对携带格式本地 code 的诊断（xml/plist/hcl 家族，以及
   category 与注册表矛盾的 INI/Properties 恢复诊断）已从内部错误改为
   正常报告：`inspect bad.xml --profile xml.1.0-safe` 与 `inspect dup.ini
   --profile ini.portable`（Recovered）均 exit 0，stderr 行保留格式本地
   真码（如 `xml.tree.mismatched-end-tag@1`），信封绑定注册 fallback
   （边界 4 语义）。
9. **record 目标 Profile 的请求契约**：plist.binary 目标要求
   `encoding: Binary` 与 `newline: None`（RFC 0013 §10 冻结）；
   json.strict 目标要求 `newline: None`。请求违反契约时材料化原子失败
   （`core.conversion.materialization-failed@1`，exit 2），不会静默改写
   编码或换行（实测见第 12.6 节）。

## 11. exit code 速查（RFC 0015 §5.1，实测对应）

| 码 | 类 | 实测示例 |
|---|---|---|
| 0 | success | 全部完整结果：inspect（含歧义报告）、query 成功、plan（含 failed 条目）、apply 全 completed、conformance、explain、--help/--version |
| 1 | usage | 未知命令/未知参数、缺 `--profile`、`edit --write`（本版本）、非 UTF-8 参数 |
| 2 | data | 请求解码失败（`cli.data.invalid-request@1`）、Recovered 源、cardinality 违反、转换原子失败（`core.conversion.*`）、文件不可读（`cli.data.io@1`） |
| 3 | limit | 超出 `--max-bytes`/`--max-files`/manifest 预算（`cli.limit.*@1`） |
| 4 | precondition | stale digest（`core.source.patch-base-mismatch@1`）、写入失败（`cli.write.*`）、中断（`cli.interrupted.signal@1`） |
| 5 | internal | 未分类内部错误（`cli.internal.unclassified@1`，如 conformance 自检失败） |

## 12. 每格式 CLI 示例矩阵（路线图 §22.6）

本节按格式家族给出一组**实跑**的 inspect/query/project/edit/convert 示例，
补齐第 10 节能力矩阵的命令面证据（2026-08-07，0.12.0 开发工作区，
`target/release/consema.exe` 0.8.0，Windows 11 Pro 10.0.26200）。命令在
`conformance/fixtures/` 的钉版夹具上执行；未接线的格都是显式拒绝（exit 2，
绝不输出不完整记录），拒绝消息本身就是可复制的示例。

请求文件体例与第 3-6 节一致：query/project 用 `cli.request@1` 包装（源与
Profile 在请求内），convert/edit 用裸 payload（源是位置参数、Profile 来自
`--profile`）。每家族的目标 ID 与操作词表见第 12.9 节，全部可由
`consema capabilities` 派生。

### 12.1 json 家族（json.strict / jsonc.bounded / json5.standard）

```text
$ consema inspect application.json5
consema inspect application.json5
  bytes: 410 bytes sha256:30c07b89db0fecd9b465835e8bf5a06e69d68ff8a195a1be3a18fbbfe0b1fa1a
  bom: none
  symlink: no
  markers: first non-whitespace '{'
  candidates: json.strict@1 (first non-whitespace byte is '{'); json5.standard@1 (first non-whitespace byte is '{'); jsonc.bounded@1 (first non-whitespace byte is '{')
  ambiguous: yes: first non-whitespace '{' is consistent with multiple profiles of the json family

$ consema inspect tsconfig.jsonc --profile jsonc.bounded
consema inspect tsconfig.jsonc
  bytes: 428 bytes sha256:c3fa961d9eae747c4b1025cabf8c0dd05b8c7532574db9cb89ec026f1aac7f52
  bom: none
  symlink: no
  markers: first non-whitespace '{'
  candidates: json.strict@1 (first non-whitespace byte is '{'); json5.standard@1 (first non-whitespace byte is '{'); jsonc.bounded@1 (first non-whitespace byte is '{')
  ambiguous: yes: first non-whitespace '{' is consistent with multiple profiles of the json family
  parse (jsonc.bounded@1): Complete
    diagnostics: none
    structure counts: json.object_members: 6
```

query / project / convert 的完整输出见第 3、4、5 节（同一 fixture）。JSON 源
可作任何可表示目标（TOML/YAML/JSON）的源，JSON → TOML、JSON → YAML 均
exit 0（第 5 节与第 12.2 节）。

edit（未接线 → 显式拒绝）：

```text
$ consema edit package.json --profile json.strict --request-file edit-json.json
consema: error: edit: the json edit surface is not wired in this milestone: the request vocabulary maps the ini family only (the facade exposes typed edit transactions for json, but no operation request mapping yet) (code cli.data.invalid-request@1)
```

（`edit-json.json` 为 `cli.edit-request@1` 裸 payload，操作
`json.edit.replace-scalar-semantic@1`，目标 member `version`。该命令 exit 2。
`edit --write` 另见边界 7：usage 错误 exit 1。）

### 12.2 toml.1.0

```text
$ consema inspect pyproject.toml
consema inspect pyproject.toml
  bytes: 524 bytes sha256:5611e9d8f40d3f464ae9e122e288b14f85c62a9cd2c86267a13455b4183cd5ec
  bom: none
  symlink: no
  markers: [section] line
  candidates: ini.portable@1 (leading [section] line); ini.python-configparser@1 (leading [section] line); ini.windows@1 (leading [section] line); toml.1.0@1 (leading [section] line)
  ambiguous: yes: [section] line is consistent with format families: ini, toml
```

`[section]` 前导使 TOML 与 INI 家族歧义——inspect 如实报告，不猜格式；
parse 类命令必须显式 `--profile`。

```text
$ consema query --profile toml.1.0 --request-file query-toml.json
match 0: $.build-system (key build-system) = {requires: ["hatchling>=1.25"], build-backend: "hatchling.build"}
match 1: $.project (key project) = {name: "consema-client", version: "0.2.0", description: "A realistic PEP 621 fixture", requires-python: ">=3.11", dependencies: ["httpx>=0.27,<1", "pydantic>=2.8,<3"], optional-dependencies: {test: ["pytest>=8", "pytest-cov>=5"]}}
match 2: $.tool (key tool) = {pytest: {ini_options: {addopts: "-ra --strict-markers", testpaths: ["tests"]}}, ruff: {line-length: 100, target-version: "py311", lint: {select: ["E", "F", "I", "UP"]}}}
```

```text
$ consema project --profile toml.1.0 --request-file project-toml.json
{build-system: {requires: ["hatchling>=1.25"], build-backend: "hatchling.build"}, project: {name: "consema-client", version: "0.2.0", description: "A realistic PEP 621 fixture", requires-python: ">=3.11", dependencies: ["httpx>=0.27,<1", "pydantic>=2.8,<3"], optional-dependencies: {test: ["pytest>=8", "pytest-cov>=5"]}}, tool: {pytest: {ini_options: {addopts: "-ra --strict-markers", testpaths: ["tests"]}}, ruff: {line-length: 100, target-version: "py311", lint: {select: ["E", "F", "I", "UP"]}}}}
```

convert → JSON（canonical compact）：

```text
$ consema convert pyproject.toml --profile toml.1.0 --request-file convert-toml-json.json
{"build-system":{"requires":["hatchling>=1.25"],"build-backend":"hatchling.build"},"project":{"name":"consema-client","version":"0.2.0","description":"A realistic PEP 621 fixture","requires-python":">=3.11","dependencies":["httpx>=0.27,<1","pydantic>=2.8,<3"],"optional-dependencies":{"test":["pytest>=8","pytest-cov>=5"]}},"tool":{"pytest":{"ini_options":{"addopts":"-ra --strict-markers","testpaths":["tests"]}},"ruff":{"line-length":100,"target-version":"py311","lint":{"select":["E","F","I","UP"]}}}}
```

convert → YAML（`yaml.canonical-block` 风格；canonical 显式 tagged 渲染是
materializer 的冻结输出形状，不是缺省猜测）：

```text
$ consema convert pyproject.toml --profile toml.1.0 --request-file convert-toml-yaml.json
--- !!map
? !!str "build-system"
: !!map
  ? !!str "requires"
  : !!seq
    - !!str "hatchling>=1.25"
  ? !!str "build-backend"
  : !!str "hatchling.build"
? !!str "project"
...
```

edit（未接线 → 显式拒绝，exit 2，消息同 12.1 的 toml 变体）。

### 12.3 yaml 家族（yaml.1.2-core / yaml.1.1-compat）

```text
$ consema inspect github-actions-ci.yaml
consema inspect github-actions-ci.yaml
  bytes: 526 bytes sha256:692520d9998309d85972b6d780aa33c41d04eafff67e3e91fe3ae75b84867519
  bom: none
  symlink: no
  markers: key: value line
  candidates: yaml.1.1-compat@1 (leading key: value line); yaml.1.2-core@1 (leading key: value line)
  ambiguous: yes: key: value line is consistent with multiple profiles of the yaml family
```

```text
$ consema query --profile yaml.1.2-core --request-file query-yaml.json
match 0: $.name (key name) = "Rust CI"
match 1: $.on (key on) = {push: {branches: ["main"]}, pull_request: null}
match 2: $.permissions (key permissions) = {contents: "read"}
match 3: $.jobs (key jobs) = {test: {runs-on: "${{ matrix.os }}", strategy: {fail-fast: false, matrix: {os: ["ubuntu-latest", "windows-latest"], rust: ["stable", "1.85.0"]}}, steps: [{uses: "actions/checkout@v4"}, {name: "Install Rust", uses: "dtolnay/rust-toolchain@stable", with: {toolchain: "${{ matrix.rust }}"}}, {name: "Test workspace", run: "cargo test --locked --workspace --all-targets"}]}}
```

convert → JSON：

```text
$ consema convert github-actions-ci.yaml --profile yaml.1.2-core --request-file convert-yaml-json.json
{"name":"Rust CI","on":{"push":{"branches":["main"]},"pull_request":null},"permissions":{"contents":"read"},"jobs":{"test":{"runs-on":"${{ matrix.os }}","strategy":{"fail-fast":false,"matrix":{"os":["ubuntu-latest","windows-latest"],"rust":["stable","1.85.0"]}},"steps":[{"uses":"actions/checkout@v4"},{"name":"Install Rust","uses":"dtolnay/rust-toolchain@stable","with":{"toolchain":"${{ matrix.rust }}"}},{"name":"Test workspace","run":"cargo test --locked --workspace --all-targets"}]}}}
```

project（未接线 → 显式拒绝，exit 2）：

```text
$ consema project --profile yaml.1.2-core --request-file project-yaml.json
consema: error: project: the project command is not wired for the 'yaml' family in milestone M5 (its report/provenance externalization is not yet implemented); refusing instead of emitting an incomplete record (code cli.data.invalid-request@1)
```

图语义 → 树目标的 loss policy（共享未授权 → 原子失败，见第 5.1 节）：
`anchor-heavy.yaml`（`&defaults`/`*defaults`）转换到 JSON 目标：

```text
$ consema convert anchor-heavy.yaml --profile yaml.1.2-core --request-file convert-yaml-json.json
consema: error: convert: conversion failed atomically (core.conversion.projection-failed@1) (code core.conversion.projection-failed@1)
```

edit（未接线 → 显式拒绝，exit 2，消息同 12.1 的 yaml 变体）。

### 12.4 ini 家族（ini.portable / ini.windows / ini.python-configparser）

```text
$ consema inspect desktop-settings.ini
consema inspect desktop-settings.ini
  bytes: 177 bytes sha256:b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8
  bom: none
  symlink: no
  markers: none
  candidates: none
  ambiguous: no
```

（文件以 `;` 注释行开头，前导 marker 不成立——facts-only 如实报告，不因
扩展名猜格式。）

query 走 `core.try-entry-mapping-entries`（入口映射形状；`try-object-entries`
对 EntryMapping 无匹配）：

```text
$ consema query --profile ini.portable --request-file query-ini.json
match 0: $[value 0] (key PortableValue(String("window"))) = {"width": "1440", "height": "900", "maximized": "false":}
match 1: $[value 1] (key PortableValue(String("appearance"))) = {"theme": "system", "language": "zh-CN":}
match 2: $[value 2] (key PortableValue(String("recent"))) = {"workspace": "work/consema", "autosave_seconds": "30":}
```

convert → JSON：

```text
$ consema convert desktop-settings.ini --profile ini.portable --request-file convert-ini-json.json
{"window":{"width":"1440","height":"900","maximized":"false"},"appearance":{"theme":"system","language":"zh-CN"},"recent":{"workspace":"work/consema","autosave_seconds":"30"}}
```

edit/plan/apply 是 INI 家族唯一接线的编辑词表——单文件 dry-run 与 100 文件
批量 plan/apply 完整输出见第 6 节。Recovered 文档（重复 section）不可
convert（formation 执行 duplicate policy，exit 2，见第 5.1 节）。

project（未接线 → 显式拒绝，exit 2，消息同 12.3 的 yaml 变体、家族名替换）。

### 12.5 java-properties（java-properties.reader / java-properties.latin1）

```text
$ consema inspect build-tool.properties
consema inspect build-tool.properties
  bytes: 208 bytes sha256:3c988cf59c07443462e95ab3554713892c94c675a0eff9e6db3a46affbd84636
  bom: none
  symlink: no
  markers: none
  candidates: none
  ambiguous: no
```

query（`core.try-entry-mapping-entries`）：

```text
$ consema query --profile java-properties.reader --request-file query-properties.json
match 0: $[value 0] (key PortableValue(String("org.gradle.daemon"))) = "true"
match 1: $[value 1] (key PortableValue(String("org.gradle.parallel"))) = "true"
match 2: $[value 2] (key PortableValue(String("org.gradle.caching"))) = "true"
match 3: $[value 3] (key PortableValue(String("org.gradle.jvmargs"))) = "-Xmx2g -Dfile.encoding=UTF-8"
match 4: $[value 4] (key PortableValue(String("version"))) = "1.0.0"
match 5: $[value 5] (key PortableValue(String("publish.url"))) = "https://example.invalid/releases"
```

convert → JSON（2026-08-07 复核：族前缀特例修复后可达，见边界 6）：

```text
$ consema convert build-tool.properties --profile java-properties.reader --request-file convert-properties-json.json
{"org.gradle.daemon":"true","org.gradle.parallel":"true","org.gradle.caching":"true","org.gradle.jvmargs":"-Xmx2g -Dfile.encoding=UTF-8","version":"1.0.0","publish.url":"https://example.invalid/releases"}
```

project（未接线 → 显式拒绝，exit 2，消息同 12.3 的 yaml 变体、家族名替换）；
edit（未接线 → 显式拒绝，exit 2）。

### 12.6 plist 家族（plist.xml / plist.binary）

```text
$ consema inspect Info.plist
consema inspect Info.plist
  bytes: 1355 bytes sha256:bfc61719340a722b5bd77f0e29b941d36159a2da8e9cc1a719c9be97cd450592
  bom: none
  symlink: no
  markers: XML declaration
  candidates: plist.xml@1 (leading XML declaration); xml.1.0-safe@1 (leading XML declaration)
  ambiguous: yes: XML declaration is consistent with format families: plist, xml
```

query（native 域未接线 → 显式拒绝，exit 2）：

```text
$ consema query --profile plist.xml --request-file query-plist.json
consema: error: query: the core.portable-value-query@1 domain cannot query plist sources: their default projection publishes a versioned internal record (the native query domains require caller locators not yet exposed by the facade) (code cli.data.invalid-request@1)
```

同家族 convert：XML → XML canonical：

```text
$ consema convert Info.plist --profile plist.xml --request-file convert-plist-xml-xml.json
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
...
```

XML → binary（请求必须带 `encoding: Binary` 与 `newline: None`，边界 9；
输出为 `bplist00` 头字节）：

```text
$ consema convert com.example.preferences.plist --profile plist.xml --request-file convert-plist-xml-binary.json > out.binary.plist
$ od -c out.binary.plist | head -1
0000000   b   p   l   i   s   t   0   0
```

（`convert-plist-xml-binary.json` 与第 5 节 `convert-request.json` 同体例，
仅 materialization 段的 `encoding.kind` 为 `Binary`、`newline` 为 `None`、
style 为 `plist.binary-canonical`。请求契约违反时材料化原子失败，见边界 9。）

project / edit（未接线 → 显式拒绝，exit 2）。UID 投影的 loss policy 见第
5.1 节（exact-or-reject 默认拒绝）。

### 12.7 xml.1.0-safe

```text
$ consema inspect app-server-config.xml
consema inspect app-server-config.xml
  bytes: 508 bytes sha256:221ebb7eeadcdc12488cbc0c3c3e061c93f73f52152200d0c3dc624b8b1fec40
  bom: none
  symlink: no
  markers: XML declaration
  candidates: plist.xml@1 (leading XML declaration); xml.1.0-safe@1 (leading XML declaration)
  ambiguous: yes: XML declaration is consistent with format families: plist, xml

$ consema inspect app-server-config.xml --profile xml.1.0-safe
consema inspect app-server-config.xml
  bytes: 508 bytes sha256:221ebb7eeadcdc12488cbc0c3c3e061c93f73f52152200d0c3dc624b8b1fec40
  bom: none
  symlink: no
  markers: XML declaration
  candidates: plist.xml@1 (leading XML declaration); xml.1.0-safe@1 (leading XML declaration)
  ambiguous: yes: XML declaration is consistent with format families: plist, xml
  parse (xml.1.0-safe@1): Complete
    diagnostics: none
    structure counts: xml.nodes: 17
```

query（native 域未接线 → 显式拒绝，exit 2，消息同 12.6 的 xml 变体）。

同家族 convert：element-tree 投影 → `xml.safe-canonical-document`：

```text
$ consema convert app-server-config.xml --profile xml.1.0-safe --request-file convert-xml-xml.json
<?xml version="1.0" encoding="UTF-8"?><server xmlns="urn:example:server" xmlns:db="urn:example:datasource" xmlns:sec="urn:example:security">
  <sec:realm name="app-realm">
    <sec:user username="service" roles="app,read"/>
  </sec:realm>
...
```

跨家族目标（XML → JSON）被 record-consumption gate 原子拒绝（record 只能
由本家 materializer 消费，第 5 节）：

```text
$ consema convert app-server-config.xml --profile xml.1.0-safe --request-file convert-xml-json.json
consema: error: convert: conversion failed atomically (core.conversion.materialization-failed@1) (code core.conversion.materialization-failed@1)
```

project / edit（未接线 → 显式拒绝，exit 2）。malformed 输入的 inspect
Recovered 报告见边界 8（exit 0，格式本地真码在 stderr）。

### 12.8 hcl 家族（hcl.native / hcl.tfvars）

```text
$ consema inspect main.tf
consema inspect main.tf
  bytes: 1139 bytes sha256:1c9a57fc4f6b7358d22aac8c2f13c7b9ab421194007eac7d6673e7b5558e2436
  bom: none
  symlink: no
  markers: none
  candidates: none
  ambiguous: no

$ consema inspect main.tf --profile hcl.native
consema inspect main.tf
  bytes: 1139 bytes sha256:1c9a57fc4f6b7358d22aac8c2f13c7b9ab421194007eac7d6673e7b5558e2436
  bom: none
  symlink: no
  markers: none
  candidates: none
  ambiguous: no
  parse (hcl.native@1): Complete
    diagnostics: none
    structure counts: hcl.body_items: 10
```

query（native 域未接线 → 显式拒绝，exit 2，消息同 12.6 的 hcl 变体）。

convert：tfvars → `hcl.canonical-document`（literal-complete 属性，无求值）：

```text
$ consema convert terraform.tfvars --profile hcl.tfvars --request-file convert-hcl-tfvars.json
region = "us-east-1"
instance_type = "t3.micro"
ami = "ami-0abcdef1234567890"
instance_count = 2
monitoring = true
tags = {
```

含 derived 表达式（模板字符串）的 `main.tf` 在 exact 投影下原子失败：

```text
$ consema convert main.tf --profile hcl.native --request-file convert-hcl-body.json
consema: error: convert: conversion failed atomically (core.conversion.projection-failed@1) (code core.conversion.projection-failed@1)
```

project / edit（未接线 → 显式拒绝，exit 2）。

### 12.9 目标 ID、风格 ID 与操作词表速查

全部由 `consema capabilities` 派生（第 8 节）。convert/edit 请求文件所需的
每家族 ID：

| 家族 | 投影目标（projection 段 `target.id`） | 材料化风格（style `id`） | 操作词表（edit/plan，示例） |
|---|---|---|---|
| json | `json.projection.best-exact-core`、`project-as-object`、`project-as-entry-mapping`、`json5-best-exact-core` | `json.canonical-compact` / `json.canonical-pretty` | `json.edit.replace-scalar-semantic` 等 8 个（未接线） |
| toml | `toml.projection.best-exact-core` | `toml.canonical-document` | `toml.edit.replace-scalar-semantic` 等 7 个（未接线） |
| yaml | `yaml.projection.best-exact-value` | `yaml.canonical-block` / `yaml.canonical-flow` | `yaml.edit.replace-scalar-semantic` 等 8 个（未接线） |
| ini | `ini.projection.best-exact-entry-mapping`、`require-object` | `ini.portable-canonical` 等三 Profile 风格 | `ini.edit.replace-semantic-value` 等 8 个（**已接线**，第 6 节） |
| java-properties | `java-properties.projection.best-exact-entry-mapping`、`require-object` | `java-properties.reader-canonical` / `latin1-canonical` | `java-properties.edit.*` 5 个（未接线） |
| xml | `xml.projection.element-tree` | `xml.safe-canonical-document` | `xml.edit.set-attribute-value` 等 8 个（未接线） |
| plist | `plist.projection.value-tree` | `plist.xml-canonical` / `plist.binary-canonical` | `plist.edit.set-value` 等 6 个（未接线） |
| hcl | `hcl.projection.body` | `hcl.canonical-document` | `hcl.edit.set-attribute-value` 等 6 个（未接线） |

convert 组合的 loss policy 小结（全部实测，§22.6）：

- 可表示组合走 ExactOnly 双阶段：JSON↔TOML、JSON↔YAML、TOML→YAML、
  INI→JSON、Properties→JSON（本节省略重复输出）。
- 未授权 loss 原子失败（`core.conversion.projection-failed@1`）：YAML
  sharing/cycle → JSON（12.3）、HCL derived expression（12.8）、plist UID
  （第 5.1 节）。
- 目标 Profile 无法表示 → 材料化原子失败（`core.conversion.materialization-failed@1`）：
  TOML date/time → JSON（`all-values.toml` 实测）、以及 INI/JSON/TOML →
  INI 或 Properties 等入口映射/标量形状不匹配的组合（实测 exit 2）。
- record 家族跨家族目标被 record-consumption gate 拒绝（12.7 XML → JSON）。
- entry-mapping → object 的映射政策是唯一授权转换通道
  （`mapping_policy: UniqueStringEntriesToObject`，第 5 节 JSON→TOML 例），
  转换信封携带完整 report（两阶段 fidelity + events，`--json` 可查）。
