# Consema `1.0.0` 产品路线图与双语言落地设计

## 最终生产级设计基线

---

# 0. 文档地位

本文是 Consema 从 Rust `0.1.0` 经已完成的 `0.2.0`、`0.3.0` 走向 `1.0.0` 的总路线图、产品范围和发布治理基线。

它回答以下问题：

1. `1.0.0` 到底意味着什么；
2. 哪些格式、能力、产品和实现必须在 `1.0.0` 中完成；
3. Rust 与 Go 如何按先后顺序形成两个独立且一致的实现；
4. 每个 `0.x.0` 版本解决什么架构风险；
5. 每个阶段如何证明完成，而不是仅声明完成；
6. 哪些相邻能力即使有价值，也不进入 `1.0.0`；
7. 如何保证哲学统一、语义一致、逻辑自洽、真实有效、完整可靠。

本文不替代《配置内容统一处理标准与 Rust 参考实现》。原文继续定义现有语义基线和永久不变量；本文在不破坏那些不变量的前提下，定义产品化扩展、双语言落地和 `1.0.0` 完成条件。

如果路线图、实现和规范发生冲突，必须先分类：

```text
实现缺陷       → 修复实现
测试缺陷       → 修复测试并说明影响
规范缺口       → 先通过 RFC 冻结语义，再实现
既有契约错误   → 发布新的契约版本，不重新解释旧版本
路线图范围冲突 → 修改路线图，不暗中缩减 1.0.0 承诺
```

## 0.1 已确认的起点

当前 Rust `0.1.0` 已完成：

* PortableValue v1 全类型与 strict equality/hash；
* PVCE/1 canonical encode/strict decode；
* immutable SourceSnapshot/Document、Span、NodeRef；
* `json.strict@1` 与 `jsonc.bounded@1` byte-exact Document；
* JSON native semantic view 与 duplicate member preservation；
* typed Query definition/validation/binding/ordered execution；
* Projection、fidelity、report 与 provenance；
* semantic/literal scalar replacement、transaction 与 ChangeSet；
* resource limits 与语言无关 conformance vectors。

当前仓库约有 17 个 Rust source files、7,383 行 Rust、30 个测试函数和 20 个语言无关 conformance cases。基线已通过 workspace tests、Clippy `-D warnings` 和 rustfmt check。

## 0.2 当前已完成阶段

Rust `0.2.0` 已在不改写 0.1.0 永久不变量的前提下完成第二格式验证：

* 冻结 `toml.1.0@1` 与 RFC 0001；
* 完成 TOML byte-exact Document、原生 item/entry/key/element identity；
* 区分 table、inline table、array、array-of-tables、implicit/dotted table；
* 完成 `toml.native-semantic-query@1`、exact core projection、provenance 与 atomic scalar edit；
* 发布 18 个语言无关 TOML cases 和 Cargo/pyproject/service corpus；
* 通过 `toml-lang/toml-test v2.2.0` TOML 1.0 的 205 个 valid 与 474 个 invalid decoder cases；
* workspace 统一为 0.2.0，公共 facade 导出 JSON 与 TOML 两个格式实现。

Rust `0.3.0` 已完成跨格式 contract/protocol 闭合：冻结 RFC 0002、Semantic Model v1 identity、15 个稳定 payload、canonical JSON/PVCE 双传输、55 个公共 error code、全量 typed payload validation，以及 process-local identity 的拒绝边界。全部 15 个稳定 payload 均由语言无关向量证明双传输等价。

当前仓库为 40 个 Rust source files、19,220 行 Rust、78 个 `#[test]` 函数、70 个语言无关 conformance cases。0.3.0 仍不是生产级 1.0.0；它证明核心公共行为已有不依赖 Rust 私有类型的跨语言 wire contract，下一阶段是 0.4.0 原始内容 Source/Document 平台。

这些阶段证明核心哲学可以跨两个格式并通过语言无关协议成立，但尚未证明：

* raw bytes 与多编码平台成立；
* graph、XML tree、binary document 和 expression-bearing config 成立；
* structural edit、materialization 和正式 CLI 成立；
* Rust API 已达到长期兼容质量；
* Go 可以独立得到相同行为；
* 真实 corpus、安全、性能和供应链达到生产门槛。

因此后续路线不是继续堆叠 parser，而是逐项消除这些未证明条件。

---

# 1. `1.0.0` 的最终定性

`1.0.0` 不是：

* 最小可行产品；
* 最小跨格式闭环；
* 概念验证；
* 只有 JSON 与 TOML 的参考库；
* “大多数接口已经存在”的预览版；
* 依靠 `experimental`、`best effort` 或“以后补齐”成立的版本。

`1.0.0` 是：

> **已经覆盖主流配置格式、具备 Rust 与 Go 两个独立实现、拥有稳定公共契约和完整生产保障，可以被真实系统长期依赖的配置内容处理产品。**

`1.0.0` 必须同时具备四种完成：

```text
标准完成     语义、协议、Capability、Profile 和版本规则已冻结
实现完成     Rust 与 Go 均实现全部 mandatory 1.0 能力
产品完成     SDK、CLI、文档、迁移流程和诊断体验可真实使用
生产完成     安全、性能、兼容、供应链、发布和运维保障成立
```

缺少其中任何一个，都不能发布 `1.0.0`。

---

# 2. 目标、产品与标准的关系

Consema 的长期目标保持不变：

> **建立一套跨格式、跨语言、跨实现都能共同理解、交换并验证的配置内容处理标准。**

但用户首先消费的不是“标准”这个抽象名词，而是可完成工作的产品：

```text
规范与契约
    ↓ 约束
Rust SDK ────── Go SDK
    ↓              ↓
语言无关 Conformance Suite
    ↓
Rust 实现的正式 CLI 与批量变更工作流
```

因此 `1.0.0` 的交付物是：

1. 语言无关规范；
2. 版本化协议与 Capability Registry；
3. 语言无关 Conformance Suite；
4. 完整 Rust SDK；
5. 完整 Go SDK；
6. Rust 实现的正式 `consema` CLI；
7. 示例、迁移手册、兼容政策和安全说明；
8. 可验证、可重现、带签名和物料清单的正式发布物。

CLI 是产品入口，但不是规范权威，也不是第三个实现。Go 与 Rust 必须分别实现标准语义，Go 不允许通过 FFI 调用 Rust 来冒充独立实现。

`1.0.0` 不提供 Java、TypeScript、Python 或其他语言 SDK。语言无关协议仍应允许未来实现加入，但首个稳定版本只对 Rust 和 Go 作出产品承诺。

---

# 3. 不可改变的统一哲学

从 `0.1.0` 到 `1.0.0`，所有扩展必须继续服从以下哲学。

## 3.1 真实状态只有 Document

```text
Document
≠ PortableValue
≠ PortableGraph
≠ EvaluationResult
≠ Executable Program
```

* Document 保存原始内容事实；
* Native Semantic View 表达格式本义；
* PortableValue 表达封闭的共同纯值；
* PortableGraph 表达确有共享、别名或环的图值；
* EvaluationResult 只存在于显式求值边界；
* 所有观察层均从不可变 Document 派生。

## 3.2 共同机制统一，格式差异显式

统一：

* 快照、完成、失败和取消语义；
* Span、NodeRef、位置与身份职责；
* Query 生命周期和确定顺序；
* Projection、Materialization、Provenance 和 Report 框架；
* EditTransaction、冲突和 ChangeSet；
* Diagnostic、Profile、Capability 和 Conformance；
* 资源限制、安全和版本治理。

不强制统一：

* JSON member、TOML table、YAML node、XML element、HCL block；
* 注释和 trivia 归属；
* YAML anchor/alias/tag；
* XML namespace、attribute、CDATA、PI 和 mixed content；
* HCL expression、template 与 block；
* 各格式的结构编辑和字面量生成规则。

## 3.3 默认不猜测

所有可能改变含义的行为必须由请求、Profile 或 Policy 明确授权，包括但不限于：

* 重复键折叠；
* YAML alias 展开；
* YAML tag 构造；
* XML attribute/element/object 映射；
* HCL expression 求值；
* INI 插值和大小写折叠；
* Java Properties 编码解释；
* 数值降精度；
* 日期识别；
* 格式化；
* 跨快照 NodeRef 迁移；
* 跨格式结构重写。

没有明确授权时，一律拒绝或保持为原生结构，不进行隐式转换。

## 3.4 完成产物不能半成功

以下对象只有完整成功或明确失败：

* Document；
* PortableValue；
* PortableGraph；
* ExecutableQuery；
* CompleteProjection；
* CompleteMaterialization；
* committed EditTransaction；
* applied SourcePatch；
* completed batch operation。

恢复节点、诊断、事件流和失败报告可以保存局部事实，但不得伪装成完整成功。

## 3.5 标准定义行为，实现保留自由

标准不规定：

* 使用哪一个 parser backend；
* arena、rowan、green tree 或其他内部结构；
* Rust 与 Go 使用相同的类或包布局；
* 是否缓存派生观察；
* 内部算法和索引形式。

标准必须规定：

* 接受什么；
* 产生什么；
* 结果顺序和身份是什么；
* 什么是损失、失败和冲突；
* 资源耗尽如何报告；
* 同一契约在两种语言中如何被共同测试。

---

# 4. `1.0.0` 格式范围

## 4.1 选择方法：先看跨生态事实，再决定产品承诺

格式范围不能由个人偏好、文件扩展名数量或某一个 Rust crate 决定。路线图采用以下证据：

1. 主流语言的通用配置库是否正式支持；
2. 是否跨两个以上生态重复出现；
3. 是否承载大量现实配置，而不只是数据交换；
4. 是否具有独立且值得保留的语义；
5. 是否能在 Rust 和 Go 中达到完整 capability matrix；
6. 是否属于静态内容格式，而不是配置来源或可执行程序。

本次调查取样如下。`✓` 表示库或平台提供正式文件支持；`扩展` 表示需要可选 loader；`来源` 表示被当作配置来源而不是静态内容格式。

| 生态与代表库 | JSON | JSON5 | YAML | TOML | INI | XML | Properties | HCL | plist | 语言代码 / env |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Rust [`config`](https://docs.rs/config/latest/config/enum.FileFormat.html) | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — | — | RON/Corn |
| Go [Viper](https://github.com/spf13/viper) | ✓ | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | envfile/远程来源 |
| Java [Apache Commons Configuration](https://commons.apache.org/proper/commons-configuration/) | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | — | ✓ | JNDI/系统来源 |
| .NET [Configuration Providers](https://learn.microsoft.com/dotnet/core/extensions/configuration-providers) | ✓ | — | — | — | ✓ | ✓ | — | — | — | 环境/命令行来源 |
| Python [Dynaconf](https://www.dynaconf.com/settings_files/) | ✓ | — | ✓ | ✓ | ✓ | — | 扩展 | — | — | `.py`/`.env` loader |
| Node.js [cosmiconfig](https://www.npmjs.com/package/cosmiconfig) / [node-config](https://github.com/node-config/node-config/wiki/Environment-Variables) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | JS/TS 模块 |
| C++ [Boost.PropertyTree](https://www.boost.org/doc/libs/latest/doc/html/property_tree/parsers.html) / [Qt QSettings](https://doc.qt.io/qt-6/qsettings.html) | ✓ | — | — | — | ✓ | ✓ | — | — | ✓ | registry/native source |

这个矩阵只用于判断行业覆盖，不把这些库的“读取成 map”语义当作 Consema 标准。它得出三个结论：

* JSON、YAML、TOML、INI 是跨生态通用主线；
* XML、Properties、plist 是成熟平台中不能忽略的静态配置格式；
* HCL 虽非跨语言通用格式，但在基础设施配置中具有独立且重要的生产价值。

## 4.2 `1.0.0` Mandatory GA 格式家族

`1.0.0` 最终包含以下八个格式家族：

| 层级 | 格式家族 | Mandatory Profile | 必须保存的核心真实性 |
|---|---|---|---|
| 通用主线 | JSON family | `json.strict@1`、`jsonc.bounded@1`、`json5.standard@1` | duplicate member、精确数字、dialect syntax/trivia |
| 通用主线 | YAML family | `yaml.1.2-core@1`、`yaml.1.1-compat@1` | stream、tag、anchor、alias、任意 key、图语义 |
| 通用主线 | TOML | `toml.1.0@1` | table、inline table、array of tables、dotted key、日期时间 |
| 通用主线 | INI family | `ini.portable@1`、`ini.windows@1`、`ini.python-configparser@1` | section、entry、comment、重复项、方言差异 |
| 通用/企业 | XML | `xml.1.0-safe@1` | namespace、attribute、mixed content、CDATA、comment、PI |
| 通用/企业 | Properties family | `java-properties.reader@1`、`java-properties.latin1@1` | logical line、escape、separator、encoding、duplicate |
| 平台生态 | Property List | `plist.xml@1`、`plist.binary@1` | dict、array、data、date、UID、二进制对象引用 |
| 基础设施 | HCL family | `hcl.native@1`、`hcl.tfvars@1` | body、attribute、block、expression、template；不隐式求值 |

这里的“八个家族”不是八个 parser 开关，而是八套完整、可验证的格式产品。JSONC/JSON5 属于 JSON 家族；YAML 1.1/1.2 和 INI dialect 属于各自家族，不通过顶层格式数量制造虚假覆盖率。

上述范围不是“能识别文件扩展名”。一个家族只有在其全部 mandatory Profile 完成第 8 节 capability matrix 后，才可标为 GA；任意一个表内家族未达到生产门槛，Consema 都不能发布 `1.0.0`。

TOML 采用 [TOML v1.0.0](https://toml.io/en/v1.0.0)。YAML 采用 [YAML 1.2.2](https://yaml.org/spec/1.2.2/) 并用独立兼容 Profile 处理 1.1 差异。JSON5 采用其[正式规范](https://spec.json5.org/)。XML 安全 Profile 以 [XML 1.0 Fifth Edition](https://www.w3.org/TR/xml/) 为语法基础，但设置更严格的实体和网络安全边界。HCL 以 [HCL Native Syntax Specification](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md) 为格式事实基础。

Java Properties 的字符流和 Latin-1 字节流是两个输入契约，以 [`java.util.Properties`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Properties.html) 的公开格式说明为基线。

## 4.3 INI 不是一个语法，必须作为格式家族

INI 在所有被调查生态中反复出现，但没有统一标准；不同实现对 comment、separator、case、continuation、duplicate、空值和 interpolation 的解释不同。因此禁止发布含糊的 `ini@1`。

`1.0.0` 至少冻结：

```text
ini.portable@1   跨主流实现可安全交换的明确子集
ini.windows@1    Windows/常见桌面软件语义
ini.python-configparser@1  Python ConfigParser 常见语义边界
```

三者共享 line-oriented 基础机制，但分别定义合法输入、原生语义、诊断、查询、生成和编辑。一个文件采用哪个 Profile 必须由调用方或可靠的外部上下文指定；扩展名 `.ini` 不能自动解决 dialect 歧义。

每个 Profile 必须冻结：

* 字符编码与 BOM；
* section 与 key 合法形式；
* `=`、`:` 等 separator；
* quote 与 escape；
* comment 与 inline comment；
* continuation/multiline；
* duplicate section/key；
* case sensitivity；
* 空值、缺失值和空字符串；
* interpolation 是否存在以及是否执行；
* 错误恢复；
* canonical materialization。

## 4.4 配置格式、配置来源与配置程序必须分开

以下内容不是 `1.0.0` 核心格式：

| 类别 | 例子 | 处理方式 |
|---|---|---|
| 配置来源 | 环境变量、`.env` loader、CLI 参数、注册表、JNDI、Consul/etcd | application/adapter 层，不进入 Document 格式核心 |
| 可执行配置 | JavaScript、TypeScript、Python 配置模块 | 只在未来 Evaluation 边界处理，不在 parse/project 中执行 |
| 求值型语言 | HOCON、Jsonnet、Dhall、CUE | 等独立 evaluation/import RFC 成熟后再决定 |
| 语言专属格式 | RON、Corn、CSON | `1.x` 格式包候选，不进入首个稳定承诺 |
| 新兴/小众格式 | KDL、HJSON、UCL 等 | 通过未来格式准入 RFC |
| 应用专属 DSL | Nginx、Apache、Git config 等 | 独立 format pack，不冒充通用格式 |

`.env` 可以未来拥有安全的 source adapter，但它不计入“支持的配置内容格式数量”，也不影响 `1.0.0` 核心格式完成度。

HCL 被纳入并不意味着放弃“文档、值和程序分离”。Consema `1.0.0` 支持 HCL 的 Document、native syntax/semantics、literal projection 和安全编辑；变量、函数、template 和应用上下文求值仍然禁止隐式执行。

## 4.5 格式准入门槛

任何未来正式格式必须同时满足：

1. 有清晰且可冻结的语法/Profile；
2. 有足够真实的配置使用场景；
3. 能定义 Native Semantic View；
4. 能定义 lossless syntax coverage；
5. 能解释其与 PortableValue、PortableGraph 或 ExtendedValue 的关系；
6. 能定义 Query、Projection、Materialization 和 Edit 边界；
7. 能提供合法、非法、恢复和恶意语料；
8. Rust 与 Go 都能独立实现；
9. 不要求破坏永久不变量；
10. 有维护责任和版本升级策略；
11. 能说明自己属于静态格式、来源 adapter 还是 evaluation language；
12. 不依赖“先丢失原始结构再写回”的伪无损实现。

---

# 5. `1.0.0` 的公共数据模型

## 5.1 SourceSnapshot 扩展为原始字节事实

`0.1.0` 的实现范围只接受 UTF-8。生产范围包含 XML UTF-16、Java Properties Latin-1 等现实输入，因此 `1.0.0` 必须把 SourceSnapshot 完整定义为：

```text
SourceSnapshot
  raw bytes
  content identity/digest
  declared or detected encoding facts
  decoding result and diagnostics
```

规则：

* 原始字节永远保留；
* Span 默认仍以原始 byte offset 计量；
* decoded character location 是派生位置，不替代 byte Span；
* BOM、声明编码和调用方指定编码发生冲突时，不猜测；
* 未修改 Document 必须输出完全相同的原始字节；
* 修改后的编码策略必须由 Profile 与 RepresentationPolicy 决定；
* 解码失败不能产生伪造的完整 Document。

## 5.2 Document 仍是唯一状态

每个格式的 Document 必须：

* 不可变；
* 绑定一个 SourceSnapshot；
* 拥有确定的形成状态；
* 可精确 render；
* 提供完整 source coverage；
* 提供 snapshot-bound NodeRef；
* 不暴露 backend AST；
* 可安全并发读取；
* 不在 getter 中隐式执行 evaluation、I/O 或网络请求。

## 5.3 PortableValue v1 保持封闭

现有 PortableValue v1 不因新增格式而扩充万能类型。以下仍然成立：

* YAML alias 不塞入 PortableValue；
* XML element 不塞入 Object 并假装无损；
* HCL expression 不塞入 String 并假装已经求值；
* missing、diagnostic、error node 不属于 PortableValue；
* 核心相等和 PVCE/1 不被新格式重新解释。

## 5.4 PortableGraph 独立建立

YAML 的 anchor、alias、共享节点和可能的环要求正式图模型。`1.0.0` 必须通过独立 RFC 建立：

```text
PortableGraph@1
PGCE/1
core.portable-graph-query@1
```

PortableGraph 至少定义：

* graph root 或 stream roots；
* graph-local node identity；
* scalar、sequence、mapping node；
* ordered mapping associations；
* tag；
* shared reference 与 cycle；
* strict graph equality；
* canonical graph encoding；
* 资源限制；
* 与 PortableValue 的显式降维策略。

PortableGraph 不进入 PortableValue，也不改变 PVCE/1。只有确实存在图语义的格式才使用它。

## 5.5 ExtendedValue 的职责保持克制

ExtendedValue 只表达拥有正式 TypeId、版本、相等和编码契约的扩展值。可能的 `1.0.0` 扩展包括：

* 显式保留的 HCL unevaluated expression；
* 显式保留的 XML expanded name 或 element tree 投影；
* 用户选择保留的 YAML custom tag payload。

它不能成为“遇到无法建模的内容就塞 bytes”的逃生口。任何扩展都必须拥有独立 Capability、规范和 conformance vectors。

---

# 6. 统一操作链条

`1.0.0` 的完整只读链条：

```text
raw source bytes
→ SourceSnapshot
→ Document
→ Lossless Syntax View / Native Semantic View
→ Validated + Bound Query
→ ordered, typed matches
→ explicit ProjectionRequest
→ CompleteProjection
   ├─ PortableValue / PortableGraph / ExtendedValue
   ├─ ProjectionReport
   └─ ProvenanceMap
```

完整生成与转换链条：

```text
PortableValue / PortableGraph / supported ExtendedValue
+ MaterializationRequest
→ CompleteMaterialization
   ├─ new Document
   ├─ MaterializationReport
   └─ ProvenanceMap
```

跨格式转换必须是两个显式操作的组合：

```text
source Document
→ Projection
→ portable representation
→ Materialization into target Profile
→ target Document
```

转换总报告由 projection report 与 materialization report 组合而成。任何损失只要未被 policy 授权，整个转换失败。

完整编辑链条：

```text
immutable Document
→ typed Query
→ exact NodeRef(s)
→ EditTransaction
→ validation + conflict detection
→ atomic commit
→ new Document + ChangeSet
→ optional snapshot-bound SourcePatch
```

文件系统应用链条属于 CLI/application 层：

```text
ChangeSet / SourcePatch
→ dry-run and review
→ precondition recheck
→ temporary write
→ flush + atomic replace where supported
→ result manifest
```

核心 SDK 不负责文件发现、配置合并或部署；正式 CLI 可以负责安全的文件读写，但不能把这些行为塞回 Document 核心。

---

# 7. Query、Projection、Materialization 与 Edit 的最终边界

## 7.1 三类 Query Domain

`1.0.0` 至少拥有：

1. `core.portable-value-query@1`；
2. `core.portable-graph-query@1`；
3. 每个格式的 Native Semantic Query Domain；
4. 每个格式独立的 Lossless Syntax Query Domain。

Syntax Query 不建立万能 CST。示例：

```text
json.lossless-syntax-query@1
toml.lossless-syntax-query@1
yaml.lossless-syntax-query@1
xml.lossless-syntax-query@1
hcl.lossless-syntax-query@1
```

每个 Domain 独立定义 role、operator、ordering 和 conformance。跨 Domain 转换必须显式。

## 7.2 Projection

Projection 必须：

* 从 Document/native/graph 事实出发；
* 由显式 target 与 policy 控制；
* 成功时返回完整值、报告和 provenance；
* 失败时返回失败尝试和已有报告；
* 不静默折叠 duplicate、alias、tag、mixed content 或 expression；
* 对跨格式可组合。

## 7.3 Materialization

Materialization 是新建目标 Document，不是隐式 formatter。

它必须定义：

* target Profile；
* input representation；
* representability policy；
* duplicate、key、number、time、tag 和 graph policy；
* style preset；
* encoding 与 newline policy；
* 完整报告；
* 输入到输出 NodeRef/Span 的 provenance。

如果目标格式无法表达输入，默认失败。Canonical style 只适用于新文档或调用方显式请求的完整重写。

## 7.4 Edit

`1.0.0` 的共同编辑机制包括：

* scalar semantic/literal replacement；
* transaction、precondition 和 conflict；
* snapshot binding；
* atomic commit；
* ChangeSet；
* exact untouched-byte guarantee；
* batch planning；
* reversible source replacements when the original snapshot is retained。

结构编辑不伪造为万能跨格式操作。每个格式发布自己的 versioned operation，例如：

```text
json.edit.insert-member@1
toml.edit.insert-entry@1
yaml.edit.insert-mapping-pair@1
xml.edit.insert-element@1
hcl.edit.insert-attribute@1
```

每个 mandatory 格式至少支持：

* 替换可编辑值；
* 插入本格式的常用关联或元素；
* 删除本格式的常用关联或元素；
* rename 本格式中语义允许重命名的 key/name；
* sequence/list 中常用的插入与删除；
* 多操作原子事务；
* 明确的格式专属不可编辑原因。

Move/reorder 只有在格式原生语义与 source ownership 清楚时才提供，不通过 delete+insert 冒充完全保真。

## 7.5 SourcePatch

`1.0.0` 必须定义 snapshot-bound `SourcePatch@1`，用于审阅和安全应用已完成规划的 byte replacements。它必须包含：

* base content digest；
* source encoding facts；
* ordered non-overlapping replacements；
* original-byte preconditions；
* target digest（可预计算时）；
* change metadata 和 redaction rules。

SourcePatch 不是 Document semantic diff，也不保证跨任意快照迁移。万能 Diff/Patch 仍不属于 `1.0.0`。

---

# 8. 每个 GA 格式的 Mandatory Capability Matrix

一个格式只有全部满足以下能力，才算进入 `1.0.0`：

| 能力组 | Mandatory 行为 |
|---|---|
| Source | 受支持编码、BOM/newline 事实、稳定 byte span、content digest |
| Formation | Complete、Recovered、FatalFormationFailure 的确定边界 |
| Lossless | 未修改字节精确往返；token/trivia/error region 完整覆盖 |
| Native | 格式专属结构、身份、重复项、顺序和原生标量完整保留 |
| Diagnostics | 稳定 code、category、severity、location、确定顺序 |
| Query | native 与 syntax typed query；预验证；确定结果；限制与取消 |
| Projection | PortableValue/Graph/Extended target、policy、fidelity、report |
| Provenance | 可区分重复项、共享节点和结构重编码来源 |
| Materialization | 从支持的 portable representation 生成合法新 Document |
| Edit | scalar + 常用结构编辑；事务原子；冲突；最小修改 |
| Change | ChangeSet、untouched-byte proof、snapshot-bound SourcePatch |
| Recovery | 损坏输入可分析但不能伪造语义完成 |
| Security | 无隐式网络/I/O/evaluation；全部资源可限制 |
| Conformance | 合法、非法、恢复、恶意、查询、投影、生成、编辑向量 |
| Quality | fuzz、property、differential、corpus、benchmark、panic-free |
| Languages | Rust 与 Go 对 mandatory 行为一致 |

禁止使用以下宣传替代上表：

* “基于某成熟 parser，所以已生产可用”；
* “能 parse 成 map”；
* “大部分文件可以工作”；
* “unsupported 节点会忽略”；
* “Go 版本输出看起来差不多”；
* “后续 patch 版本再补安全限制”。

---

# 9. 格式专属真实性要求

## 9.1 JSON / JSONC / JSON5

必须保留：

* 重复 member 的数量、顺序和身份；
* number 原始表示与精确语义；
* string escape 表示；
* JSONC/JSON5 comment 与 trailing comma；
* JSON5 identifier key、单引号、Infinity/NaN、扩展数值语法等正式差异。

Profile 之间不能通过“宽松模式 bool”混合。每个 Profile 的合法输入和 canonical materialization 独立版本化。

## 9.2 TOML

必须保留：

* table、inline table 和 array of tables 的原生身份；
* dotted key 的 source 表达与语义路线；
* key/value association；
* 注释、空白、顺序和 literal style；
* integer/float/date/time/local/offset datetime；
* 重定义与冲突诊断；
* TOML 特有的插入位置和 table ownership。

不得把 dotted key 展开后的 Object 当作唯一文档事实。

## 9.3 YAML

必须保留：

* stream 与多 document；
* block/flow style；
* scalar style 与 chomping；
* explicit/implicit tag；
* anchor、alias、sharing 和 cycle；
* sequence、mapping、任意类型 key；
* mapping association 的 source 顺序和身份；
* directive、document marker、comment 和 trivia；
* 1.2 与 1.1 兼容 Profile 的标量解析差异。

安全默认：

* 不实例化语言对象；
* 不执行 custom tag constructor；
* alias expansion 有深度、节点数和放大比限制；
* merge key 若支持，属于独立兼容 Capability；
* 投影为 PortableValue 前必须显式处理 sharing、cycle、tag 和非字符串 key。

## 9.4 INI / Java Properties

三者可以共享 line-oriented parser infrastructure，但不能共享未经验证的语义模型。

必须分别保留：

* physical line 与 logical line；
* section/assignment/property 身份；
* 原始 key/value text、quote、escape 和 comment；
* 重复项及其顺序；
* 空值、缺失值和空字符串的差异；
* encoding 与 newline；
* continuation/multiline 的 Profile 规则。

默认不进行：

* INI interpolation；
* 环境变量读取；
* Java Properties defaults 链合并；
* key 大小写折叠。

## 9.5 XML

XML Native Semantic View 至少包含：

* document、prolog 和 document element；
* expanded name、prefix 与 namespace binding；
* ordered child content；
* attribute association；
* text、CDATA、comment、processing instruction；
* mixed content；
* character/entity reference 的 source 表达与解析事实；
* encoding declaration 与原始编码。

安全默认：

* 禁止外部实体获取；
* 禁止网络；
* DTD validation 不属于默认 parse；
* entity expansion 严格限制；
* XML namespace-aware 语义不能关闭后继续宣称同一 Profile；
* XPath 不直接作为 Consema Query 协议；可以未来通过独立 adapter/RFC 提供。

XML 到 Object 的映射没有唯一正确答案，因此只能通过显式 Projection Target/Policy 提供，不存在默认 XML-to-JSON 规则。

## 9.6 Property List

Property List 是一个独立值格式家族，不等同于“任意 XML”。Apple 的 [PropertyListSerialization](https://developer.apple.com/documentation/foundation/propertylistserialization) 明确定义其值空间主要由 dictionary、array、data、string、date、number 和 boolean 组成，并同时提供 XML 与 binary 表示。

必须保留：

* XML 与 binary representation 的格式身份；
* dictionary key/value association；
* array order；
* string、data、date、integer、real 和 boolean 的精确类型；
* binary plist object table、offset table 和 object reference；
* XML plist 的 tag、trivia 与 source representation；
* UID 等实现中真实存在但不属于普通 XML plist 值表的扩展类型；
* 编码、版本和不支持对象的诊断。

XML plist 可以复用 XML 的底层 source infrastructure，但必须产生 plist native semantics。Binary plist 是二进制 Document，不伪造 token/trivia；它仍要支持原始 byte round-trip、结构 Span、NodeRef、Projection、Materialization 和原子 byte edit。

## 9.7 HCL

必须保留：

* body、attribute、block type、labels 和 nested body；
* expression 与 template 的完整 syntax identity；
* literal 与 derived expression 的差异；
* comment、trivia 和 source ranges；
* HCL 自身对 attribute 重复的约束；
* block 顺序和身份。

默认不进行：

* variable lookup；
* function call；
* template interpolation；
* include/import；
* Terraform provider/schema 解释；
* 任何应用专属 evaluation。

只有 literal-complete 的表达式可以自然投影为 PortableValue；其他表达式必须留在 native view，或在调用方显式请求时投影为正式 ExtendedValue。

---

# 10. 产品级 CLI

Rust `consema` CLI 是 `1.0.0` 正式产品组成部分，至少提供：

```text
consema inspect
consema capabilities
consema query
consema project
consema materialize
consema convert
consema edit
consema plan
consema apply
consema conformance
consema explain
```

要求：

* 默认只读或 dry-run；
* 写入必须显式确认参数；
* stdout 输出数据，stderr 输出诊断，exit code 稳定；
* 支持人类可读与机器可读结果；
* 机器结果拥有 versioned schema；
* query/edit 请求可通过 PVCE 或严格 JSON protocol 输入；
* 批量操作产生 manifest；
* 每个写入在应用前重新验证 digest/precondition；
* 尽可能使用同目录临时文件和原子替换；
* 不声称跨文件系统多文件原子性；
* 中断后可根据 manifest 判断完成、失败和未执行项；
* 默认对可能的 secret value 做诊断和日志脱敏；
* symlink、权限、所有者、换行和编码行为有明确政策；
* 不在 parse/query/project 中执行配置里的程序。

CLI 的便利选择不能成为核心语义默认值。例如 CLI 可以要求用户选择 duplicate policy，但不能替用户静默选择 LastWins。

---

# 11. Rust 与 Go 的双实现原则

## 11.1 顺序

```text
Rust 全部功能实现
→ Rust 全部门禁通过
→ Rust Feature-Complete Baseline 冻结
→ 才开始 Go 正式实现
→ Go 反向审计规范
→ 双语言共同通过 conformance
→ 1.0.0
```

Go 开发不得提前与 Rust 格式实现并行，以免在语义尚未稳定时复制返工。

## 11.2 Go 不是 Rust 的翻译

Go 实现必须：

* 不使用 Rust FFI；
* 不序列化 Rust 私有 AST；
* 使用 Go 惯用的 package、error 和 iterator 设计；
* 保持 completed public objects 的逻辑不可变性；
* 在并发读取、取消和资源限制上符合 Go 生态习惯；
* 只在语言无关行为上与 Rust 完全一致。

Rust 和 Go 可以拥有不同的内部树、缓存和算法。它们必须在以下方面一致：

* PortableValue/PortableGraph 相等；
* PVCE/PGCE 字节；
* protocol decoding；
* Capability 声明；
* parse formation；
* diagnostic code/category/order；
* native result 的规范化事实；
* query count/identity/order；
* projection/materialization report；
* edit 和 conflict 结果；
* resource-limit completion semantics。

## 11.3 Go 发现问题时的处理

Rust Feature-Complete Baseline 不是“Rust 永远正确”的声明。若 Go 实现证明规范存在歧义或 Rust 行为不可移植：

1. 暂停对应 Go capability；
2. 建立最小跨语言反例；
3. 判断是实现 bug、测试 bug 还是规范缺口；
4. 先修正规范和 conformance；
5. 如公共行为改变，发布新的 contract ID；
6. Rust 先通过修订向量；
7. Go 再继续实现。

禁止为了保持 Rust 既有输出而把偶然实现细节提升为标准。

## 11.4 发布版本关系

Rust crates、Go module、规范和 suite 各自有版本，但稳定发布使用同一产品 release train：

```text
Consema Product 1.0.0
  Rust crates 1.0.0
  Go module v1.0.0
  Specification v1 release set
  Conformance release set 1.0.0
```

包版本不替代 contract version。`core.pvce.full@1` 的 `@1` 与 crate/package 的 `1.0.0` 是不同维度。

---

# 12. 版本治理与推进规则

## 12.1 `0.x.0` 是架构门，不是日期标签

每个 `0.x.0` 只解决一个可清晰验收的主要风险。版本达到门禁才发布；不得因为排期到达、代码量足够或演示可运行而晋级。

规则：

* `0.x.0`：新的架构能力或格式家族里程碑；
* `0.x.y`：修复该里程碑缺陷，不偷偷扩展范围；
* `-alpha.n`：语义和 API 仍允许明显变化；
* `-beta.n`：功能完整，接受兼容性和语料反馈；
* `-rc.n`：只有阻断缺陷、安全问题和文档错误可修改；
* `1.0.0`：稳定公共 API、协议和产品承诺开始生效。

在 `0.x` 阶段，破坏性变更必须：

1. 出现在 minor 版本而不是 patch；
2. 有迁移说明；
3. 不重解释已发布的 `namespace.contract@N`；
4. 更新 conformance；
5. 同步列出 Rust API、protocol 和 CLI schema 影响。

Cargo 对 `0.y.z` 使用“最左非零位”判断兼容区间，因此每个新的 `0.y.0` 应被视为潜在不兼容边界；稳定后遵循 [Cargo SemVer compatibility](https://doc.rust-lang.org/cargo/reference/semver.html)。Go 的 `v0` 同样不承诺稳定，而 `v1` 表示稳定使用承诺，遵循 [Go module version numbering](https://go.dev/doc/modules/version-numbers)。

## 12.2 规范契约与产品版本正交

产品版本描述一次发布；contract version 描述一项不可变行为。

```text
Product 0.7.0 可以同时支持：
  core.pvce.full@1
  core.query-definition@1
  yaml.native-semantic-query@1
  yaml.native-semantic-query@2
```

增加新契约不要求删除旧契约。旧契约何时停止支持必须遵循公开生命周期政策。

## 12.3 RFC-first 范围

以下能力必须先完成 RFC，再进入实现：

1. Source encoding 与 raw-byte snapshot；
2. 语言无关 protocol schema closure；
3. Lossless Syntax Query；
4. Materialization；
5. structural edit 与 SourcePatch；
6. PortableGraph 与 PGCE；
7. YAML Profile 与 tag/alias policy；
8. INI 三 Profile；
9. XML safe Profile；
10. plist XML/binary model；
11. HCL unevaluated semantics；
12. Go public API mapping；
13. CLI machine protocol 与 batch apply。

RFC 必须包含：动机、非目标、数据模型、状态机、错误代数、资源限制、安全、版本、conformance 和 rejected alternatives。只有接口草图不算完成 RFC。

## 12.4 阶段完成的共同定义

任何里程碑标记完成前，必须同时具备：

* 规范文本；
* public API；
* capability registry；
* 正向与负向 conformance vectors；
* 单元、集成、property 和资源限制测试；
* 至少一个真实使用示例；
* 安全与性能基线；
* migration note；
* 无未分类的 P0/P1 缺陷。

代码合并、测试样例数量或 README 示例都不能单独代表里程碑完成。

---

# 13. 总路线图

```text
0.1.0  JSON/JSONC 与核心语义证明                         已完成
  ↓
0.2.0  TOML 第二格式验证                                已完成
  ↓
0.3.0  跨格式核心与语言无关协议闭合                     已完成
  ↓
0.4.0  原始字节 Source / encoding / syntax query 平台    已完成
  ↓
0.5.0  Materialization / conversion / structural edit    已完成
  ↓
0.6.0  JSON family 生产完成（含 JSON5）                  Rust
  ↓
0.7.0  YAML family + PortableGraph/PGCE                  Rust
  ↓
0.8.0  INI family + Properties family                    Rust
  ↓
0.9.0  XML                                               Rust
  ↓
0.10.0 plist XML/binary                                  Rust
  ↓
0.11.0 HCL native/tfvars                                 Rust
  ↓
0.12.0 Rust SDK + CLI 产品集成                           Rust
  ↓
0.13.0 Rust 生产加固与 Feature-Complete Gate             Rust 全通过
  ↓
0.14.0 Go core / PVCE / PGCE / protocol                  Go 开始
  ↓
0.15.0 Go Source/Document + JSON family + TOML            Go
  ↓
0.16.0 Go YAML + INI + Properties                        Go
  ↓
0.17.0 Go XML + plist                                    Go
  ↓
0.18.0 Go HCL + Materialization/Edit parity              Go
  ↓
0.19.0 双语言一致性、产品 Beta 与真实项目验证            Rust + Go
  ↓
1.0.0-rc.n  稳定候选
  ↓
1.0.0  完整生产级产品
```

版本数量可以在实际执行中增加，但不得压缩语义门禁。若某个阶段过大，可以拆成更多 minor 版本；不能为了保持编号漂亮而把未完成能力滚入下一阶段。

---

# 14. Rust 阶段详细计划

## 14.1 `0.2.0`：TOML 第二格式验证

目标：证明 `0.1.0` 的 Document、NodeRef、Query、Projection、Provenance 和 Edit 没有过拟合 JSON。

落实状态：已完成（2026-08-04）。规范见 `docs/rfcs/0001-toml-1.0-profile.md`，实现见 `consema-toml`，语言无关证据见 `conformance/vectors/toml-v1.json`，上游证据见 `docs/UPSTREAM-TOML-TEST.md`。

交付：

* `toml.1.0@1` Profile；
* lossless TOML Document；
* table、inline table、array of tables、dotted key native view；
* TOML scalar 和 temporal types；
* `toml.native-semantic-query@1`；
* 按原生语义 Projection 到 Object、Sequence 与 core scalar/temporal types；
* TOML provenance；
* scalar replacement 与 TOML representation policy；
* TOML conformance vectors；
* upstream TOML suite 与真实 Cargo/pyproject/config corpus。

硬门禁：

* 未修改 TOML 字节精确往返；
* table identity 与 dotted key source identity 不丢失；
* date/time 与 PortableValue 无降精度；
* JSON 专属类型不得泄漏为跨格式公共类型；
* 如果两格式共同机制需要根本重写，必须在本阶段完成，不把错误抽象带入第三格式。

完成证据：18/18 TOML language-neutral cases、205/205 upstream valid cases、474/474 upstream invalid cases、45 项 workspace test、rustfmt、Clippy/rustdoc `-D warnings`、RustSec audit 与 cargo-deny 四类供应链门禁全部通过。table/entry/key/element 使用 TOML 专属角色，JSON 专属类型没有提升为跨格式事实。

本版本不加入 YAML、结构编辑或 Go。

## 14.2 `0.3.0`：跨格式核心与协议闭合

目标：在 JSON 与 TOML 两个事实基础上，冻结第一套真正跨格式的 v1 contract candidate。

落实状态：已完成（2026-08-04）。规范见 `docs/rfcs/0002-cross-format-protocol-v1.md`，实现见 `consema-protocol`，语言无关证据见 `conformance/vectors/protocol-v1.json`。

交付：

* Semantic Model v1 contract set；
* Profile、Capability 和 registry schema；
* Diagnostic protocol；
* QueryDefinition/Result protocol 完整编码；
* ProjectionRequest/Result/Report/Provenance protocol；
* ChangeSet protocol；
* ResourceLimit、Cancellation 和 Completion protocol；
* 所有协议的严格 JSON representation 与 PVCE representation；
* 未知字段、未知 contract、非规范编码的统一拒绝规则；
* conformance suite 分层、版本和 runner contract；
* public error code registry。

硬门禁：

* 所有跨语言公共行为都有 wire schema 或明确声明为 process-local；
* NodeRef、cursor、snapshot handle 的可序列化范围明确；
* Rust 私有枚举名、错误字符串和 AST 不进入协议；
* 旧 PVCE/1 字节保持不变；若设计错误，发布 PVCE/2 而不是改写 PVCE/1。

完成证据：32/32 protocol language-neutral cases、全部 15 个稳定 payload 的 JSON/PVCE envelope 往返、55 个公共 error code、78 项 workspace 全 target 测试、rustfmt、Clippy/rustdoc `-D warnings`、RustSec audit 与 cargo-deny 门禁全部通过。schema-only payload、未知 code、process-local handle、非 canonical transport、资源越界与成功 Null/absent 歧义均有反例回归。

本版本不加入 raw multi-encoding Source、YAML、结构编辑、materialization 或 Go。

## 14.3 `0.4.0`：生产 Source/Document 平台

目标：把 UTF-8 文本原型提升为可支持 XML、Properties 与 binary plist 的原始内容平台。

落实状态：已完成（2026-08-04）。规范见 `docs/rfcs/0003-source-syntax-query-and-patch-v1.md`，实现覆盖 raw SourceSnapshot、五种 encoding、decoded location、binary regions、JSON/TOML lossless Syntax Query、cursor terminal、SourcePatch 与 semantic-model v2；语言无关证据见 `source-v1.json`、`syntax-query-v1.json` 与 `protocol-v2.json`。

交付：

* raw-byte SourceSnapshot；
* content digest 与 snapshot identity contract；
* encoding declaration/detection/override facts；
* byte Span 与 decoded location 的严格分离；
* UTF-8、UTF-16、Latin-1 所需基础设施；
* binary Document structural region model；
* exact source coverage verifier；
* per-format Lossless Syntax Query framework；
* process-local cursor/stream completion contract；
* snapshot-bound SourcePatch@1；
* encoding、digest 和 malicious input conformance。

硬门禁：

* 同一原始字节在 Rust 中产生稳定 identity；
* BOM/声明/调用方 override 冲突绝不猜测；
* 未修改文本或二进制 Document 均 byte-exact；
* offset conversion 不溢出；
* decoded char index 不替代原始 byte Span；
* binary format 不被迫伪造 trivia/token。

完成证据：28/28 source、19/19 syntax-query、11/11 protocol v2 language-neutral cases；141 项 workspace 全 target/all features tests；SourceSnapshot/SourcePatch canonical JSON/PVCE v2 往返；adversarial decoding/offset/count/allocation corpus；rustfmt、strict Clippy、rustdoc、RustSec、cargo-deny 与官方 TOML suite 全部通过。annotated tag `v0.4.0` 精确指向审计提交 `874c7cc`。

## 14.4 `0.5.0`：生成、转换与结构编辑闭环

目标：从“读、查、投影、替换标量”提升为可执行真实迁移的操作平台。

落实状态：已完成（2026-08-04）。规范见 `docs/rfcs/0004-materialization-conversion-and-structural-edit-v1.md`，实现覆盖公共 materialization contract、JSON/TOML generator、两向 audited conversion、format operation registry、结构事务、dry-run、UntouchedByteProof、SourcePatch derivation 与 semantic-model v3；语言无关证据见 `conformance/vectors/operations-v1.json`。

交付：

* MaterializationRequest/Result；
* representability、style、encoding、newline policies；
* ProjectionReport + MaterializationReport 组合；
* audited cross-format conversion report；
* format-operation registry；
* 插入、删除、rename、sequence edit 的共同事务机制；
* 格式专属 structural operations；
* multi-operation conflict algebra；
* reversible source replacement metadata；
* dry-run plan schema；
* SourcePatch application preconditions。

硬门禁：

* 未授权损失为零；
* conversion 不存在默认 duplicate/key/tag 映射猜测；
* 多编辑失败不产生部分新 Document；
* untouched source regions 有机器可验证证明；
* SourcePatch 基础摘要不匹配时必须失败；
* Materialization 与 Formatter 的边界写入规范。

完成证据：35/35 operations v1、合计 163/163 language-neutral cases；Rust 1.97 与声明的 MSRV Rust 1.85 均通过 189 项 workspace 全 target/all features tests 和 strict Clippy；rustfmt、doctest、rustdoc `-D warnings`、10 项 adversarial/property tests、RustSec、cargo-deny 与官方 TOML 205 valid/474 invalid suite 全部通过。semantic-model v1 的 16/55、v2 的 18/62 保持冻结，v3 发布 25 条 contract registry 记录与 90 个 error code；失败 materialization/transaction 不产生 partial Document，成功 edit 的 patch 重放与 untouched proof 均完成验证。

## 14.5 `0.6.0`：JSON family 生产完成

目标：完成 `json.strict@1`、`jsonc.bounded@1` 与 `json5.standard@1` 的完整生产矩阵。

交付：

* JSON5 parser、native view、syntax query、projection、materialization、edit；
* JSON/JSONC 完整 syntax query；
* member insert/remove/rename/reorder policy；
* array structural edit；
* JSON family canonical generation；
* dialect conversion report；
* 大规模 JSON/JSONC/JSON5 corpus、fuzz 和 benchmark；
* 严格数字、Unicode、escape、NaN/Infinity 的跨 Profile 规则。

硬门禁：JSON family 的第 8 节 capability matrix 在 Rust 中全部为绿色。

## 14.6 `0.7.0`：YAML family 与 PortableGraph

目标：用最复杂的主流数据配置格式验证“共同机制统一、真实差异显式”。

交付：

* PortableGraph@1、strict graph equality 与 PGCE/1；
* `core.portable-graph-query@1`；
* `yaml.1.2-core@1` 与 `yaml.1.1-compat@1`；
* stream/multi-document Document；
* tag、anchor、alias、sharing、cycle native semantics；
* block/flow/scalar style 与 trivia；
* YAML native/syntax query；
* graph/value projection policies；
* YAML materialization；
* mapping/sequence/anchor-safe edit；
* alias bomb、depth、cycle 和 custom tag 安全限制；
* YAML official/community test suite 与 Kubernetes/CI 配置 corpus。

硬门禁：

* PortableValue 不因 YAML 被污染；
* alias 和 cycle 不被隐式展开；
* custom tag 不实例化语言对象；
* 1.1 与 1.2 标量差异由 Profile 决定；
* 图 identity、query order、PGCE 在所有执行中确定；
* 资源耗尽不能返回截断图或伪成功 Document。

## 14.7 `0.8.0`：INI family 与 Properties family

目标：覆盖跨平台遗留配置与 JVM Properties，并证明共享 lexer 基础设施不等于共享语义。

交付：

* `ini.portable@1`、`ini.windows@1`、`ini.python-configparser@1`；
* `java-properties.reader@1`、`java-properties.latin1@1`；
* physical/logical line、section、entry/property native identity；
* duplicate、case、separator、comment、continuation 规则；
* native/syntax query；
* EntryMapping 优先的 exact projection；
* materialization 与常用结构编辑；
* 与 Python ConfigParser、.NET/Windows/Qt INI 和 JDK Properties 的 differential suite。

硬门禁：

* Profile 选择不依赖扩展名猜测；
* duplicate 不被 map 覆盖；
* interpolation、environment 和 defaults chain 不隐式执行；
* Latin-1、Unicode escape 和 Reader semantics 可重放；
* 三个 INI Profile 的差异均有反例向量。

## 14.8 `0.9.0`：XML

目标：完整支持 tree、namespace、mixed content 和多编码配置文档，不把 XML 压平为 Object。

交付：

* `xml.1.0-safe@1`；
* prolog、element、attribute、namespace、text、CDATA、comment、PI；
* mixed content 和 source order；
* native/syntax query；
* XML-specific projection targets 与 explicit mapping policies；
* XML materialization；
* element/attribute/text structural edit；
* external entity/network deny-by-default；
* entity expansion limits；
* W3C XML test suite、encoding corpus 和 adversarial corpus。

硬门禁：

* expanded name、prefix 和 namespace binding 职责分离；
* attribute 与 child element 不混为同一关联；
* mixed content 顺序完整；
* 外部实体不产生 I/O；
* XML-to-Object 不存在默认映射；
* UTF-8/UTF-16 未修改字节精确往返。

## 14.9 `0.10.0`：Property List

目标：覆盖 Apple 平台常用配置，并验证 text/binary 两种 representation 共享值语义但不共享虚假语法树。

交付：

* `plist.xml@1` 与 `plist.binary@1`；
* plist native value model；
* data/date/integer/real/boolean 精确语义；
* binary object/offset/reference table；
* XML/binary exact round trip；
* native/syntax 或 binary-structure query；
* projection/materialization；
* dictionary/array/value edit；
* 与 Apple `plutil`/Foundation 行为的 macOS differential suite。

硬门禁：

* binary plist 不伪造文本 trivia；
* XML 与 binary 转换报告 representation change；
* date、data 和 integer 不通过字符串降维；
* object reference、offset 和 size 计算有溢出与资源限制保护。

## 14.10 `0.11.0`：HCL family

目标：覆盖基础设施配置，同时严格守住 Document 与 Evaluation 的边界。

交付：

* `hcl.native@1`、`hcl.tfvars@1`；
* body、block、label、attribute、expression、template native view；
* native/syntax query；
* literal-complete projection；
* unevaluated expression ExtendedValue contract；
* HCL materialization；
* attribute/block/literal structural edit；
* 与 HashiCorp HCL parser 的 differential suite；
* expression depth、template 和 heredoc adversarial corpus。

硬门禁：

* parse/project/query/edit 不执行 variable、function 或 template；
* application schema 不进入通用 HCL semantic model；
* Terraform 专属解释不冒充 HCL 格式事实；
* 非 literal expression 的投影结果必须显式失败或使用已授权 ExtendedValue。

## 14.11 `0.12.0`：Rust 产品集成

目标：把全部 Rust libraries 组合成一个统一、可使用、可维护的产品。

交付：

* 稳定候选 Rust crate topology；
* facade 与 feature policy；
* 全格式 registry 和 auto-detection 的安全边界；
* 正式 `consema` CLI；
* inspect/query/project/materialize/convert/plan/apply/explain；
* machine-readable CLI protocol；
* per-file atomic write 与 batch manifest；
* secret redaction；
* API examples、cookbook、migration guide；
* 全格式真实工作流示例。

硬门禁：

* 用户不需要直接依赖 backend crate；
* CLI 与 SDK 使用同一语义入口；
* 格式 auto-detection 只返回置信事实或歧义，不静默猜测；
* 默认操作不写文件；
* 所有 public API 有文档和稳定错误分类。

## 14.12 `0.13.0`：Rust 生产加固与 Feature-Complete Gate

目标：在 Go 开始之前，证明 Rust 已经完整跑通 `1.0.0` 的所有功能和生产门槛。

本版本不增加新格式或大型功能，只完成：

* full conformance；
* fuzz、property、differential、mutation 和 malicious corpus；
* 性能与内存预算；
* API/semver review；
* MSRV policy；
* dependency/license/security audit；
* Windows、Linux、macOS CI；
* 文档、示例和真实项目 pilot；
* release process、SBOM、签名和恢复演练。

只有第 15 节 Rust Feature-Complete Gate 全部通过，才允许开始 `0.14.0` 的 Go 实现。

---

# 15. Rust Feature-Complete Gate

`0.13.0` 只有同时满足以下条件，才被认定为“Rust 全跑通”。

## 15.1 功能门禁

* 八个 mandatory 格式家族、全部 mandatory Profile 完成；
* 第 8 节 capability matrix 全部通过；
* PortableValue/PVCE 与 PortableGraph/PGCE 完成；
* native query、syntax query、projection、materialization、provenance 完成；
* scalar 与 mandatory structural edits 完成；
* ChangeSet、SourcePatch、dry-run 和 batch manifest 完成；
* CLI 全部正式命令完成；
* 无 mandatory capability 标记为 experimental、stub 或 partial。

## 15.2 规范门禁

* 每个公共行为有权威规范章节；
* 每个 contract ID 已登记且不可变；
* 所有 public object 的 lifecycle、identity、completion 和 failure 已定义；
* 没有依赖 Rust 类型名才能解释的语言无关行为；
* 所有 provisional abstraction 已验证、修订或删除；
* Go API mapping RFC 已通过，但 Go 实现尚未开始；
* 所有已知规范歧义有 resolution 或明确的阻断状态。

## 15.3 质量门禁

* 所有 unit/integration/doc/conformance tests 通过；
* 所有支持格式的上游/官方测试套件通过，任何有意差异都有 Profile 说明和反例；
* accepted Complete Document 全部 byte-exact round-trip；
* 所有 edit 的 untouched regions byte-exact；
* 所有未授权 lossy projection/materialization 被拒绝；
* 每个 parser、decoder、query、projection、materialization 和 edit target 完成持续 fuzz；
* 每个格式发布前至少累计 72 CPU-hours release-candidate fuzz，零未解释 crash、panic、hang 或 limit bypass；
* 所有 fuzz regression 永久加入 corpus；
* 高风险 protocol/varint/offset/graph/alias 逻辑有 property tests 和 mutation review；
* 没有未分类 P0/P1 缺陷，P2 必须有明确发布判断。

72 CPU-hours 是发布候选最低证据，不是“超过时间即证明安全”。任何新 crash 都会清零该 target 的 release-candidate clean run。

## 15.4 安全门禁

* Rust workspace 保持 `unsafe_code = "forbid"`；
* 不因 parse/query/project/materialize 触发网络、文件、环境或程序执行；
* XML external entity、YAML tag constructor、HCL evaluation 默认关闭且不可被错误路径绕过；
* 所有输入、递归、节点、输出、诊断、匹配和编辑均可限制；
* resource limit 不产生截断假成功；
* 依赖不存在未接受的 critical/high 漏洞；
* dependency license、来源和维护状态完成审计；
* threat model、SECURITY.md、披露与修复流程完成；
* CLI secret redaction 和临时文件权限完成跨平台验证。

## 15.5 性能门禁

* parser/decoder 在正常输入上具有经验证的线性或明确复杂度；
* adversarial input 不出现未受限的超线性退化；
* 每个格式都有 parse、render、query、projection、materialization、edit benchmark；
* 建立固定硬件、固定 corpus 和版本化 baseline；
* p50/p95 时间与峰值内存有正式预算；
* 任何超过已冻结预算或相对上一基线 10% 的回退必须有批准记录；
* 大文档、深嵌套、大量重复项和大量小节点均有独立场景；
* lazy/streaming capability 的完成、取消和 backpressure 经过验证。

绝对性能预算必须在 `0.6.0` 前通过真实 benchmark 冻结，不能等到 `1.0.0-rc` 才临时定义。路线图不在没有基准数据时伪造 MB/s 数字。

## 15.6 API 与产品门禁

* Rust public API 完成独立审查；
* backend AST 和第三方错误类型不泄漏；
* facade、低层 crate 与 feature 关系清楚；
* MSRV 在 manifest 中声明并在 CI 真正验证；
* 全部 public API 有 rustdoc；
* 每个主要工作流有可复制示例；
* CLI exit code、stdout/stderr 和 machine schema 冻结为 v1 candidate；
* patch/apply 具备中断、冲突、权限和磁盘错误测试；
* release artifact 可从干净环境重建；
* changelog、migration、compatibility 和 support policy 完成。

## 15.7 Feature-Complete Manifest

门禁通过后发布机器可读 manifest，至少记录：

```text
product version
spec revision
contract registry digest
capability set
conformance suite digest
corpus/test-suite revisions
benchmark baseline revision
Rust compiler/MSRV
dependency lock digest
supported targets
known accepted limitations
```

Go 以该 manifest 为起点，不以某个本地 Rust 工作树的偶然状态为起点。

---

# 16. Go 阶段详细计划

## 16.1 `0.14.0`：Go core、PVCE、PGCE 与协议

目标：先证明最底层值、图、编码和协议可以独立实现。

交付：

* Go module 与 package topology；
* PortableValue、strict equality/hash；
* PVCE/1 canonical encode/decode；
* PortableGraph、graph equality 与 PGCE/1；
* Capability、Profile、Diagnostic；
* QueryDefinition validation/binding；
* 全部 language-neutral protocol codecs；
* Go conformance runner；
* Go fuzz targets。

硬门禁：

* Rust 与 Go 的 PVCE/PGCE bytes 完全一致；
* shared vectors 100% 通过；
* Go 不导入或调用 Rust；
* Go error text 不参与规范比较；
* protocol unknown-field/canonicality 规则一致。

## 16.2 `0.15.0`：Go Document、JSON family 与 TOML

目标：建立 Go 的不可变 Document 平台并覆盖已最早成熟的四个 Profile 家族入口。

交付：

* raw SourceSnapshot、encoding、Span、NodeRef；
* JSON/JSONC/JSON5；
* TOML；
* native/syntax query；
* projection/materialization/provenance；
* scalar/structural edit、ChangeSet、SourcePatch；
* cancellation 使用 `context.Context` 的 Go 适配；
* cross-language normalized-result differential harness。

硬门禁：对应 Rust capability set 的共享向量 100% 一致。

## 16.3 `0.16.0`：Go YAML、INI 与 Properties

目标：完成 graph 与 line-oriented 两类差异显著的格式。

交付：

* YAML 1.2/1.1 compatibility；
* anchor/alias/tag/graph；
* INI 三 Profile；
* Java Properties 两 Profile；
* 全操作能力与 security limits；
* Rust/Go cross-run fixtures。

硬门禁：

* Go graph identity 和 query ordering 满足同一 contract；
* alias bomb、cycle、INI dialect 和 Properties encoding 的负向向量一致；
* Go map 的随机迭代顺序不得影响任何公共结果。

## 16.4 `0.17.0`：Go XML 与 plist

目标：完成多编码 tree 和 text/binary 双表示格式。

交付：

* XML 1.0 safe；
* namespace/mixed content；
* plist XML/binary；
* 全 query/projection/materialization/edit；
* XML security 与 binary offset hardening；
* macOS Foundation differential run。

硬门禁：Rust 与 Go 在 native normalized facts、报告、诊断 code/order 和 edit bytes 上一致。

## 16.5 `0.18.0`：Go HCL 与全操作 parity

目标：完成最后一个格式家族，并补齐全部 common operations。

交付：

* HCL native/tfvars；
* expression/template native view；
* 全格式 Materialization；
* 全格式 mandatory structural Edit；
* SourcePatch 与 batch-plan protocol；
* Go SDK examples 和完整文档。

硬门禁：Go mandatory capability set 与 Rust Feature-Complete Manifest 对齐，不存在“Rust only” mandatory 行为。

## 16.6 `0.19.0`：双语言一致性与产品 Beta

目标：停止新增范围，用真实项目同时审计 Rust 与 Go。

交付：

* shared conformance runner orchestration；
* Rust/Go bidirectional differential runs；
* cross-language protocol exchange；
* full corpus、fuzz、benchmark 和 security matrix；
* SDK usability review；
* CLI beta；
* real-repository migration pilots；
* release/upgrade/rollback drill；
* `1.0.0-rc.1` 候选清单。

硬门禁：第 22 节 `1.0.0` 门槛除 RC soak 外全部通过。

---

# 17. 语言无关 Conformance 架构

## 17.1 权威组成

```text
normative prose
+ contract registry
+ machine-readable vectors
+ raw fixtures
+ independent Rust and Go runners
```

Rust 测试通过不能代替 Go 测试，Go 测试通过也不能证明规范没有歧义。权威来自规范含义与两实现共同验证。

## 17.2 Suite 分层

```text
core/value       PortableValue equality/hash/PVCE
core/graph       PortableGraph equality/PGCE
core/protocol    schema/canonicality/versioning
document         source/encoding/span/identity/formation
format/<profile> syntax/native/recovery/diagnostic
query            validation/binding/order/cardinality/cancel
projection       fidelity/report/provenance/policy
materialization representability/style/report/provenance
edit             transaction/conflict/minimality/changeset
patch            digest/precondition/application
security         limits/adversarial/no-side-effect
cross-format     projection + materialization composition
cross-language   Rust/Go exact observable parity
```

## 17.3 Fixture 形式

* 原始输入以独立 fixture file 保存，不通过宿主字符串转义改变字节；
* 二进制或非法编码输入使用 raw file，并在 manifest 中记录 digest；
* expected portable values 同时提供 readable strict JSON form 与 canonical PVCE hex；
* graph 提供 readable graph form 与 PGCE hex；
* Span 使用原始 byte offset；
* diagnostic 只比较稳定字段，不比较本地化 message；
* native semantics 使用每个格式自己的 normalized protocol；
* edit 同时比较新 bytes、ChangeSet、report 和 untouched ranges；
* 每个 case 有 stable ID、capability、profile、limits、input、expected 和 provenance。

## 17.4 测试来源

每个格式同时消费：

1. 官方或事实标准测试套件；
2. Consema 自身规范向量；
3. 公开真实项目 corpus；
4. 生成式/property corpus；
5. fuzz regression corpus；
6. 安全恶意 corpus；
7. Rust/Go differential corpus。

第三方 suite 的成功不能替代 Consema 特有的 lossless、query、projection、provenance 和 edit 测试。

## 17.5 Conformance 声明

实现只能声明：

```text
Conformant with <exact capability set>
Verified against <suite version and digest>
For <profiles and platform targets>
```

禁止模糊声明“fully Consema compatible”而不列 capability set。

---

# 18. 测试与质量体系

## 18.1 测试金字塔

每个 capability 至少需要：

* unit tests：局部不变量和边界；
* protocol tests：编码、严格解码、版本和 canonicality；
* property tests：round-trip、equality、ordering、span coverage；
* conformance tests：语言无关公共行为；
* corpus tests：真实文件；
* differential tests：与成熟实现及 Rust/Go 互比；
* fuzz tests：任意输入、mutation 和 stateful operations；
* adversarial tests：深度、放大、溢出、病态重复、编码攻击；
* benchmark tests：时间、内存和输出放大；
* end-to-end tests：CLI plan/apply、冲突和中断恢复。

## 18.2 必须验证的不变量

1. 未修改 Document byte-exact；
2. source coverage 无 gap/overlap；
3. NodeRef 不跨 snapshot 误用；
4. native duplicate/order/identity 不丢失；
5. query 定义错误在首个 Match 前失败；
6. query 结果顺序不受 map、goroutine 或线程调度影响；
7. projection/materialization 无静默损失；
8. provenance 能区分重复与共享来源；
9. edit 失败原子；
10. untouched bytes 不变；
11. SourcePatch precondition 不匹配时失败；
12. resource limit 不产生假成功；
13. cancellation 不返回 completed result；
14. parser/backend 类型不进入公共协议；
15. Rust 与 Go 规范化结果一致。

## 18.3 Coverage 不替代语义证明

项目必须生成 line/branch coverage 报告，但不把单一百分比当作质量证明。发布门禁优先关注：

* mandatory contract 是否全部有向量；
* 错误和资源路径是否实际执行；
* parser 状态机和 transaction 冲突是否被 mutation testing 挑战；
* 已知缺陷是否变成永久 regression；
* 真实 corpus 是否覆盖 Profile 差异。

协议、varint、offset、graph、alias、encoding 和 atomic edit 等高风险模块必须达到接近穷举的边界覆盖；普通 glue code 不以刷覆盖率为目标。

## 18.4 缺陷等级

```text
P0  数据破坏、静默损失、RCE/外部访问、错误写文件、跨快照误编辑
P1  panic/crash/hang、错误完成状态、明显语义不一致、limit bypass
P2  有安全替代路径的功能缺陷、非核心性能回退、诊断位置错误
P3  文档、易用性、非稳定 message 或低风险边角问题
```

`1.0.0` 不允许未解决 P0/P1。P2 必须逐项公开评审，不能笼统归入 known issues。

---

# 19. 资源、安全与供应链

## 19.1 统一资源模型

所有格式和操作使用共同资源类别，但允许 Profile 添加专属限制：

```text
input bytes
decoded code points
tokens / syntax regions
nesting depth
document nodes / associations
diagnostics
query steps / matches / buffered results
projection nodes / report events / provenance entries
materialization nodes / output bytes
edit operations / replacement bytes
graph nodes / edges / cycle traversal
YAML aliases / expansion ratio
XML entities / expansion ratio
HCL expression/template depth
binary plist objects / offsets
```

每个 limit 必须定义：计数单位、检查时机、失败 code、是否可恢复、完成状态和跨语言相同行为。

## 19.2 无副作用安全边界

核心操作默认满足：

```text
no filesystem access
no environment read
no network
no external entity fetch
no custom object construction
no expression evaluation
no command execution
no plugin loading
```

CLI 文件 I/O 是明确的 application operation，并受路径、权限、symlink、临时文件和 precondition policy 约束。

## 19.3 依赖政策

允许使用成熟 backend，但必须：

* 不泄漏其 AST/API；
* 验证其能提供所需 source facts；
* 对缺失能力建立自有层，而不是降低标准；
* 固定并审计版本；
* 跟踪安全公告和维护状态；
* 可以在不破坏公共契约时替换；
* 不允许 backend 默认执行 tag/entity/expression；
* 任何差异由 Consema conformance 决定。

“使用成熟依赖”降低实现风险，但不转移 Consema 对正确性和安全的责任。

## 19.4 发布供应链

稳定发布至少包含：

* locked dependency graph；
* Cargo 与 Go dependency audit；
* license inventory；
* source archive；
* SBOM；
* artifact checksum；
* signed tag 与 release artifact；
* build provenance；
* 干净环境重建步骤；
* 安全披露联系方式和支持周期。

---

# 20. 性能与可扩展性

## 20.1 性能目标

Consema 的首要目标是正确、保真和可审计，不追求在所有场景击败只生成普通 map 的 parser。但生产产品必须：

* 对常规输入拥有可预测吞吐；
* 对大输入有明确内存预算；
* 对局部查询和编辑可利用结构索引；
* 不出现可被输入触发的未受限超线性行为；
* 支持取消和资源限制；
* 能说明保真能力带来的额外成本。

## 20.2 Benchmark 维度

每个格式至少测试：

* small/medium/large real documents；
* deeply nested documents；
* wide containers；
* comment/trivia-heavy documents；
* duplicate-heavy documents；
* recovery-heavy documents；
* parse + exact render；
* native and syntax query；
* projection/materialization；
* single and batch edits；
* peak resident memory；
* cold and warm cache。

对比对象使用成熟 format-specific parser/editor，但结果必须注明对方是否执行等价的 lossless/provenance 工作，禁止拿不同工作量做营销式比较。

## 20.3 回退政策

* benchmark corpus 和 runner versioned；
* 主分支报告趋势，release 分支冻结 baseline；
* 超过 10% 的 p50/p95 或 peak-memory 回退需要分析和批准；
* 安全或正确性修复可以接受性能回退，但必须公开；
* 不通过关闭诊断、lossless coverage 或 limits 换取 benchmark 成绩。

---

# 21. API、兼容性与支持政策

## 21.1 Rust API

* completed public objects 默认不可变且 `Send + Sync`；
* builders 用于复杂 request；
* public structs 优先私有字段或 `non_exhaustive` 设计；
* public enum 的扩展策略在 `1.0.0` 前确定；
* backend types 和 parser lifetimes 不泄漏；
* feature 开关不得改变已有 API 的含义；
* MSRV 提升不进入 patch release；
* `cargo-semver-checks` 或等价 API diff 进入 CI。

## 21.2 Go API

* module path 在 `0.14.0` 前冻结并拥有可长期使用的发布位置；
* completed objects 使用未导出字段和只读方法维护逻辑不可变；
* `context.Context` 只用于取消/deadline，不隐藏业务参数；
* error code/type 与本地 message 分离；
* map 不用于表达有序公共结果；
* iterator/stream 有显式 Close/Completion/Error 语义；
* Go 最低版本遵循公开支持政策并在 CI 验证；
* `go vet`、static analysis、race detector 和 fuzz 进入发布门禁。

Go 官方把 `v1` 定义为稳定承诺，并建议将破坏性 major update 作为最后手段，相关发布流程遵循 [Go module release workflow](https://go.dev/doc/modules/release-workflow)。

## 21.3 稳定承诺

从 `1.0.0` 开始：

* patch：bug/security fix，不改变公共 API 或已定义行为；
* minor：向后兼容的新能力、新 Profile 或新 contract；
* major：不可避免的破坏性公共变更；
* 已发布 contract `@N` 永远不被重解释；
* diagnostic message 可改进，stable code/category/fields 不随意变化；
* output order 属于兼容性；
* 默认 loss policy 属于兼容性；
* format acceptance/recovery 边界属于 Profile 兼容性。

## 21.4 支持周期

`1.0.0` 发布前必须公开：

* Rust MSRV window；
* Go version window；
* supported OS/architectures；
* security fix policy；
* previous minor branch support period；
* deprecation notice period；
* contract/profile retirement process。

具体工具链版本在 Rust Feature-Complete 和 Go RC 时按当时稳定生态冻结，不在多年路线图中预先写死未来版本号。

---

# 22. `1.0.0` 最终发布门槛

## 22.1 标准与格式

* 八个格式家族全部 GA；
* 所有 mandatory Profile 规范冻结；
* 所有 mandatory capability 已注册；
* PortableValue/PVCE、PortableGraph/PGCE 稳定；
* 所有 protocol schema 稳定；
* 不存在 provisional public abstraction；
* 格式差异均由 native model/Profile/policy 表达。

## 22.2 双语言实现

* Rust 与 Go capability set 一致；
* shared conformance 100% 通过；
* PVCE/PGCE byte-exact；
* protocol cross-encode/decode 100% 通过；
* normalized parse/query/projection/materialization/edit results 一致；
* 两个实现均独立，不通过 FFI 或私有中间结果作弊；
* Rust/Go public API 都完成稳定性审查。

## 22.3 正确性

* accepted complete inputs byte-exact unmodified round-trip；
* recovery corpus completion state 稳定；
* duplicate、order、identity、graph sharing 和 mixed content 不丢失；
* projection/materialization 静默损失为零；
* provenance 可追踪全部转换结果；
* query 定义错误不会晚于首个 Match；
* edit/patch wrong-snapshot 和 stale-content 必须拒绝；
* transaction 失败原子；
* untouched bytes exact；
* resource limit/cancellation 不产生伪成功。

## 22.4 安全与质量

* Rust 和 Go 全测试矩阵通过；
* release-candidate fuzz clean-run 达标；
* 无未解决 P0/P1；
* 无未接受 critical/high dependency vulnerability；
* XML/YAML/HCL/binary plist 专项 threat tests 通过；
* Windows/Linux/macOS 全部正式 target 通过；
* race、overflow、deep recursion、OOM amplification 和 path handling 测试通过；
* security audit findings 全部关闭或公开接受。

## 22.5 性能

* 所有格式达到冻结的时间和内存预算；
* 无未解释 >10% release baseline 回退；
* adversarial complexity 有明确上界或 limit；
* CLI 批量计划和应用在真实规模仓库通过；
* benchmark 报告可重现并说明比较工作量。

## 22.6 产品

* Rust SDK、Go SDK、Rust CLI 正式发布；
* CLI 默认 dry-run，写操作有 precondition；
* machine-readable output schema 稳定；
* batch manifest、冲突、中断和恢复完成；
* 文档、API reference、cookbook、迁移指南、故障排查完成；
* 每个格式至少有 inspect/query/project/edit 示例；
* 每个可转换组合有 loss policy 示例；
* 发布物、SBOM、签名、checksum 和 build provenance 完成。

## 22.7 真实有效性

* 每个格式 family 有公开或可审计的真实 corpus；
* 至少完成三类真实批量迁移：版本/镜像更新、结构插入删除、跨格式转换；
* 迁移中未经授权的信息损失为零；
* 用户未选择的文件和 byte ranges 不改变；
* 至少一次 stale file、部分权限失败、进程中断和磁盘失败演练；
* Rust 与 Go 分别完成至少一个端到端 SDK pilot；
* 所有 pilot 缺陷进入 regression suite。

只有以上全部通过，才能发布 `1.0.0`。RC 期间发现任何 P0/P1 或 contract ambiguity，必须发布新的 RC 并重新完成相应 clean-run，不能以 release note 代替修复。

---

# 23. 真实项目验证方案

## 23.1 Corpus 分类

每个格式维护：

* minimal grammar corpus；
* official/upstream suite；
* public open-source configuration corpus；
* hand-edited trivia-heavy corpus；
* malformed/recovery corpus；
* malicious corpus；
* generated combinatorial corpus；
* historical regression corpus。

Corpus 必须记录来源、license、digest、Profile 和预期用途。不得把含 secret、个人信息或不明许可的客户文件直接提交公开仓库。

## 23.2 必做工作流

1. 在 JSONC/JSON5/TOML/YAML 中更新依赖或镜像版本，保持注释与 style；
2. 在 INI/Properties 中插入、删除、rename 配置项并保留重复与 logical line；
3. 在 XML 中修改 attribute/element/text，不破坏 namespace 与 mixed content；
4. 在 plist XML/binary 中修改 typed value 并保持 representation contract；
5. 在 HCL 中修改 literal attribute，不执行表达式；
6. JSON ↔ TOML、JSON ↔ YAML 等可表示组合的 audited conversion；
7. 对不可无损转换的 YAML graph/XML mixed content 产生明确拒绝和报告；
8. 多文件 dry-run、review、stale conflict 和 apply。

## 23.3 核心指标

```text
exact unmodified round-trip rate
untouched-byte preservation rate
silent-loss count
authorized-loss report completeness
false-success count
false-conflict / missed-conflict count
diagnostic stability
query result determinism
parse/query/edit latency p50/p95
peak memory/input byte
batch apply success/recovery rate
Rust/Go observable mismatch count
```

目标不是“样例看起来正确”，而是让所有重要承诺可量化、可重放、可回归。

---

# 24. `1.0.0` 明确非目标

即使 `1.0.0` 是完整生产级产品，以下仍不属于其核心范围：

* 文件发现和配置优先级合并引擎；
* 环境变量、CLI、注册表或远程 KV 作为核心 Document 格式；
* Schema validation 与 auto-fix 平台；
* 任意 expression evaluation；
* import/include/reference resolution；
* 通用语义 Diff/Patch；
* live query；
* incremental parsing；
* formatter 产品；
* 配置中心和热更新；
* secret manager；
* IDE/GUI；
* 稳定远程 plugin process protocol；
* Java/TypeScript/Python SDK；
* 企业治理平台本身。

Materialization 的 canonical style 不等于 formatter；SourcePatch 不等于通用 semantic patch；CLI 文件读写不等于配置来源合并系统；HCL Document 支持不等于 HCL/Terraform evaluation。

---

# 25. 参考实现架构

## 25.1 逻辑分层

```text
Core contracts
  ├─ PortableValue / PVCE
  ├─ PortableGraph / PGCE
  ├─ Diagnostic / Profile / Capability
  ├─ Query / Projection / Materialization protocols
  └─ Edit / ChangeSet / SourcePatch protocols

Source & Document platform
  ├─ raw snapshot / encoding / spans
  ├─ immutable document facts
  ├─ coverage / identity
  └─ limits / cancellation

Format families
  ├─ JSON
  ├─ TOML
  ├─ YAML
  ├─ INI
  ├─ Properties
  ├─ XML
  ├─ plist
  └─ HCL

Product
  ├─ facade / registry
  ├─ conformance runners
  └─ CLI
```

依赖只能向下，格式包之间不得互相依赖。跨格式转换通过 core Projection/Materialization contracts 组合，不让 JSON crate 直接调用 TOML crate。

## 25.2 Rust workspace 候选

具体 crate 名可在 RFC 中调整，逻辑职责至少包括：

```text
consema-core
consema-pvce
consema-graph
consema-protocol
consema-source
consema-document
consema-json
consema-toml
consema-yaml
consema-ini
consema-properties
consema-xml
consema-plist
consema-hcl
consema-conformance
consema-cli
consema              facade
```

不要求为每个小抽象创建 crate；要求是依赖方向、公共职责和发布 feature 清楚。内部共享 lexer/arena 可以存在，但不得让一个格式的 node enum 成为其他格式的公共模型。

## 25.3 Go module 候选

```text
core
pvce
graph
protocol
source
document
formats/json
formats/toml
formats/yaml
formats/ini
formats/properties
formats/xml
formats/plist
formats/hcl
conformance
```

Go package 不需要模仿 Rust crate 数量。module path 必须在正式编码前确认仓库和发布所有权，避免发布后迁移 import path。

## 25.4 Backend adapter 原则

每个格式实现可以选择：

* 自研 lossless parser；
* 在成熟 parser 上构建 source-preserving layer；
* 使用 lossless editor backend；
* 混合 lexer 与 semantic validator。

选择由原型和 capability spike 决定。进入正式实现前必须验证 backend 是否能满足：

* exact raw bytes；
* complete syntax coverage；
* native identity 和 duplicate；
* stable spans；
* recovery；
* minimal edit；
* resource limits；
* no hidden evaluation；
* Rust/Go 可独立达到相同行为。

若 backend 不能满足，不降低产品门槛；更换 backend、补齐自有层或暂停该里程碑。

---

# 26. 风险、止损与不可跳过的决策

## 26.1 格式规模风险

八个家族意味着长期维护八套原生语义，而不是八个 decoder。风险控制：

* 一次只推进一个主要新语义家族；
* 前一个阶段不通过门禁，不启动下一个；
* 公共抽象至少经两个格式验证；
* 每个格式必须有 owner、suite、corpus 和 security plan；
* 不能用 shared universal AST 降低表面代码量。

止损条件：某格式在两个 backend spike 后仍无法满足 exact source、recovery 或 safe edit，则暂停路线，先发布设计调查，不带着伪能力继续。

## 26.2 标准自证风险

规范、Rust 实现和自有测试都由同一项目产生，容易形成循环证明。控制：

* 使用官方/upstream suites；
* differential testing；
* Go 独立实现；
* 真实 public corpus；
* RFC rejected alternatives；
* 对异常差异保留最小反例。

## 26.3 Go 复制 Rust bug 风险

控制：

* Go 从规范和 vectors 实现，不参考 Rust 私有 AST；
* code review 禁止机械逐函数翻译作为语义依据；
* 先解码共同协议，再分别产生 native facts；
* cross-language mismatch 默认视为需要调查，不默认 Rust 正确。

## 26.4 生产承诺过早冻结风险

控制：

* Rust feature complete 前 API 仍可通过 minor 迁移；
* Go 实现是第二轮规范审计；
* `1.0.0-rc` 前不作稳定 API 承诺；
* contract ID 一旦发布仍保持不可变；
* 所有 freeze 有 manifest 和 digest。

## 26.5 性能与内存风险

Lossless structure、provenance 和 graph 必然增加成本。控制：

* 每阶段建立 benchmark，不在最后优化；
* 派生索引可按需构建但结果不变；
* 完成对象可以共享不可变存储；
* 大结果提供显式 cursor/stream capability；
* resource limits 优先于极端吞吐；
* 性能不足时优化实现，不删除语义事实。

## 26.6 安全风险

高风险点：YAML alias/tag、XML entity、HCL expression、encoding、binary plist offset、批量文件写入。

控制：

* deny-by-default；
* side-effect-free core；
* 每一高风险格式单独 threat model；
* 所有递归与放大有 limit；
* fuzz + adversarial corpus；
* stale digest 和 original bytes 双 precondition；
* CLI apply 与 core edit 分层。

## 26.7 范围扩张风险

在 `1.0.0` 前出现新的热门格式时，不自动加入。只有同时满足以下条件才允许调整 mandatory scope：

1. 通过正式 RFC；
2. 证明属于主流静态配置格式；
3. 说明对当前排期和双语言成本的影响；
4. 用户明确接受路线图变更；
5. 不降低任何既有家族门槛。

---

# 27. RFC 与产物清单

以下编号是规划编号，可在建立正式 RFC 仓库时映射，但主题不能遗漏。

| 规划 RFC | 主题 | 最晚完成版本 |
|---|---|---|
| R-01 | TOML native model 与 Profile | `0.2.0` |
| R-02 | Cross-format core contract closure | `0.3.0` |
| R-03 | Protocol schemas 与 registry | `0.3.0` |
| R-04 | Raw source、encoding 与 location | `0.4.0` |
| R-05 | Syntax Query framework | `0.4.0` |
| R-06 | SourcePatch | `0.4.0` |
| R-07 | Materialization 与 conversion report | `0.5.0` |
| R-08 | Structural edit operation registry | `0.5.0` |
| R-09 | JSON5 Profile | `0.6.0` |
| R-10 | PortableGraph 与 PGCE | `0.7.0` |
| R-11 | YAML Profiles 与安全 | `0.7.0` |
| R-12 | INI family Profiles | `0.8.0` |
| R-13 | Java Properties Profiles | `0.8.0` |
| R-14 | XML safe Profile | `0.9.0` |
| R-15 | plist XML/binary | `0.10.0` |
| R-16 | HCL unevaluated semantics | `0.11.0` |
| R-17 | CLI protocol 与 batch apply | `0.12.0` |
| R-18 | Rust stable API candidate | `0.13.0` |
| R-19 | Go API mapping | Go 开始前 |
| R-20 | 1.0 compatibility/support policy | `0.19.0` |

每个版本还必须维护：

```text
spec changes
contract registry changes
capability manifest
conformance vectors
fixture/corpus manifest
security notes
benchmark report
API migration guide
known limitations
release checklist
```

---

# 28. 五要素终审

## 28.1 哲学统一

通过条件：

* 八个格式都以不可变 Document 为真实状态；
* PortableValue 不吞并 graph、XML tree 或 HCL program；
* Projection、Materialization 和 Edit 都是显式操作；
* CLI 便利性不改变核心默认拒绝原则；
* Rust 与 Go 共享行为，不强制共享实现结构；
* 生产级范围没有把配置来源、evaluation 和治理平台塞入核心。

## 28.2 语义一致

通过条件：

```text
SourceSnapshot       原始内容事实
Document             单一不可变状态
Lossless Syntax      格式表示事实
Native Semantics     格式本义
PortableValue        共同树值
PortableGraph        共同图值
ExtendedValue        正式扩展值
Query                确定搜索意图
Projection           Document → portable representation
Materialization      portable representation → new Document
Provenance           结果来源
EditTransaction      快照绑定原子修改
ChangeSet            已提交快照变化
SourcePatch          快照绑定 byte replacements
Profile              合法语言契约
Capability           可验证行为承诺
Conformance          跨实现证据
```

每个概念只有一个核心职责，不随格式或语言改变含义。

## 28.3 逻辑自洽

通过条件：

* read/query/project 链闭合；
* materialize/convert 链闭合；
* edit/patch/apply 链闭合；
* Document 与 portable representation 之间没有隐藏同步；
* format-specific edit 不伪装成 universal edit；
* YAML graph、XML tree 和 HCL expression 都有合法归属；
* Rust 先行与 Go 反向审计没有权威循环。

## 28.4 真实有效

通过条件：

* 格式范围来自跨生态调查，而不是个人偏好；
* `.env`、注册表和远程 KV 被正确归为来源；
* 八个家族完成真实 corpus 和迁移工作流；
* 每个格式不仅能 parse，还能保真、查询、投影、生成和编辑；
* 用户可以用 CLI 安全 plan/apply；
* 性能、安全和供应链有可重放证据；
* 静默信息损失为零。

## 28.5 完整可靠

通过条件：

* 标准、Rust、Go、CLI 和 suite 同时完成；
* 所有 mandatory capability 100% 通过；
* P0/P1 为零；
* 两语言 observable mismatch 为零；
* 生产发布物可验证、可重建、可升级；
* failure、recovery、cancellation、limits 和 conflict 都有正式语义；
* 没有通过 experimental 标签隐藏未完成的 1.0 承诺。

---

# 29. 最终确认

Consema `1.0.0` 的最终定义是：

> **一套完整生产级配置内容处理产品：覆盖 JSON、YAML、TOML、INI、XML、Properties、Property List 与 HCL 八个主流格式家族；由 Rust 和 Go 两个独立实现共同证明；能够无损保存内容事实、表达格式原生语义、执行确定查询、进行显式且可审计的投影与生成、完成快照绑定的原子编辑，并以 Capability、协议、Conformance、安全、性能和稳定发布政策保证长期可靠使用。**

路线图的最高推进原则是：

> **不以版本号推进代替完成，不以格式数量代替真实支持，不以共同 map 代替语义统一，不以单一实现通过代替跨语言标准成立。**

Go 只在 Rust 全部门禁通过后开始；`1.0.0` 只在 Rust、Go、规范、CLI 和生产保障全部完成后发布。
