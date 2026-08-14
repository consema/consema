# 迁移指南（0.8.0 时代 API → 0.12.0 facade + CLI）

本文面向两类读者：(1) 已经在 0.8.0 时代使用 Consema Rust SDK 的调用方；
(2) 用临时脚本处理配置文件的用户，现在可以迁移到正式 `consema` CLI。
0.8.0 → 0.12.0 的 SDK 变化全部是**增量的**：没有删除或改写任何 0.8.0
公共 API；语义模型注册表 v6 精确冻结，v7 在其上追加。CLI 是新产品入口，
不是对 SDK 的替代。

## 1. 0.8.0 时代的 API 用法仍然有效

0.8.0 的 facade 入口（`Document::parse_json`/`parse_toml`/`parse_yaml`/
`parse_ini`/`parse_properties`、`convert_json`/`convert_toml`/
`convert_yaml`/`convert_ini`/`convert_properties`、`consema::protocol`
导出）在 0.12.0 原样可用，语义未变。README 中 0.8.0 时代的示例代码
（JSON5→JSON、INI、Properties、协议、物化、原子编辑等）不需要修改。

0.9.0–0.11.0 是纯增量：

- **0.9.0**：新增 `Document::parse_xml`/`as_xml`（`xml.1.0-safe@1`）与
  XML materialization 转换目标；
- **0.10.0**：新增 `Document::parse_plist`/`as_plist`
  （`plist.xml@1`/`plist.binary@1`）与 plist 转换目标；
- **0.11.0**：新增 `Document::parse_hcl`/`as_hcl`
  （`hcl.native@1`/`hcl.tfvars@1`）与 `convert_hcl`。

facade 的再导出清单（`consema::core/document/graph/hcl/ini/json/plist/
properties/toml/xml/yaml/protocol/pvce`）与 Workspace 章节同步更新。
旧代码只需在新 crate 发布后重新编译（workspace 版本号仍为 0.8.0 直至
发布时统一提升）。

## 2. semantic-model v6 → v7：注册表变化

| 项 | v6（0.8.0） | v7（0.12.0） |
|---|---|---|
| `ContractRegistry::v6()` / `v7()` | 38 条记录 | 38 条冻结不变 + 3 条新增 |
| 新增 contract | — | `core.cli-output@1`、`core.batch-plan@1`、`core.batch-result@1` |
| `ErrorCodeRegistry::v6()` / `v7()` | 166 个 code | 166 个冻结不变 + 20 个 `cli.*`（usage 7/data 2/detection 1/limit 3/write 5/interrupted 1/internal 1；0.13.0 另注册 `json.projection.incomplete-document@1`，v7 现 187 个 code） |
| `RegistryManifest::current()` | 指向 v6 | **指向 v7** |

对调用方的实际影响只有一处需要核对：**读取
`RegistryManifest::current()` 的代码**（例如做兼容性断言、capability
清单或版本报告的程序）现在会看到 `core.semantic-model@7`、41 条 contract
与 187 个 code。如果你的代码断言"当前 manifest 是 v6/38/166"，需要改为
断言 v7 或显式绑定 `RegistryManifest::v6()`（v1-v6 的 frozen constructor
仍可精确构造，冻结断言测试保持全绿）。

CLI 机器输出是语言无关的 semantic-model v7 payload：Go 实现（路线图
0.14.0）将产出同一 machine schema；payload 内没有 Rust 类型名或
process-local 身份。

## 3. 从脚本迁移到 `consema` CLI

### 3.1 场景：批量检查一批配置文件

旧做法（每文件手写解析循环）。新做法——事实检查不需要选 Profile：

```text
$ consema inspect package.json
consema inspect package.json
  bytes: 424 bytes sha256:06d760863d6c0c66e119747d74a116c12a365315cb423ce3108f4f2b10089a13
  bom: none
  symlink: no
  markers: first non-whitespace '{'
  candidates: json.strict@1 (first non-whitespace byte is '{'); json5.standard@1 (first non-whitespace byte is '{'); jsonc.bounded@1 (first non-whitespace byte is '{')
  ambiguous: yes: first non-whitespace '{' is consistent with multiple profiles of the json family
```

脚本集成用 `--json`：stdout 一行信封，`exit_class`/`diagnostics`/
`redaction` 都是稳定机器事实；digest 在 payload 中。

### 3.2 场景：从配置里取一个值

旧做法（正则或自写 parser）。新做法——显式 Profile + 显式查询请求
（`cli.request@1` 包装 `core.query-definition@1`，第 3 节 cookbook 的
`query-request.json` 逐字节可用）：

```text
$ consema query --profile json.strict --request-file query-request.json
match 0: $.name (key name) = "consema-fixture-app"
match 1: $.version (key version) = "1.0.0"
...
```

查询结果按 source order 返回，`RequireOne` 选择器对缺失/多匹配是
确定性失败（exit 2）——脚本不再需要自行实现 fail-not-null。

### 3.3 场景：跨格式转换

旧做法（自写 parser + writer）。新做法——两阶段显式组合，目标字节只到
stdout（`--output` 是 plan/apply 专属的 manifest/结果写目标，convert 收到即
usage 错误 exit 1——G089 处置口径，2026-08-14；cookbook 第 5 节
`convert-request.json`）：

```text
$ consema convert package.json --profile json.strict --request-file convert-request.json
"name" = "consema-fixture-app"
"version" = "1.0.0"
...
```

未授权 loss 一律原子失败（无目标文档、无部分字节）：YAML sharing/cycle、
INI duplicate、plist UID 等都不能静默降级（cookbook 第 5.1 节三个真实
失败示例）。

### 3.4 场景：批量改 100 个配置文件

旧做法（`sed -i`/`perl -pi`，无前置条件、无恢复）。新做法——plan/apply
两段：`plan` 只读产出 manifest（dry-run 与 commit 相同的 replacements 与
target digest），`apply` 逐文件重验 digest 与 original-bytes 双前置条件后
同目录原子替换，中断后重跑同 manifest 恢复（cookbook 第 6 节完整配方与
stale 示例）。`--output` 落盘 manifest/结果，`--json` 出机器记录。

### 3.5 场景：秘密值出现在输出里

CLI 默认脱敏（保守键名模式）：human 视图与 plan 视图的 `password`/
`token`/`api_key` 等键名及值渲染为 `$REDACTED$`，stderr 报告脱敏计数，
机器输出带 `redaction` 事实；`--show-secrets` 是唯一取消通道（cookbook
第 7 节真实输出）。迁移旧脚本时注意：plan manifest 记录本身（apply 的
字节前置条件）永不脱敏，这是硬门禁 3，不是遗漏。

## 4. 迁移到 CLI 的脚本契约

- **exit code 0-5 稳定分类**（RFC 0015 §5.1）：0 success、1 usage、
  2 data、3 limit、4 precondition、5 internal；6-255 保留。`inspect`
  对歧义/Recovered 报告 exit 0（报告即结果），`query` 对无法形成
  Complete 文档的输入 exit 2，`apply` 对含 stale/failed 条目的批 exit 4。
- **stdout/stderr 分流**：`--json` 下 stdout 恰好一行信封；诊断、进度、
  脱敏提示都在 stderr。脚本按 stdout 解析，绝不过滤 stderr。
- **默认只读**：任何命令无显式参数不写目标文件；`--write`/`--apply`/
  `--output` 是仅有的三档写入显式参数。
- **请求输入是严格 canonical 字节**：`--request-file` 接受 canonical
  tagged JSON 或 PVCE/1；文件不能带尾随换行/空白（canonical 字节形式
  严格判定，非规范输入报 `core.protocol.non-canonical-json@1`）。

## 5. 已知边界（0.12.0 未提供，迁移时不要依赖）

- native 查询域、xml/plist/hcl 的便携域查询、project 的非 json/toml
  报告外部化、materialize/convert 的 provenance map、非 INI 的
  edit 词表与 `edit --write` 都未接线（显式拒绝，不是隐藏缺失）；
- java-properties 源的 project/convert 当前不可达（目标族前缀不匹配，
  2026-08-07 复核发现，已入 0.13.0 API 评审 backlog）；
- 完整清单与 disposition 见 `docs/cookbook.md` 第 10 节与
  `docs/0.13.0-gate-plan.md` §4 M4。

〔superseded 注记（1.0.0-rc.1 起）：本节的"未接线"陈述已部分被交付推翻——
java-properties 源的 project/convert 已随 B-6 修复接线（project_cmd.rs:70-73
族前缀特判）、xml/plist/hcl 便携域查询已随 query_cmd.rs:553-557 分派接线
（conformance 0 skipped 全绿）；其余项（provenance map、非 INI edit 词表、
`edit --write`）仍为 0.12.0-0.13.0 时点边界，随 API 评审 backlog 跟踪。〕

## 6. 相关文档

- 命令配方（含全部请求文件字节）：`docs/cookbook.md`
- 机器协议与 batch 状态机：`docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md`
- crate 边界、v7 注册表与 CLI 章节：`docs/IMPLEMENTATION.md`（第 12 章
  v7、第 14 章 CLI）
- 性能基线：`docs/BENCHMARKS-0.12.0.md`
