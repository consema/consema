# 配置管理平台接入指南（Platform Integration Guide）

- 状态：面向平台构建决策（2026-08-12 用户决策：配置内容处理完全基于 Consema，
  RC 确认后启动）
- 用途：指导基于 Consema 构建的配置管理平台完成接入——架构选型、变更记录
  格式、回滚流程、能力边界、机器协议消费、限制与分片、性能基线
- 权威依据：[RFC 0015](rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md)
  （CLI 机器协议与 batch apply）、[产品路线图 §24 / §4.4](../Consema%201.0.0%20产品路线图与双语言落地设计.md)
  （能力边界）、[cookbook](cookbook.md)（可复制配方）

## 1. 定位：Consema 覆盖"配置内容处理"面

Consema 是**配置内容处理**引擎，覆盖以下能力面：

| 能力面 | 载体 | 说明 |
|---|---|---|
| 解析 | 五语言 SDK / CLI `inspect` | 8 格式家族 / 16 profiles / 无损 Document（注释、顺序、字节保真） |
| 校验 | parse 诊断 + 结构不变量 + formation status | 格式级校验：Recovered/fatal 报告、卡方不变量；**业务 schema 校验是平台职责**（§5） |
| 检索 | SDK 查询 / CLI `query` | 21 query domains，native 语义查询与 portable-value 查询 |
| 投影 | SDK projection / CLI `project` | 显式投影，报告外部化，不猜测 |
| 转换 | SDK conversion / CLI `convert` | 跨格式转换，loss 显式、原子失败 |
| 原子编辑 | SDK 编辑事务 / CLI `edit`（dry-run） | 全部 8 家族（CLI 词表仅 INI，见 §6） |
| 批量变更 | CLI `plan` + `apply` | RFC 0015 契约：只读 plan manifest → 逐文件重验 + 原子写 + 读回验证 |
| 审计 | `inspect` detection facts + manifest + result 状态机 | digest / bom / symlink / markers / ambiguity 事实，全链路可追溯 |

平台在 Consema **外层**构建。来源发现（文件枚举、glob、watch）、overlay
合并、加密、secret 管理、schema 校验平台、配置中心/热更新、IDE/GUI、
业务治理——这些是平台职责，Consema 有意排除（路线图 §24，`1.0.0` 明确
非目标：文件发现和配置优先级合并引擎、Schema validation 与 auto-fix 平台、
配置中心和热更新、secret manager、IDE/GUI、通用语义 Diff/Patch、formatter
产品、任意 expression evaluation、import/include 解析等；§4.4：配置来源
〔环境变量、`.env`、CLI 参数、注册表、Consul/etcd〕与可执行配置是
application/adapter 层，不进入 Document 格式核心）。

Consema 的承诺边界是**单文件内容处理**：`apply` 的"批量原子性"是 manifest
状态机的可恢复性，不是跨文件系统事务（RFC 0015 §2.2、§9.4）；每个写入
在应用前重新验证 digest/precondition（路线图 §10），单文件原子替换
（同目录临时文件 + rename，RFC 0015 §10）。平台层的多文件一致性、编排、
调度全部在平台侧实现。

## 2. 推荐架构

```text
配置管理平台（来源发现 / overlay 合并 / 加密 / watch / 编排 / 审计展示）
        │
        ├── SDK 路径（首选）：五语言任选
        │     解析 → 编辑事务（EditTransaction，8 家族全覆盖）→
        │     ChangeSet / SourcePatch → 材料化
        │
        └── CLI 路径（批量）：consema plan → core.batch-plan@1 → consema apply
               RFC 0015 契约；plan manifest 即平台变更记录格式（§3）
```

- **SDK 路径**：单文件或小批量、需要程序化跨格式修改时，直接使用五语言
  SDK 之一（Rust / Go / TypeScript / Python / Kotlin，语言无关契约
  RFC 0016；五语言同等地位，2026-08-11 决策）。编辑事务
  （`EditTransaction` → `EditPlan`/`ChangeSet` → `SourcePatch`）覆盖全部
  8 格式家族——每家族 5-8 个注册操作，共 16 个 format-local operation
  registry 条目（json 8 / toml 7 / yaml 8 / ini 8 / properties 5 / xml 8 /
  plist 6 / hcl 6，见 fc-manifest-0.13.0.json 与五要素评审 §5）；dry-run
  与提交产生完全相同的 replacements 与 target digest（SECURITY.md）。
  平台不应自己拼接字节改写配置。
- **CLI 路径（批量）**：文件级批量变更一律走 `plan` → `apply`（RFC 0015
  契约；`apply` 只接受先前 `plan` 产生的 manifest，不接受裸操作）。这是
  平台默认的批量变更通道：plan 只读、apply 逐文件重验双前置条件
  （base digest 与 original 字节）后原子写并读回验证。
- **manifest 即变更记录**：`core.batch-plan@1` / `core.batch-result@1`
  （RFC 0015 §8/§9）是语言无关、版本化 schema 的机器记录，平台直接以其
  作为变更记录格式（入库、审计、回滚，见 §3-§4），不必另造格式。

## 3. 变更记录格式：`core.batch-plan@1`

一次批量变更的完整事实都存在于 plan manifest（RFC 0015 §8）：

```text
core.batch-plan@1（Stable，dual transport：canonical JSON / PVCE）：
  schema / product_version / command
  files[]：
    path           文件路径（verbatim 拼写）
    status         "planned" | "failed"
    profile        {id, version}
    source_digest  原文件 sha256（== source_patch.base_digest）
    operations     [{operation: {id, version}, summary}]（操作审计摘要）
    source_patch   core.source-patch@2 记录：base_digest / target_digest /
                   encoding / ordered replacements（old_start/old_end/
                   original 字节 / replacement 字节）/ metadata
    failure_code   （failed 条目）
    diagnostics    （failed 条目）
```

平台侧要点：

- **存档**：每次 `apply` 前的 plan manifest 是变更事实的唯一完整记录，
  平台应入库保存（含 `core.batch-result@1` 的 completed/failed/
  skipped-stale 状态与 target_digest 读回验证结果）。
- **original 字节是事实，不是可选项**：manifest 中的 replacements 携带
  original 字节（SourcePatch 的 precondition facts）；磁盘上的 plan
  manifest **永不被脱敏**（RFC 0015 §8.3、§11.4：redaction 永不触碰
  patch 字节前置条件）。平台存档时可保留原始 manifest（建议另存
  redaction 展示视图，两者分离）。
- **单文件失败不失败整批**：`plan` 中失败文件如实记录为 `failed` 条目，
  `plan` 本身 exit 0（manifest 即完整结果，不伪装成功）；`apply` 中任一
  failed/skipped-stale 条目 → exit 4。平台按 manifest 内容驱动 UI 状态。

## 4. 回滚：文档化第一类场景

Consema **没有内建"回滚"命令**——但机制完备，平台封装为**回滚服务**即可。

### 4.1 回滚 = 逆编辑派生 + apply（同一恢复语义）

回滚服务实现（平台侧，纯数据操作）：

```text
1. 取出存档的 plan manifest（其 source_patch 携带 original 字节与
   base/target digest）
2. 逆编辑派生：交换每个 replacement 的 original ↔ replacement，
   base_digest = 原 target_digest，目标 digest = 原 source_digest，
   其余字段（encoding、顺序、overlap 约束）不变
   → 得到回滚 plan（schema 仍为 core.batch-plan@1，语义完全对称）
3. consema apply <回滚 plan>：恢复字节到变更前状态
```

### 4.2 幂等与并发安全由 RFC 0015 §9.4 恢复语义保证

`apply` 的逐文件三路判定（以**当前磁盘字节**为准，RFC 0015 §9.4）天然
给出回滚的正确性保障：

| 当前磁盘 digest | 判定 | 结果 |
|---|---|---|
| == source_digest（变更前） | 尚未生效 | 执行完整流程（重做） |
| == target_digest（变更后） | 已生效 | 标记 completed，跳过（不重写） |
| 其他 | 外部并发修改 | `skipped-stale`（exit 4），**完全不写** |

- **恢复（同一 plan 重跑）**：`apply` 中断后重跑同一 plan——
  pending 重做、completed 跳过、failed 重报，无需人工判断（RFC 0015
  §9.4；cookbook §6 实测：中断后重跑 completed 跳过、pending 重做全完成）。
- **回滚（逆编辑 plan）**：同一状态机。已回滚的文件（digest == 原
  source）→ 跳过；apply 与回滚并发对同一文件 → 后者 skipped-stale。
- **无跨进程文件锁**：digest 前置条件重验是唯一的并发防御（RFC 0015
  §9.4、§10）——这正是不需要平台加锁的设计：平台只管生成正确的 plan，
  安全性由 Consema 逐文件执行。
- 读回验证失败（target digest 不符）→ `core.source.patch-target-mismatch@1`
  + 环境诊断，如实记录，绝不伪装成功（RFC 0015 §9.3）——回滚失败同样
  被如实报告，平台据 result manifest 呈现。
- 平台可按需把"回滚"建模为：变更记录 → 回滚变更记录（新 plan 存档），
  保持审计链完整（每步都有 manifest 与 result 佐证）。

> 与发布物回滚的区分：路线图/rc-1.0.0-candidate §3 的"回滚"指发布物
> （构建产物）回滚；本文档的回滚指**配置内容变更**回滚，两者互补。

## 5. 能力边界表：平台外层实现

| 能力 | Consema | 平台（外层） | 依据 |
|---|---|---|---|
| 加密 / 密钥管理 | 无 | 平台职责（secret manager 非目标） | 路线图 §24 |
| 变量插值 / 表达式求值 | 禁止（parse/query/project 永不执行配置内程序；HCL 支持 Document/literal 投影/安全编辑，不求值） | 平台在读取/写入前后处理；Consema 只处理最终字节 | 路线图 §24、§4.4、§19.2 |
| schema 校验（业务 schema） | 无（格式级校验齐备：parse 诊断、结构不变量、formation status） | 平台在 Consema 解析结果之上做业务 schema 校验 | 路线图 §24 |
| overlay 合并 / 优先级合并 | 无（单文件内容处理） | 平台合并后把最终字节交给 Consema | 路线图 §24 |
| watch 事件 / 热更新 | 无（配置中心与热更新非目标） | 平台做 watch 与事件分发；变更动作仍走 Consema | 路线图 §24 |
| 三向合并 / 通用语义 Diff/Patch | 无（SourcePatch 是字节精确的语义编辑证明，不是通用 semantic patch；Diff/Patch 非目标） | 平台做三向合并（或基于 §4.2 的 digest 判定拒绝冲突）；Consema 保证单侧字节正确 | 路线图 §24、§19.2 |
| 来源发现 / 文件枚举 / glob | CLI 不做 glob 展开（位置参数；shell 展开或平台枚举，cookbook §6） | 平台侧枚举文件清单，按 §8 分片 | 路线图 §24；cookbook §6 |
| 多文件事务性 | 不做跨文件系统原子性承诺（批量原子性 = manifest 状态机可恢复性） | 平台编排：分批、重试、整体状态聚合 | RFC 0015 §2.2、§9 |
| 跨格式 CLI 操作映射（B-7） | 0.13.0 未接线（CLI 词表仅 INI）；facade `operation_registry` 已提供每 profile 操作清单，映射表归 0.14.0+ | 当前跨格式修改走 SDK 编辑事务（§6）；B-7 是平台可承接的适配面（或等待官方映射） | API-REVIEW-0.13.0.md B-7；cookbook §10 |

Consema 只做单文件内容处理：平台负责"文件集合"这个维度（发现、合并、
调度、状态聚合），Consema 负责"每个文件的内容"这个维度（解析、校验、
编辑、原子写、验证）——职责边界清晰，互不越界。

## 6. CLI 编辑限制与跨格式修改路径

- **CLI 编辑词表仅 INI family**（0.13.0）：`consema edit` 只接受
  `ini.edit.*` 操作；其余 6 个家族的 edit 请求显式拒绝（exit 2，
  `cli.data.invalid-request@1`，消息自明，绝不静默）；`edit --write`
  未接线（dry-run only，`--write` 是 usage 错误 exit 1）；**批量写一律经
  `plan` + `apply`**（cookbook §10 边界 7、§6；pilot-0.13.0 F-1；
  B-8 backlog）。
- **平台跨格式修改走 SDK 编辑事务**：json/toml/yaml/xml/plist/hcl/
  properties 的内容修改通过 SDK `EditTransaction`（16 操作注册表：
  每家族 5-8 个注册操作，见 §2）；CLI 批量路径用于 INI 及未来 B-7
  映射后的全家族。
- **B-7 是平台可承接的适配面**：facade `operation_registry` 已为每
  profile 提供操作清单，平台若需在 CLI 层做跨格式批量编辑，可在平台侧
  实现"格式 → 操作请求"映射（请求体见 RFC 0015 §3.2 与 cookbook §6）；
  0.14.0+ 官方映射落地后切换。
- 能力矩阵速查（cookbook §10）：inspect/query 全家族；project 仅
  json/toml 报告外部化（其余显式拒绝）；convert 全家族（java-properties
  已修复）；edit/plan/apply 仅 INI 词表。

## 7. 机器协议消费

CLI 的机器输出是平台各组件统一解析的单一契约（RFC 0015 §4-§5）：

```text
core.cli-output@1 信封（--json 下每命令恰好一行 canonical JSON + LF）：
  schema / command / exit_class / product_version / payload / diagnostics / redaction
exit_class 六值：success | usage | data | limit | precondition | internal
进程 exit code：0-5（= 是否产出完整结果，非数据健康度，§5.1）
诊断码：core.diagnostic@1 携带注册码（v7 registry 187 码；cli.* 家族 20 码，
        §13.1）
```

- **五语言均可解码**：信封是 `core.portable-value-json@1` 包装的
  PortableValue，五语言协议库（core/graph/protocol/document 层）齐备
  （TS/Py/Kt 的 protocol 模块与 Go `go/protocol`、Rust consema-protocol
  对拍验证，protocol-exchange 差分绿），平台各语言组件统一解析信封、
  exit_class 与诊断码，不必各自处理 stderr 文本。
- 约定：usage 类失败（exit 1）与中断（SIGINT/SIGTERM）**不产生信封**
  （stdout 无字节，诊断在 stderr）；信封只在 {success, data, limit,
  precondition, internal} 中出现。平台据此区分"机器可解析"与"进程级
  失败"。
- stdout 输出数据、stderr 输出诊断、机器与人类输出同源（同一次 facade
  调用，仅渲染不同）；平台消费 `--json` 信封即可。

## 8. 限制与分片

CLI 层冻结预算（RFC 0015 §12，超限是 limit 类错误 exit 3，**绝不截断
伪装成功**）：

| 限制 | 默认值 | 参数 | 码 |
|---|---|---|---|
| 每文件读取上限 | 64 MiB | `--max-bytes` | `cli.limit.file-size@1` |
| plan/apply 批次文件数 | 1000 | `--max-files` | `cli.limit.batch-count@1` |
| plan manifest / 请求输入上限 | 64 MiB | `--max-bytes` 同样适用 | `cli.limit.manifest-size@1` |

平台侧对策：

- **超限分片**：文件集合 > 1000 时切成 ≤1000 的子批次，各自
  `plan` → `apply`，聚合子批次 result；单文件 > 64 MiB 显式报给用户
  （改走 SDK 路径按需处理）。
- **manifest 体积**：含 original 字节的 SourcePatch 计入 manifest 上限；
  大文件批次注意 manifest 总字节，必要时减小批次。
- **glob 由平台展开**：CLI 不做 glob 展开（位置参数）；PowerShell/cmd
  下平台侧枚举文件清单（cookbook §6 明示）。
- SDK 层限制（ParseLimits / ProtocolLimits / SourcePatchLimits）继续
  生效，经既有码上报（`core.parse.resource-limit@1` 等 → exit 3）——
  平台把限制类错误与数据类错误分开呈现。

## 9. 性能基线（容量规划依据）

实测证据（pilot-0.13.0.md §3 冷进程、BENCHMARKS-0.13.0.md §5 冻结行、
pilot-go-0.19.0.md §2.8 对照）：

| 操作 | 量级 | 出处 |
|---|---|---|
| plan（单文件，parse + edit dry-run） | **~0.5-3 ms/文件** | pilot：plan 100 文件 333 ms（≈3.3 ms/文件）；BENCHMARKS：plan 100 INI p50 ≈72 ms（≈0.7 ms/文件） |
| apply（含每文件原子写 + 读回验证） | **~21-45 ms/文件** | pilot：apply 100 文件 2,137 ms（≈21 ms/文件）；BENCHMARKS：apply 100 INI p50 ≈4.5 s（≈45 ms/文件） |
| 单文件冷进程命令 | 5-37 ms（p50/p95/max） | pilot：inspect/query/edit dry-run/convert |
| Go 实现对照 | plan 100 文件 52 ms；apply 100 文件 3.4 s | pilot-go-0.19.0 §2.8 |

规划要点：

- 平台批量编排的预期成本模型：plan ≈ 1-3 ms/文件、apply ≈ 21-45 ms/文件
  （Windows 冷进程、release 构建；apply 大头是文件系统原子写与读回验证）。
- 内存：CLI 命令峰值工作集 2.6-29 MiB 量级（BENCHMARKS §5），大文件
  场景按输入字节线性扩展。
- 超线性风险已闭环：JSON→YAML 转换曾呈 O(n²)（F-2），2026-08-07 修复
  后线性（BENCHMARKS-0.13.0）；平台对超大单文件转换做后端任务化处理即可。

## 10. 快速上手

1. **五语言 SDK 示例**（同一 SDK chain 场景五份等价实现，cookbook §13）：
   - Rust：[consema/examples/sdk_chain.rs](https://github.com/consema/consema-rs/blob/main/consema/examples/sdk_chain.rs)
   - Go：[go/examples/sdk_chain/main.go](https://github.com/consema/consema-go/blob/main/go/examples/sdk_chain/main.go)
   - TypeScript：[typescript/examples/sdk_chain.ts](https://github.com/consema/consema-ts/blob/main/typescript/examples/sdk_chain.ts)
   - Python：[python/examples/sdk_chain.py](https://github.com/consema/consema-py/blob/main/python/examples/sdk_chain.py)
   - Kotlin：[kotlin/examples/SdkChain.kt](https://github.com/consema/consema-kt/blob/main/kotlin/examples/SdkChain.kt)
2. **批量变更配方**：cookbook §6（`plan` + `apply` 完整示例、中断恢复、
   stale 场景）、cookbook §10（能力矩阵与 11 条已知边界）。
3. **协议细节**：RFC 0015（信封 / exit 分类 / plan-result manifest /
   恢复语义 / 资源限制 / 错误代数）。
4. **实测记录**：[pilot-0.13.0.md](pilot-0.13.0.md)（Rust CLI）、
   [pilot-go-0.19.0.md](pilot-go-0.19.0.md)（Go CLI 对照）、
   [BENCHMARKS-0.13.0.md](BENCHMARKS-0.13.0.md)。
5. **能力现状基线**：8 families / 16 profiles / 21 query domains /
   16 operation registries / 187 诊断码（v7 registry）；CLI 11 命令
   （RFC 0015 §6.1），机器 schema 冻结为 v1 candidate（路线图 §15.6）。

## 11. 引用索引

- RFC 0015：CLI 机器协议与 batch apply（信封、exit 分类、manifest、
  恢复语义、fsio、redaction、资源限制、cli.* 错误族）
- 路线图 §10（产品级 CLI 要求）、§15.6（机器 schema 冻结）、§24（明确
  非目标）、§4.4（配置来源/程序边界）
- cookbook §6（批量修改）、§10（能力矩阵与边界）、§11（exit code 速查）、
  §13（五语言 SDK 示例）
- 审计：API-REVIEW-0.13.0.md（B-7/B-8 backlog 处置）、fc-manifest-0.13.0.json
  （16 操作注册表）、pilot-0.13.0.md / pilot-go-0.19.0.md / BENCHMARKS-0.13.0.md
- 契约与兼容：RFC 0016（Go API mapping）、RFC 0020（兼容与支持政策）
