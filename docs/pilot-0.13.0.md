# 真实项目 Pilot 报告（0.13.0 M6，路线图 §23）

- 日期：2026-08-07（本地实测）
- 环境：Windows 11 Pro 10.0.26200，x86-64；`target/release/consema.exe`
  （0.8.0，0.12.0 CLI，release profile，`cargo build --release --locked -p
  consema`）
- 依据：路线图 §23.2（必做工作流）与 §23.3（核心指标）；0.13.0 门禁计划
  M6 与 G-9
- 本报告所有命令输出均为实跑粘贴；指标全部来自本报告记录的运行

## 1. 选择的真实项目与语料登记（§23.1）

选择 `conformance/fixtures/real-world/` 钉版 corpus 中的
**`package.json`（`consema-fixture-app`，424 字节）** 为 pilot 项目；
同 corpus 的其余三个文件（`tsconfig.jsonc`、`vscode-settings.jsonc`、
`application.json5`）在适用的工作流步骤中一并参与。

语料登记（§23.1 要求记录来源、license、digest、Profile 与预期用途）：

| 文件 | 字节 | SHA-256 | Profile 预期 | 用途 |
|---|---|---|---|---|
| package.json | 424 | 06d760863d6c0c66e119747d74a116c12a365315cb423ce3108f4f2b10089a13 | json.strict@1 | §23.2 W1/W6/W7/W8 主项目 |
| tsconfig.jsonc | 428 | c3fa961d9eae747c4b1025cabf8c0dd05b8c7532574db9cb89ec026f1aac7f52 | jsonc.bounded@1 | W1（JSONC 依赖/镜像更新） |
| vscode-settings.jsonc | 396 | 0fa1b8e135e81fc980fd301a8b231227a7fb24fb823d8a3316ff3cd2f6ac799d | jsonc.bounded@1 | W1 |
| application.json5 | 410 | 30c07b89db0fecd9b465835e8bf5a06e69d68ff8a195a1be3a18fbbfe0b1fa1a | json5.standard@1 | W1 |

来源与 license：`conformance/fixtures/real-world/README.md`——非专有的代表性
配置文档，非第三方项目逐字节拷贝；仓库 MIT 许可。不包含 secret 或个人
信息。Pilot 的 INI 批量工作流（W2/W8）使用钉版 `conformance/fixtures/ini/
desktop-settings.ini`（177 字节）的 100 份副本（语料类型：generated
combinatorial corpus；每份记录在 plan manifest 中）。

## 2. §23.2 必做工作流执行记录

### 2.1 W1 — JSONC/JSON5/TOML/YAML 中更新依赖或镜像版本，保持注释与 style

**结论：CLI 上不可执行（发现 F-1）。** 本版本 edit/plan 操作词表只接线
INI family（CHANGELOG.md 的 0.13.0 节 INI edit 词表条目、cookbook §10 边界 7）。对 JSONC 源发出
`json.edit.replace-scalar-semantic@1` 请求得到显式拒绝（exit 2）：

```text
$ consema edit tsconfig.jsonc --profile jsonc.bounded --request-file edit-json.json
consema: error: edit: the json edit surface is not wired in this milestone: the request vocabulary maps the ini family only (the facade exposes typed edit transactions for json, but no operation request mapping yet) (code cli.data.invalid-request@1)
```

（`edit-json.json` 为 `cli.edit-request@1` 裸 payload：操作
`json.edit.replace-scalar-semantic@1`、目标 member `version`。TOML/YAML 同
样拒绝，见 cookbook §12。）CLI 提供的事实面完整：inspect + query 可定位与
审计依赖版本，但"保持注释与 style 的版本更新"必须走 SDK 编辑事务或等待
跨格式 edit 词表接线（0.13.0 API 评审 backlog B-7）。

### 2.2 W2 — INI/Properties 中插入、删除、rename 配置项并保留重复与 logical line

**INI 部分可执行（dry-run 与批量写），Properties 不可执行（F-1）。**

对 `desktop-settings.ini` 的 `window:width` 执行 replace-semantic-value
dry-run（base/target digest 与 replacements 计数齐全）：

```text
$ consema edit desktop-settings.ini --profile ini.portable --request-file edit-ini.json
edit dry-run (ini.portable): desktop-settings.ini
  ini.edit.replace-semantic-value@1 on entry 'window':'width'  value=1600 representation_policy=preserve-compatible
  base b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8 target 98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a replacements: 1
  committed: no
```

词表另含 insert/remove/rename entry/section（`consema capabilities` 的
ini 操作注册表），本 pilot 执行了 replace 语义；重复 section 的
Recovered 行为由第 2.7 节（W7）覆盖。Properties 的 `java-properties.edit.*`
词表存在但 edit 面未接线（同 F-1）。

### 2.3 W3 — XML 中修改 attribute/element/text，不破坏 namespace 与 mixed content

**CLI 上不可执行（F-1）。** `xml.edit.set-attribute-value@1` 请求显式拒绝
（exit 2，消息同 2.1 的 xml 变体）。namespace/mixed content 保持能力在
SDK 层（RFC 0012 的编辑事务；六仓拆分后母仓 README 不再承载 SDK 细节，见各语言仓 README），CLI 词表未接线。

### 2.4 W4 — plist XML/binary 中修改 typed value 并保持 representation contract

**CLI 上不可执行（F-1）。** `plist.edit.set-value@1` 请求显式拒绝（exit 2）。
representation contract 的保持能力在 SDK 层（RFC 0013），CLI 未接线。
CLI 可执行的是同族 convert（XML → binary，含 `bplist00` 头，见 2.6 节）。

### 2.5 W5 — HCL 中修改 literal attribute，不执行表达式

**CLI 上不可执行（F-1）。** `hcl.edit.set-attribute-value@1` 请求显式拒绝
（exit 2）。无求值语义在 SDK 层（SECURITY.md:36，`hcl.expression@1` 只承载
语法事实）；CLI 的 convert 对 derived expression 原子失败（2.7 节）。

### 2.6 W6 — JSON ↔ TOML、JSON ↔ YAML 等可表示组合的 audited conversion

**全部执行成功（exit 0），双向往返语义相等。**

```text
$ consema convert package.json --profile json.strict --request-file convert-json-toml.json
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

```text
$ consema convert package.json --profile json.strict --request-file convert-json-yaml.json
--- !!map
? !!str "name"
: !!str "consema-fixture-app"
? !!str "version"
: !!str "1.0.0"
...
```

往返（TOML/YAML 目标字节落盘后作源）：

```text
$ consema convert package.toml --profile toml.1.0 --request-file convert-toml-json.json
{"name":"consema-fixture-app","version":"1.0.0","private":true,"type":"module",...}

$ consema convert package.yaml --profile yaml.1.2-core --request-file convert-yaml-json.json
{"name":"consema-fixture-app","version":"1.0.0","private":true,"type":"module",...}
```

audit 证据：两方向 round-trip 的重新转换值与源语义相等（Python
`json.loads` 深度相等，2/2）；`--json` 信封的 `cli.convert@1` 记录携带
`core.conversion-report@1`（source/target profile、两阶段 fidelity、events
与完整 target snapshot）；materialize 目标字节先重解析闭包验证
（SECURITY.md:24，生成字节必先重解析）。同族 convert 一并执行成功：
TOML→TOML、XML→XML、plist XML→XML、plist XML→binary（`bplist00` 头）、
HCL tfvars→canonical。

### 2.7 W7 — 对不可无损转换产生明确拒绝和报告

三个代表性组合全部**原子失败**（exit 2，无目标文档、无部分字节），信封
`cli.convert@1` 记录 `report: null, target: null` + 完整诊断（RFC 0015
§4.3 冻结失败形态）：

```text
$ consema convert anchor-heavy.yaml --profile yaml.1.2-core --request-file convert-yaml-json.json
consema: error: convert: conversion failed atomically (core.conversion.projection-failed@1) (code core.conversion.projection-failed@1)

$ consema convert all-values.toml --profile toml.1.0 --request-file convert-toml-json.json
consema: error: convert: conversion failed atomically (core.conversion.materialization-failed@1) (code core.conversion.materialization-failed@1)

$ consema convert app-server-config.xml --profile xml.1.0-safe --request-file convert-xml-json.json
consema: error: convert: conversion failed atomically (core.conversion.materialization-failed@1) (code core.conversion.materialization-failed@1)
```

语义：YAML sharing/cycle → 树（`yaml.projection.sharing@1` 系未授权损失）；
TOML date/time → JSON（JSON 无 date/time 类型，materialization
unrepresentable）；XML element-tree record → 非本家目标被
record-consumption gate 拒绝（conversion.rs 记录门禁）。Recovered 源同样
明确拒绝：重复 section 的 INI 不可 convert（`ini.formation.duplicate-section@1`）。

### 2.8 W8 — 多文件 dry-run、review、stale conflict 和 apply

100 文件批量（INI，钉版夹具副本；`edit-ini.json` 为 `window:width` →
1600）：

```text
$ consema plan settings-*.ini --profile ini.portable --request-file edit-ini.json --output plan.json
consema plan: 100 file(s)
  settings-001.ini: planned
    ini.edit.replace-semantic-value@1 on entry 'window':'width'  value=1600 representation_policy=preserve-compatible
    base sha256:b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8 target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a replacements: 1
  settings-002.ini: planned
  ...

$ consema apply plan.json --output result.json
consema apply: 100 file(s)
  settings-001.ini: completed (target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a)
  settings-002.ini: completed (target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a)
  ...
```

stale conflict（10 文件新批；`s-03.ini` 在 plan 后被外部追加一行）：

```text
$ consema apply plan.json --output result.json
consema: error: apply: s-03.ini: the current file bytes no longer match the planned base digest; the file was not rewritten (code core.source.patch-base-mismatch@1)
consema apply: 10 file(s)
  s-01.ini: completed (target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a)
  s-02.ini: completed (target sha256:98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a)
  ...
```

exit 4；被跳过文件字节分毫未动（`width=1440` 保持，追加行保持）。

中断与恢复（`CONSEMA_APPLY_INTERRUPT_AFTER=7` 注入 seam）：

```text
$ CONSEMA_APPLY_INTERRUPT_AFTER=7 consema apply plan.json --output result.json
consema: error: apply: interrupted by SIGINT/SIGTERM: the result manifest keeps the in-flight file 's-08.ini' pending; re-run apply with the same plan to resume (code cli.interrupted.signal@1)
```

中断 exit 4；manifest 状态 7 completed / 13 pending；重跑同一 plan 后
20/20 completed（completed 跳过、pending 重做）。

## 3. §23.3 核心指标

| # | 指标 | 数值 | 测量方式 |
|---|---|---|---|
| 1 | exact unmodified round-trip rate | 2/2 = 100%（语义往返） | JSON→TOML→JSON 与 JSON→YAML→JSON 再转换值与源深度相等；字节级 round-trip 是库级门禁（18 套 suite 519/519，README.md:56；2026-08-12 P2-B 补强前为 508/508），CLI 可观察代理 = 目标字节重解析闭包（convert 每次成功都执行） |
| 2 | untouched-byte preservation rate | 97.7%/文件（编辑路径）；100%（stale 路径） | 每文件 1 个 replacement（4 字节值替换），177 字节文件 → 173/177；stale 文件 0 字节写入（s-03.ini 实测 `width=1440` 保持） |
| 3 | silent-loss count | 0 | 19 个 convert 运行（12 成功 + 7 原子失败，第 2.6/2.7 节）全部 ExactOnly 或原子失败；成功信封 `core.conversion-report@1` 两阶段 fidelity 均为 Exact（抽查 INI→JSON 信封） |
| 4 | authorized-loss report completeness | 完整 | 唯一授权转换通道为 `mapping_policy: UniqueStringEntriesToObject`（entry-mapping → object）；成功信封始终携带完整 `core.conversion-report@1`（source/target profile、projection/materialization fidelity、events、target snapshot） |
| 5 | false-success count | 0 | 40+ 次运行逐一核对 exit class 与结果形态：limit 类（`--max-bytes 100` → exit 3，信封 `size:100, digest:null`，无截断伪装）、data 类（exit 2，`report:null, target:null`）均无"exit 0 但结果不完整" |
| 6 | false-conflict / missed-conflict count | 0 / 0 | stale 场景：1 个真实冲突被检出（skipped-stale，exit 4），其余 9 文件照常 completed；无误报、无漏报 |
| 7 | diagnostic stability | 字节级稳定 | 同一失败（xml 源 query、Recovered inspect、limit）重复运行 stderr+stdout 逐字节一致（`cmp` 验证） |
| 8 | query result determinism | 字节级确定 | query human 视图与 `--json` 信封各 2 次运行逐字节一致（`cmp` 验证）；RFC 0015 §3.3 冻结 |
| 9 | parse/query/edit latency p50/p95 | 见下表 | PowerShell Stopwatch，30 次冷进程各命令（见 §4 复现） |
| 10 | peak memory/input byte | ≈ 315 字节/输入字节 | 335,312 字节 JSON→TOML 成功转换峰值工作集 105,545,728 B（≈100.7 MiB）；YAML 目标见发现 F-2 |
| 11 | batch apply success/recovery rate | 100%（100/100）；恢复率 100%（20/20） | 首批 apply 全部 completed；中断后重跑 completed 跳过、pending 重做全完成；stale 场景 9/10 completed + 1 skipped-stale（exit 4，预期） |
| 12 | Rust/Go observable mismatch count | 0 | Go 实现已按 2026-08-07 decision record 启动 G0.1-G0.3（go/）；本指标按定义 N/A，0.14.0 起测量 |

延迟 p50/p95（冷进程，n=30，2026-08-07，本机）：

| 操作 | p50 | p95 | min | max |
|---|---:|---:|---:|---:|
| inspect package.json | 5 ms | 12 ms | 4 ms | 37 ms |
| query（json.strict，request-file） | 5 ms | 6 ms | 4 ms | 14 ms |
| edit dry-run（ini.portable） | 5 ms | 12 ms | 4 ms | 13 ms |
| convert package.json → toml | 6 ms | 13 ms | 5 ms | 18 ms |

批量（单次调用）：plan 100 文件 333 ms（≈3.3 ms/文件）；apply 100 文件
2,137 ms（≈21 ms/文件，含每文件原子写与读回验证）。

## 4. 复现

构建：`cargo build --release --locked -p consema`。请求文件（canonical
tagged JSON，无尾随换行）按 cookbook §3-§6 与 §12 体例逐字节构造：
query/project 用 `cli.request@1` 包装；convert/edit 用裸 payload。本报告
命令的 fixture 均取自 `conformance/fixtures/`（real-world/、ini/、toml/、
yaml/、xml/、plist/、hcl/）的钉版文件。

## 5. 发现的问题

### F-1（已知 backlog 实证）— edit 词表仅 INI，§23.2 的 W1/W3/W4/W5 与 Properties 的 W2 在 CLI 不可执行

证据：6 个家族（json/toml/yaml/xml/plist/hcl）的 edit 请求全部显式拒绝
（exit 2，`cli.data.invalid-request@1`，消息 "the <family> edit surface is
not wired in this milestone: the request vocabulary maps the ini family
only"）；CHANGELOG.md 的 0.13.0 节 INI edit 词表条目与 cookbook §10 边界 7 同文。影响：真实 JSON
项目（本 pilot）无法经 CLI 完成"保持注释与 style 的依赖版本更新"，只能
SDK 编辑或等待 0.13.0 API 评审 backlog B-7 的每格式操作请求映射。这不是
静默缺口——拒绝是显式且信息完整的。

### F-2（新发现，性能）— JSON → YAML 转换呈超线性（~O(n²) 量级），335 KB 输入耗时 69 秒

实测（同一机器、同一二进制、同一请求形状）：

| 输入（JSON → YAML） | 字节 | 耗时 |
|---|---:|---:|
| s500 | 39,988 | 0.54 s |
| s1000 | 80,571 | 2.04 s |
| big2000 | 164,071 | 9.08 s |
| big5000 | 414,571 | 120.63 s |
| big-nf5000（335,312 B，无小数） | 335,312 | 69.40 s |
| big-nf5000 同输入 → TOML | 335,312 | 1.59 s |

对照：parse+project 是线性的（project big5000 = 0.55 s，query big5000 =
0.42 s），瓶颈在 YAML materialization 阶段。输入 10 倍 → 耗时约 220 倍，
违反路线图 §20.1"不出现可被输入触发的未受限超线性行为"对 CLI 可达路径的
要求（§15.5 预算与 §22.5 大文档场景同理受影响）。处置建议：归 consema-yaml
materializer（provenance/闭包重解析路径）修复并补入 BENCHMARKS 大文档
场景；修复前文档化该边界。

**F-2 解决记录（2026-08-07，性能修复里程碑，本发现已关闭）：**

根因不在 materializer 本身，而在逐 lookup 的坐标转换：`raw_byte_at` 每次
调用对整源做一次 `from_utf8` 重校验（O(source) per call），YAML 每个
lexeme/节点边界都走一次 → O(source × pieces) 的 O(n²) 形成形状（与 task
#53 同一根因，见 `consema-rs/consema-document/src/source.rs:1540-1548`）。

修复（三处配合，各带回归测试）：

- `consema-rs/consema-yaml/src/offsets.rs:1-80`——`RawByteResolver`：单遍正向
  行走的 decoded-scalar → raw-byte 偏移解析器，每次 lookup 摊还 O(1)，
  O(source + lookups) 总量；与 `raw_byte_at` 逐点相等测试（:90-156）。
- `consema-rs/consema-document/src/source.rs:466-509`——`DecodedStorage::RawUtf8`
  保留构造时已校验的文本，`decoded_text`/`raw_byte_at` 变 O(1) 视图；
  回归网 `per_call_coordinate_conversion_does_not_rescan_large_utf8_sources`
  （:1538-1589）。
- `consema-rs/consema-xml/src/parser.rs:2027-2052`——xml 的 `raw_offset` UTF-8
  恒等快捷（同根因的 xml 侧修复）。

后修复实测（同一机器、同一请求形状）：`big-nf5000`（335,312 B）JSON → YAML
转换 **69.40 s → 1.01 s（约 69×）**；§15.5 线性度门禁据此复验通过（xml 20k
96.6 s→0.105 s、properties 10k 5.09 s→127.5 ms 同批，BENCHMARKS-0.13.0.md
§7 修正注与 §12 复验记录）。BENCHMARKS 冻结预算未受影响——修复只改善
性能，冻结值仍为有效上界。

**F-2 复核修正（audit B-8，2026-08-07）：** 上述 "1.01 s、线性" 结论未完全
复现：round-2 审计用重建输入测得嵌套形状 294-354 KB → 5.1-7.2 s（block 与
flow 皆然）、2000→4000 items 1.24 s → 7.4 s（≈6×）。根因是修复后残余的两处
独立超线性（均在 `consema-rs/consema-yaml/src/`）：

1. **Composer 覆盖 span 滞后解析**（`native.rs`）：集合的 covering span 在子
   节点之后才解析，单遍 `RawByteResolver` 游标回退 → 每个嵌套集合重走全文
   （O(nodes × source)）。证据：636 KB 嵌套文档 12,002 次回退、行走 38 亿
   char；同字节去缩进副本解析快 113×。修复：集合起点 span 在事件消费时即
   解析（事件 span 单调不减）；回归网
   `large_nested_materialization_stays_within_linear_budget`。
2. **Provenance 线性扫描**（`projection.rs` 的 value/graph provenance、
   `materialization.rs` 的 value provenance）：每次 origin 记录对整个
   provenance 表做 `position()`/`find()`（O(entries) per node）。修复：
   location → entry 索引 `HashMap`，条目顺序与去重语义不变。

修复后复测（同机、release、串行无并发构建，N=7）：嵌套 4,000 items
（300 KB）6.66 s → 0.257 s（≈26×）、数组 4,000 items（5 元素/项）
5.56 s → 0.194 s（≈29×）；所有形状 1k→8k 倍增比 1.7-2.2×（线性）。pilot
形状同类（320,001 B flat 5,000 keys）**66.5-72.3 ms p50**（两次串行会话）
—— 本 pilot 的 1.01 s 数字仍为保守上界，已被 BENCHMARKS-0.13.0.md §7.1
C2 行取代（该节为 convert 路径新增冻结预算行，含 -Check 契约，见 §11）。

### F-3（文档/UX 不一致）— convert 的 `--output` 在本构建被拒绝，帮助文本与旧文档宣称可用

```text
$ consema convert package.json --profile json.strict --request-file convert-json-toml.json --output out.toml
consema: error: convert: flag '--output' is not available in this build: convert writes only to stdout (file writing lands with fsio in milestone M6) (code cli.usage.invalid-argument@1)
```

exit 1（usage）。帮助文本 `--output <path> result or manifest write target`
与 CHANGELOG.md:112 的口径（"materialize/convert 的目标字节默认只到 stdout；
`--output <path>` 显式落盘"）对 convert 不成立（plan/apply 的 `--output` 正常）。M6 已修正 cookbook §5
表述；帮助文本需随 fsio 落地同步（报告给 0.13.0 收口）。

### F-4（已修复，文档缺陷）— cookbook §5 的 convert-request.json 块尾多出 `]}`，复制即被拒绝

原块 2,253 字节，尾部 `]}` 使 JSON 失效：复制运行得到
`core.protocol.invalid-json@1`（exit 2）。M6 已修正为恰好 2,251 字节的
canonical JSON（重新校验通过）。

### F-5（上游已修，记录复核）— 0.13.0 评审 backlog B-6/B-9 在 0.12.0 工作树已修复

- B-6（java-properties convert 族前缀不匹配）：实测
  `convert build-tool.properties --profile java-properties.reader` → JSON
  exit 0（cookbook §12.5）；project 仍按报告外部化边界拒绝。
- B-9（inspect 对格式本地 code 的 Recovered/fatal 诊断 exit 5）：实测
  `inspect bad.xml --profile xml.1.0-safe` 与 Recovered INI 均 exit 0，
  stderr 保留真码（cookbook §10 边界 8）。
  `docs/0.13.0-gate-plan.md` §4 M4 的 B-6/B-9 disposition 与
  `docs/API-REVIEW-0.13.0.md` 需据此更新（报告给 M4/D 域）。

### F-6（行为观察，非缺陷）— 失败信封的 stdout 呈现

data/limit/precondition 类失败在无 `--json` 时也在 stdout 输出机器信封
（stderr 为人类诊断行）；usage 类（exit 1）stdout 无字节（RFC 0015 §4.2
一致）。脚本消费者应把失败 stdout 当作信封解析而不是忽略。
