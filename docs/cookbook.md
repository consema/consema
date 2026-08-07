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
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.convert-request@1"}},{"key":"projection_request","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.projection-request@1"}},{"key":"target","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"json.projection.best-exact-core"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"default_policy","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"core.projection.exact-or-reject"}},{"key":"version","value":{"type":"Integer","value":"1"}},{"key":"arguments","value":{"type":"Object","entries":[]}}]}},{"key":"rules","value":{"type":"Sequence","items":[]}},{"key":"limits","value":{"type":"Object","entries":[]}}]}},{"key":"materialization_request","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.materialization-request@2"}},{"key":"target_profile","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"toml.1.0"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"style","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"toml.canonical-document"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"encoding","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.source-encoding@1"}},{"key":"kind","value":{"type":"String","value":"Utf8"}},{"key":"windows_code_page","value":{"type":"Null"}}]}},{"key":"newline","value":{"type":"String","value":"Lf"}},{"key":"mapping_policy","value":{"type":"String","value":"UniqueStringEntriesToObject"}},{"key":"representability","value":{"type":"String","value":"ExactOnly"}},{"key":"limits","value":{"type":"Object","entries":[{"key":"max_input_nodes","value":{"type":"Integer","value":"1000000"}},{"key":"max_output_bytes","value":{"type":"Integer","value":"67108864"}},{"key":"max_depth","value":{"type":"Integer","value":"256"}},{"key":"max_report_entries","value":{"type":"Integer","value":"100000"}},{"key":"max_provenance_entries","value":{"type":"Integer","value":"2000000"}}]}}]}}]}}]}
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

目标字节默认到 stdout；`--output <path>` 显式落盘。全部 8 个格式家族都可作
convert 源/目标；record 家族（xml/plist/hcl）只能由本家 materializer 消费
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
  error codes (186): ...
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
| java-properties（reader/latin1） | ✓ | ✓ | —（未接线，见下） | — | —（未接线，见下） |
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
6. **java-properties 的 project/convert 目标族前缀不匹配**（2026-08-07 复核
   发现，非文档化边界）：`format_family` 对 java-properties 返回
   `properties`，而 `wire_projection_request` 的族前缀检查按
   `properties.projection.` 拒绝 `java-properties.projection.*` 目标——
   project/convert 对 java-properties 源当前不可达（query 不受影响）。
   已记录为 0.13.0 API 评审 backlog 的优先修复项。
7. **edit 词表仅 INI family**：`edit --write` 亦未接线（dry-run only，
   `--write` 是 usage 错误），批量写经 plan/apply。

## 11. exit code 速查（RFC 0015 §5.1，实测对应）

| 码 | 类 | 实测示例 |
|---|---|---|
| 0 | success | 全部完整结果：inspect（含歧义报告）、query 成功、plan（含 failed 条目）、apply 全 completed、conformance、explain、--help/--version |
| 1 | usage | 未知命令/未知参数、缺 `--profile`、`edit --write`（本版本）、非 UTF-8 参数 |
| 2 | data | 请求解码失败（`cli.data.invalid-request@1`）、Recovered 源、cardinality 违反、转换原子失败（`core.conversion.*`）、文件不可读（`cli.data.io@1`） |
| 3 | limit | 超出 `--max-bytes`/`--max-files`/manifest 预算（`cli.limit.*@1`） |
| 4 | precondition | stale digest（`core.source.patch-base-mismatch@1`）、写入失败（`cli.write.*`）、中断（`cli.interrupted.signal@1`） |
| 5 | internal | 未分类内部错误（`cli.internal.unclassified@1`，如 conformance 自检失败） |
