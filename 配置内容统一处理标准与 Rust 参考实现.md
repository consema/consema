# 配置内容统一处理标准与 Rust 参考实现

## 最终完整设计基线 v1

> **语言中立声明（2026-08-13）**：本文档是语义基线，内容语言无关；
> 五语言实现（Rust、Go、TypeScript、Python、Kotlin）同等地位（2026-08-11
> 决策）。Rust 实现仅是参考实现（首个实现），不构成 Rust 对规范的特权；
> 文中 Rust 示例为语义的具象化，契约事实以 RFC 与 conformance vectors 为准。

---

# 0. 文档地位与确认范围

本文冻结以下内容：

* 项目为什么存在，以及永久边界；
* 文档、语法、原生语义和公共值之间的关系；
* 跨格式、跨语言必须保持一致的公共语义；
* Query、Projection、Provenance、Edit、Diagnostic 的完整操作模型；
* Profile、Capability、Extension 和版本治理；
* Rust 参考实现的公共架构；
* `0.1.0` 的准确范围、实施顺序和发布门槛；
* 后续能力如何加入且不破坏既有契约。

本文不冻结：

* 尚未进入首版的具体 Schema 语言；
* Diff/Patch 的具体操作集；
* Live Query 的事件协议；
* PortableGraph 的具体节点模型；
* 第三方进程插件的最终线协议；
* GUI、CLI 和商业产品交互设计。

这些属于后续独立 RFC。它们已经拥有清晰接入边界，因此不构成基础架构缺口。

确认结论是：

> **v1 基础架构已经闭合，`0.1.0` 可以不再依赖新的架构决策直接进入实现。**

---

# 1. 本次终审修订

终审中对先前稿件做了以下关键修正。

## 1.1 Syntax Query 不再冒充已完成标准

v1 正式冻结：

```text
core.portable-value-query@1
json.native-semantic-query@1
```

无损语法 Query 的领域边界已经确定，但其完整运算符集合尚不阻塞 `0.1.0`，因此不把一个尚未定义完整的：

```text
json.lossless-syntax-query@1
```

冒充已发布标准。

首版标量编辑可以使用格式内部的 typed syntax API，不等于已经发布公共 Syntax Query Domain。

---

## 1.2 PVCE 规范完整性与实现支持分离

`PVCE/1` 是完整的 PortableValue v1 规范编码。

Rust `0.1.0` 应实现完整 PortableValue v1 和完整 PVCE/1，而不是只实现 JSON 能产生的类型后仍声称“支持 PVCE/1”。

JSON 投影只会自然产生其中的一个子集，但核心值库和 codec 必须完整。

---

## 1.3 Object 键位置与值路径分离

`Object` 的键是属性名，不是容器中的普通子值。

因此：

* `ValuePath` 只指向值；
* Object entry、Object key role 和 EntryMapping association 使用独立的 `AssociationLocation`；
* Query 匹配条目后，可以显式取得名称或 value；
* provenance 可以同时指向值位置和关联位置。

---

## 1.4 Query 角色进入正式类型代数

仅区分 Query Domain 不足以阻止：

```text
CommentMatch → ObjectEntryValue
```

等错误组合。

因此运算符必须明确输入角色、输出角色、基数和顺序效果，并在执行前完成组合验证。

---

## 1.5 Rust 并发要求不再冒充语言无关语义

`Send + Sync` 是 Rust 参考实现的发布目标，不是跨语言标准概念。

公共标准只要求：

* 完成对象不可变；
* 多个读取者观察到一致结果；
* 并发调度不改变公开顺序和结果。

---

## 1.6 开源和商业策略与规范正文分离

开源许可证、认证和商业化建议保留为非规范性附录，不影响技术符合性。

---

# 2. 项目定位

## 2.1 项目是什么

本项目是一套配置内容处理标准及其 Rust 参考实现。

它提供：

* 无损文档快照；
* 格式原生语义；
* 跨语言公共值；
* 查询协议；
* 投影协议；
* 来源映射；
* 原子编辑；
* 诊断协议；
* Profile 与 Capability；
* 规范编码；
* 语言无关符合性测试。

长期目标是：

> **建立一套跨格式、跨语言、跨实现都能共同理解、交换并验证的配置内容处理标准。**

Rust 是第一参考实现，不是标准含义的唯一权威。

---

## 2.2 项目解决的问题

当前配置生态通常沿以下维度割裂：

```text
语言 × 格式 × 解析库 × 数据模型 × 操作接口
```

常见问题包括：

* 相同数字在不同语言中精度不同；
* 重复键被静默覆盖；
* comment、空白和字面量表示丢失；
* parser AST 泄漏成公共 API；
* null、缺失、失败和恢复节点混为一谈；
* 查询结果顺序依赖 map 或线程调度；
* 跨格式转换发生信息损失却无正式报告；
* “支持无损”或“支持查询”没有可验证定义；
* 不同实现无法共享测试向量和协议对象。

本项目不靠建立一个虚假的万能节点来解决这些问题，而是：

> **统一真正共同的行为机制，同时把真实格式差异明确建模。**

---

## 2.3 项目不是什么

永久不属于核心职责：

* 文件发现和加载；
* 环境变量、CLI 和配置中心合并；
* 多来源优先级；
* 配置生命周期和热更新；
* 密钥系统；
* 依赖注入；
* 业务配置对象管理；
* 任意表达式执行；
* 自动部署；
* 配置治理平台本身。

核心面对的是：

```text
一份已经获得的内容快照
```

文件只是内容的一个载体。

---

# 3. 最高设计原则

## 3.1 文档、值和程序分离

```text
Document
≠ PortableValue
≠ Executable Program
```

* Document 保存原始内容事实；
* PortableValue 表达公共值；
* 表达式和 import 通过显式 evaluation 边界执行。

程序不能在 parse 或 project 中偷偷执行。

---

## 3.2 一个真实状态，多种观察层

`Document` 是内容的唯一状态。

其上可以派生：

* Lossless Syntax View；
* Native Semantic View；
* Diagnostics；
* Projection；
* Query Result。

这些观察层不得各自变成可修改状态并自动同步。

---

## 3.3 共同机制统一，真实差异显式

共享：

* 快照生命周期；
* 结果代数；
* Query 执行机制；
* Diagnostic 协议；
* Capability；
* 版本治理；
* 符合性测试。

不强制共享：

* 格式语法节点；
* trivia 归属；
* table、anchor、alias、tag 等原生结构；
* 格式专属编辑规则。

---

## 3.4 默认不猜测

下列行为一律要求显式契约：

* 重复键选 first 或 last；
* 非字符串键字符串化；
* 数字舍入或降精度；
* Bytes 转 Base64；
* String 识别为日期；
* 引用展开；
* 字段删除；
* Query 跨领域转换；
* formatter 执行；
* NodeRef 跨快照迁移；
* 宽松相等。

总原则：

> **没有被明确授权的转换，默认拒绝。**

---

## 3.5 完成产物必须完整

以下完成对象都不能处于“半成功”状态：

* Document；
* PortableValue；
* ExecutableQuery；
* CompleteProjection；
* committed edit transaction。

局部进展可以通过：

* diagnostics；
* partial analysis；
* stream events；
* ProjectionReport；

报告，但不能冒充完整产物。

---

# 4. 权威与版本治理

标准权威由三部分组成：

```text
语言无关规范
+
符合性测试
+
Rust 参考实现
```

职责：

* 规范定义含义；
* 测试验证行为；
* Rust 证明可实现性。

如果参考实现与规范冲突，不能用实现 bug 重写规范。

以下对象独立版本化：

* Semantic Model；
* Format Family；
* Profile；
* Capability；
* Query Domain；
* Query Operator；
* Projection Target；
* Projection Policy；
* Extension Type；
* Canonical Encoding；
* Protocol Schema；
* Conformance Suite。

版本采用不可变整数契约：

```text
namespace.contract@1
namespace.contract@2
```

任何可能改变以下行为的修改都必须发布新版本：

* 合法输入；
* 输出类型；
* 匹配数量；
* 匹配顺序；
* 相等；
* 编码；
* 损失；
* 失败分类；
* 默认行为。

新实现可以继续支持旧契约，但不得重新解释旧契约。

---

# 5. 总体数据流

```text
SourceSnapshot
    ↓ parse
Document
    ├── Lossless Syntax View
    ├── Native Semantic View
    ├── Document Diagnostics
    │
    ├── SemanticQuery
    │       ↓
    │   Ordered Query Matches
    │
    ├── ProjectionRequest
    │       ↓
    │   ProjectionResult
    │       ├── PortableValue / ExtendedValue
    │       ├── ProjectionReport
    │       └── ProvenanceMap
    │
    └── EditTransaction
            ↓
        New Document
        +
        ChangeSet
```

表达式系统：

```text
Document
+
EvaluationContext
→ EvaluationResult
```

属于独立能力。

---

# 6. SourceSnapshot 与 Document

## 6.1 SourceSnapshot

`SourceSnapshot`：

* 保存完整原始字节；
* 不可变；
* 编码由 Profile 解释；
* 可来自内存、网络、数据库、编辑器或文件；
* 不负责内容的加载来源和生命周期。

JSON/JSONC v1 只接受 UTF-8。

---

## 6.2 Document

`Document` 至少包含：

```text
SnapshotIdentity
SourceSnapshot
FormatFamilyId
ProfileId + ProfileVersion
LosslessStructuralIndex
FormationStatus
DocumentDiagnostics
```

属性：

* 不可变；
* 默认渲染即返回当前源字节；
* 所有 NodeRef 和 Span 绑定此快照；
* 不公开 parser 后端类型；
* 是文档内容的唯一真实状态。

---

## 6.3 形成状态

成功形成 Document：

```text
Complete
Recovered
```

无法形成 Document：

```text
FatalFormationFailure
```

必须分别判断：

* 是否形成快照；
* 是否包含恢复结构；
* 是否符合 Profile；
* 某个区域是否具备语义；
* 某项操作是否成功。

不存在含义混杂的：

```text
document.is_valid()
```

---

## 6.4 结构覆盖不变量

每个源字节必须归属于：

* token；
* trivia；
* error region；

之一。

恢复产生的 missing node 可以拥有零宽度 Span，但不得伪造不存在的源字符。

---

# 7. Span、NodeRef 与无损语法

## 7.1 Span

标准 Span：

```text
[start_byte, end_byte)
```

特性：

* 半开字节区间；
* 快照绑定；
* line、column、UTF-16 offset 是派生坐标；
* 零宽度 Span 用于插入点或缺失节点。

Span 表达位置，不表达身份。

---

## 7.2 NodeRef

`NodeRef` 表示：

> 特定 Document 快照中的精确结构身份。

它：

* 不能用于其他快照；
* 不会自动漂移；
* 不保证重新解析后稳定；
* 用于最终精确编辑；
* 可以指向 syntax node、token 或格式定义允许的其他结构实体。

---

## 7.3 无损语法层

格式间只共享语法基础设施：

* 有序 children；
* token storage；
* trivia storage；
* ranges；
* identity；
* traversal；
* recovery；
* rebuilding。

每种格式拥有自己的：

* node kinds；
* token kinds；
* grammar；
* typed syntax views；
* trivia association rules。

不存在通用的：

```text
Mapping / Sequence / Scalar CST
```

原则：

> **共享树的机制，不共享格式的语法。**

---

## 7.4 Trivia

Trivia 是拥有自身 Span 和顺序的真实语法内容。

包括：

* whitespace；
* newline；
* comments；
* Profile 定义的其他非语义字符。

底层只保存事实。

“某条注释属于哪个 member”是格式专属高层解释和编辑政策，不是底层存储猜测。

---

# 8. 格式原生语义

Native Semantic View 表达某格式和 Profile 自身承认的完整意义。

JSON 原生语义至少包括：

* 有序 object members；
* 重复 member names；
* arrays；
* null；
* boolean；
* integer-form number；
* decimal-form number；
* decoded string。

Native Semantic View：

* 从 Document 派生；
* 与快照绑定；
* 可惰性计算和缓存；
* 缓存不可被观察；
* 不拥有独立可变状态。

语义可用性属于具体区域和操作：

```text
Available(value)
Unavailable(reason)
```

不存在整份文档统一的“语义有效”布尔值。

---

# 9. Profile

Profile 是：

> **不可变、命名、版本化的格式语言契约。**

定义：

* source encoding；
* lexical rules；
* grammar；
* native interpretation；
* conformance constraints；
* required capabilities。

不定义：

* 重复键投影策略；
* formatter 风格；
* Query 选择；
* 资源限制；
* 外部加载规则。

---

## 9.1 `json.strict@1`

* UTF-8；
* 标准 JSON string 和 number；
* 不允许 comments；
* 不允许 trailing comma；
* 不允许 single-quoted string；
* 不允许 unquoted key；
* 不允许 NaN 或 Infinity；
* leading UTF-8 BOM 被原样保存，但产生 Profile conformance diagnostic。

重复 member：

* 原样保留；
* 不阻止 Document 形成；
* 产生稳定 diagnostic；
* 投影到 Object 时必须显式处理。

---

## 9.2 `jsonc.bounded@1`

在 `json.strict@1` 基础上只增加：

* `//` line comment；
* `/* ... */` block comment；
* object 和 array trailing comma；
* 可选 leading UTF-8 BOM。

明确不增加：

* single quotes；
* unquoted keys；
* hexadecimal numbers；
* NaN/Infinity；
* JavaScript expressions；
* multiline string extensions。

---

## 9.3 自定义 Profile

自定义 Profile 必须拥有：

* 稳定命名空间 ID；
* 不可变版本；
* 基础 Profile；
* 明确差异；
* Capability 要求；
* 符合性案例。

匿名运行时 flags 不能作为跨进程或跨语言的 Profile 身份。

---

# 10. PortableValue v1

`PortableValue` 是：

> **封闭、不可变、无对象身份的纯值树。**

核心类型：

```text
Null
Boolean

Integer
Decimal
BinaryFloat32
BinaryFloat64

String
Bytes

Date
Time
LocalDateTime
OffsetDateTime

Sequence
Object
EntryMapping
```

它不包含：

```text
Missing
Undefined
Unavailable
Unsupported
ErrorValue
Deleted
```

缺失属于关系，失败属于结果，删除属于操作。

---

## 10.1 Integer

* 任意精度；
* 有符号；
* 不依赖机器位宽；
* 不保存原始进制、正号、前导零等字面量信息。

JSON 无小数点和指数的合法 number 投影为 Integer。

---

## 10.2 Decimal

表示有限精确十进制：

```text
coefficient × 10^exponent
```

coefficient 和 exponent 均为任意精度整数。

规范化：

* coefficient 去除十进制尾零；
* exponent 同步增加；
* 零使用唯一表示。

因此：

```text
1.0
1.00
10e-1
```

进入 PortableValue 后是同一个 Decimal。

原始写法仍由 Document 保存。

---

## 10.3 BinaryFloat32 / BinaryFloat64

表示明确的 IEEE 754 binary32 或 binary64 datum。

保存完整位模式。

严格相等要求：

```text
相同浮点格式
+
相同位模式
```

因此：

* `+0.0` 与 `-0.0` 严格不相等；
* 相同 NaN 位模式严格相等；
* 不同 NaN payload 严格不相等；
* Float32 与 Float64 严格不相等。

宿主语言浮点 `==` 不得定义公共语义。

---

## 10.4 String

* Unicode scalar value 序列；
* 不绑定源编码或转义写法；
* 不自动执行 NFC/NFD；
* 非法孤立 surrogate 不得静默进入。

严格相等按 scalar value 序列。

---

## 10.5 Bytes

* 原始 octet sequence；
* 不假设 UTF-8、Base64 或 Hex；
* 与 String 永远是不同类型；
* 所有编码和解码必须显式。

---

## 10.6 时间类型

### Date

* proleptic Gregorian calendar；
* astronomical year numbering；
* year 为任意精度有符号整数；
* month/day 必须是有效日期。

### Time

* hour：0–23；
* minute：0–59；
* second：0–59；
* fractional second：精确有限十进制；
* 不支持 leap second；
* 不支持 `24:00:00`。

### LocalDateTime

```text
Date + Time
```

没有 offset，不是时间戳。

### OffsetDateTime

```text
LocalDateTime + fixed UTC offset seconds
```

offset 为绝对值小于 24 小时的整秒数。

它可以定位时间线，但不包含 IANA region timezone。

---

## 10.7 Sequence

* 有序；
* 允许重复；
* 元素为任意 PortableValue；
* 顺序进入严格相等和规范编码。

---

## 10.8 Object

* key 必须是 String；
* key 必须唯一；
* 条目顺序保留并可观察；
* 顺序属于严格值结构。

普通 `ObjectBuilder` 遇到重复键必须失败。

---

## 10.9 EntryMapping

* 有序 association 序列；
* key 可以是任意 PortableValue；
* 允许重复；
* 顺序和重复都属于值语义。

```text
Object → EntryMapping
```

可以无损完成。

```text
EntryMapping → Object
```

必须验证：

* key 全部是 String；
* key 全部唯一。

字符串化、覆盖或折叠必须显式授权并报告。

---

## 10.10 不可变性

完成后的 PortableValue 永不原地修改。

允许实现使用：

* Builder；
* persistent data structure；
* copy-on-write；
* reference counting；
* structural sharing。

但内部共享不得通过：

* 指针身份；
* 修改传播；
* 对象 ID；

进入公共语义。

---

# 11. ExtendedValue

非核心类型由独立层表达：

```text
ExtendedValue {
    type_id,
    semantic_version,
    canonical_payload
}
```

扩展必须定义：

* 稳定命名空间；
* 不可变版本；
* 正式语言无关语义；
* payload schema；
* validation；
* strict equality；
* deterministic encoding；
* unknown-type behavior；
* capabilities；
* conformance cases。

支持级别：

```text
SemanticSupport
OpaquePreservation
Reject
```

Opaque 实现可以保存和转发已经验证的规范 payload，但不得声称：

* 理解其语义；
* 能验证扩展不变量；
* 能完成语义相等；
* 能安全修改 payload。

原生 tag 不会自动变成 Extension。

---

# 12. 相等、等价与哈希

## 12.1 StrictValueEqual

基础相等关系：

* 类型敏感；
* 结构敏感；
* 顺序敏感；
* 无隐式转换。

例如：

```text
Integer(1) != Decimal(1)
String("A") != Bytes([0x41])
```

Object 顺序不同则严格不相等。

OffsetDateTime 的本地字段或 offset 不同则严格不相等，即使对应同一绝对时刻。

---

## 12.2 明确命名的等价关系

其他关系独立定义，例如：

```text
ExactNumericEquivalent
FloatToleranceEquivalent
ObjectMappingEquivalent
SameInstant
UnicodeNormalizedEquivalent
```

每一种关系必须声明：

* 适用类型；
* 转换规则；
* 精度与舍入；
* 失败行为；
* Capability；
* 一致哈希。

不存在万能：

```text
smart_equal
loosely_equal
semantic_equal
```

---

## 12.3 哈希

每一种可用于集合或缓存的相等关系都有独立哈希契约。

严格哈希满足：

```text
StrictValueEqual(a, b)
⇒
StrictValueHash(a) == StrictValueHash(b)
```

ObjectMappingEquivalent 等关系不得复用含糊的普通 `hash()`。

---

# 13. PVCE/1

## 13.1 定位

`Portable Value Canonical Encoding / 1` 是：

* 无损；
* 确定；
* 自描述；
* 跨语言；
* 严格保留类型；
* 严格保留顺序；
* 适合摘要、签名和协议交换。

它不是：

* Document rendering；
* JSON formatter；
* 宿主语言对象序列化；
* parser AST 编码。

---

## 13.2 Stream framing

```text
magic
encoding version
root value record
```

每个 record：

```text
tag: minimal unsigned varint
payload_length: minimal unsigned varint
payload
```

所有可变长整数必须使用唯一最短形式。

固定 tag registry：

```text
0x00 Null
0x01 False
0x02 True

0x10 Integer
0x11 Decimal
0x12 BinaryFloat32
0x13 BinaryFloat64

0x20 String
0x21 Bytes

0x30 Date
0x31 Time
0x32 LocalDateTime
0x33 OffsetDateTime

0x40 Sequence
0x41 Object
0x42 EntryMapping

0x7F ExtendedValue
```

---

## 13.3 Integer

payload：

```text
sign byte
magnitude length
minimal big-endian magnitude
```

零必须使用唯一编码。

不得出现 magnitude 前导零。

---

## 13.4 Decimal

payload 编码规范化后的：

```text
coefficient
exponent
```

两者使用规范任意精度整数编码。

非规范化 Decimal 不得进入 PVCE encoder。

---

## 13.5 BinaryFloat

* Float32：4 字节原始 IEEE 位模式；
* Float64：8 字节原始 IEEE 位模式；
* 固定网络字节序；
* 不规范化 NaN；
* 不折叠 signed zero。

---

## 13.6 String 与 Bytes

String：

```text
UTF-8 length
exact UTF-8 bytes
```

不执行 Unicode normalization。

Bytes：

```text
length
raw octets
```

---

## 13.7 时间

Date：

```text
year
month
day
```

Time：

```text
hour
minute
second
normalized fractional second
```

LocalDateTime：

```text
Date payload
Time payload
```

OffsetDateTime：

```text
LocalDateTime payload
signed offset seconds
```

---

## 13.8 容器

Sequence：

```text
element count
element records in order
```

Object：

```text
entry count
String key record
value record
...
```

不得排序。

EntryMapping：

```text
entry count
key record
value record
...
```

不得去重或折叠。

---

## 13.9 ExtendedValue

payload：

```text
type_id
semantic_version
payload_codec_id
canonical payload bytes
```

未知扩展只能在明确具备 opaque-preservation 能力时原样保留。

---

## 13.10 解码

严格解码只接受规范形式。

任何宽松解码必须作为独立 Capability：

* 报告输入非规范；
* 不改变解码值；
* 重新编码时输出唯一规范形式。

未知核心 tag 不能解码成 PortableValue。

它可以被保存为独立的：

```text
OpaqueEncodedValue
```

但该对象不属于 PortableValue。

---

# 14. Capability

Capability 是：

> **命名、版本化、可验证的行为承诺。**

例如：

```text
core.document.exact-roundtrip@1
core.value.strict-equality@1
core.pvce.full@1
core.query.ordered-results@1
json.projection.best-exact-core@1
json.edit.scalar-replace@1
```

必须区分：

```text
Capability specification
Implementation support
Verification status
Request applicability
Operation outcome
```

Implementation support：

```text
Conformant
Conditional
Unsupported
```

Verification status：

```text
Verified
SelfDeclared
Unverified
```

Conditional 必须提供机器可读的前置条件，不能只写自然语言“部分支持”。

---

# 15. Result 与 Diagnostic

## 15.1 Operation Result

控制流程状态：

```text
Success
Failed
Cancelled
ResourceLimited
Unsupported
NotApplicable
```

实际操作可以定义更细的稳定子类型。

---

## 15.2 Diagnostic

每条 Diagnostic 包含：

* stable namespaced code；
* category；
* severity；
* primary location；
* related locations；
* structured arguments；
* notes；
* optional fix proposals。

自然语言可以本地化，机器依赖的是 code 和结构化参数。

---

## 15.3 Severity 与成功分离

可能存在：

* 成功并产生 warning；
* 失败但 diagnostic severity 不是 error；
* Document 形成成功但不符合 Profile；
* Query 完成且零匹配。

不能用 severity 推断控制流程。

---

## 15.4 Diagnostic 归属

* Document diagnostics 属于 Document + Profile；
* Query validation diagnostics 属于 QueryDefinition；
* operation diagnostics 属于具体请求；
* Projection losses 属于 ProjectionReport。

操作诊断不得写回并污染 Document 快照。

---

## 15.5 确定顺序

诊断按：

1. source/structural order；
2. operation phase；
3. stable code；
4. stable occurrence ordinal；

排序。

并行完成时机不得改变公开顺序。

达到 diagnostic limit 时必须输出明确 truncation marker，不能静默截断。

---

# 16. ValuePath、AssociationLocation、NodeRef 与 Span

## 16.1 ValuePath

`ValuePath` 只指向 PortableValue 中的值。

片段：

```text
ObjectValue(String key)
SequenceElement(non-negative index)
EntryKey(non-negative entry index)
EntryValue(non-negative entry index)
```

根值使用空路径。

索引不支持隐式负数。

---

## 16.2 AssociationLocation

用于表达：

* Object entry；
* Object key role；
* EntryMapping entry；
* association 本身。

它不是 PortableValue 节点身份。

---

## 16.3 Query

Query 表达搜索意图，可以返回零到多个结果。

---

## 16.4 NodeRef

NodeRef 锁定特定 Document 快照中的精确结构身份。

---

## 16.5 Span

Span 只表达该快照中的字节位置。

总纲：

> **Path 表达路线，Query 表达搜索，NodeRef 表达身份，Span 表达位置。**

---

# 17. Query Domain

v1 正式领域：

```text
core.portable-value-query@1
json.native-semantic-query@1
```

未来领域可以包括：

```text
json.lossless-syntax-query@1
toml.native-semantic-query@1
```

但必须单独完成运算符、角色和符合性规范后才能发布。

QueryDefinition 必须携带：

```text
domain_id
domain_version
```

领域不匹配时：

```text
DomainMismatch
```

不得自动：

* project；
* reparse；
* translate；
* follow provenance。

跨领域操作必须显式。

---

# 18. Query 生命周期

```text
QueryDefinition
    ↓ domain and structural validation
ValidatedQuery
    ↓ capability binding
ExecutableQuery
    ↓ bind immutable target
QueryExecution
```

## 18.1 QueryDefinition

* 声明式；
* 可传输；
* 可保存；
* 可能含当前实现未知 operator；
* 尚不一定可执行。

## 18.2 ValidatedQuery

保证：

* Domain 和版本合法；
* Operator 属于该领域；
* 参数类型正确；
* Operator 组合正确；
* Match role 兼容；
* ordering/cardinality 信息完整。

## 18.3 ExecutableQuery

进一步保证当前引擎具备全部所需 Capability。

## 18.4 QueryExecution

绑定：

* 一个不可变 PortableValue；
* 或一个具体 Document 快照。

执行期间目标不得漂移。

---

## 18.5 不允许晚发现的定义错误

以下错误必须在输出第一项 Match 前失败：

* UnknownOperator；
* DomainMismatch；
* WrongArgumentType；
* InvalidOperatorComposition；
* MissingRequiredCapability。

执行开始后仍可能出现：

* ResourceLimitExceeded；
* Cancelled；
* TargetUnavailable；
* InternalFailure。

---

# 19. 类型化 Query Algebra

每个 Operator 必须声明：

```text
domain
operator_id + version
input match role
output match role
subject constraints
cardinality effect
ordering effect
duplication effect
argument schema
required capabilities
```

---

## 19.1 Value Query roles

```text
ValueMatch
ObjectEntryMatch
EntryMappingEntryMatch
```

`ValueMatch` 包含：

* root-relative ValuePath；
* borrowed/observed PortableValue。

`ObjectEntryMatch` 包含：

* association location；
* key String；
* value ValuePath。

---

## 19.2 JSON Native Query roles

```text
JsonValueMatch
JsonObjectMemberMatch
JsonArrayElementMatch
```

`JsonObjectMemberMatch` 保留：

* member ordinal；
* decoded member name；
* key NodeRef；
* value NodeRef；
* member NodeRef。

重复 member 不会合并。

---

## 19.3 Filter、Try 与 Require

必须区分：

```text
WhereType(Object)
```

非 Object 时过滤为零匹配。

```text
TryObjectEntries
```

只对 Object 展开，其他输入产生零项。

```text
RequireType(Object)
```

非 Object 时执行失败。

同一 Operator 不得根据语言习惯在“过滤”和“失败”之间切换。

---

## 19.4 组合运算

标准机制包括：

```text
MapOne
Filter
Expand
FlatMap
Concat
StructureOrderMerge
DistinctByIdentity
Take
```

默认不去重。

`Concat(A, B)`：

```text
A 的全部结果
+
B 的全部结果
```

`StructureOrderMerge` 按共同目标的结构顺序合并。

`DistinctByIdentity` 必须声明使用：

* NodeRef；
* ValuePath；
* AssociationLocation；

中的哪一种身份，不能按严格值相等自动去重。

---

## 19.5 基数选择

```text
All
First
Last
ZeroOrOne
RequireOne
```

* `First`：多匹配时选择第一项；
* `Last`：选择标准结果序列最后一项；
* `ZeroOrOne`：多匹配时失败；
* `RequireOne`：零项或多项都失败；
* `All`：需要确认完整执行结束。

---

## 19.6 确定顺序

同一：

* target snapshot/value；
* QueryDefinition；
* Domain version；
* relevant Capability version；

必须产生相同匹配数量、身份和顺序。

基础顺序：

* Document：格式原生结构顺序；
* Sequence：索引顺序；
* Object：条目顺序；
* EntryMapping：条目序号。

并行执行允许，但公开结果前必须恢复标准顺序。

---

## 19.7 执行方式

允许：

* materialized result；
* lazy cursor；
* ordered stream。

流终止状态：

```text
Completed
Cancelled
Failed
```

失败前已输出的 Match 是真实局部发现，但不能冒充完整 QueryResult。

---

## 19.8 快照语义

QueryExecution 只属于绑定的目标。

Document 从 `D1` 编辑为 `D2` 后：

* 对 `D1` 的旧结果仍指向 `D1`；
* 不会自动变成 `D2` 的结果；
* 跨快照迁移必须使用显式 ChangeSet/NodeMapping；
* Live Query 属于未来独立能力。

---

# 20. Query 协议编码

QueryDefinition 等声明式协议对象采用：

```text
Versioned Protocol Schema
→ PortableValue
→ PVCE/1
```

每个 Protocol Schema 必须定义：

* 固定字段；
* 字段类型；
* 字段顺序；
* required/optional；
* extension point；
* unknown-field behavior。

默认规则：

> **未知字段拒绝。**

只有 Schema 明确设置的 namespaced extension map 可以保留未知扩展。

不得通过宿主语言对象序列化 Query。

---

# 21. Projection

## 21.1 投影目标

v1 标准 Target Contract：

```text
ProjectAsObject@1
ProjectAsEntryMapping@1
BestExactCore@1
```

请求 Object 时不能失败后偷偷返回 EntryMapping。

---

## 21.2 `BestExactCore@1`

固定算法：

1. 原生 scalar 投影为对应核心 scalar；
2. mapping 具有唯一 String key 时优先 Object；
3. 其他能精确保留的 mapping 使用 EntryMapping；
4. 无法精确进入核心值时失败；
5. 不自动使用 ExtendedValue；
6. 不自动发生有损转换；
7. 不根据 String 外观识别 Date、Bytes、UUID 或其他类型。

未来修改选择顺序必须发布 `@2`。

---

## 21.3 ProjectionRequest

`ProjectionRequest`：

* 不可变；
* 声明式；
* 版本化；
* 可记录；
* 可重放。

包含：

```text
target contract
default policy
scoped policy rules
```

默认：

```text
ExactOrReject
```

不存在笼统：

```text
lossy = true
```

---

## 21.4 策略类别

独立声明：

* duplicate keys；
* non-string keys；
* reference handling；
* unsupported values；
* extension usage；
* binary-to-text；
* temporal-to-text；
* numeric conversion。

授权其中一种损失，不代表授权其他损失。

---

## 21.5 策略作用域

完整架构支持：

```text
Exact NodeRef
Exact native semantic path
Resolved native-semantic Query scope
Global
```

优先级：

```text
Exact NodeRef
> more-specific exact path
> Query scope with explicit priority
> Global
```

同等级、同优先级且不能合并的冲突导致请求无效。

规则声明顺序不参与语义。

`0.1.0` 只要求实现：

* Global；
* Exact NodeRef。

---

## 21.6 投影结果

正式结果：

```text
CompleteProjection {
    value,
    fidelity,
    report,
    provenance
}
```

或：

```text
FailedProjectionAttempt {
    diagnostics,
    report,
    partial_analysis
}
```

不存在 partial PortableValue。

---

## 21.7 Fidelity

```text
Exact
Transformed
Lossy
```

定义：

* `Exact`：目标模型直接、完整保留本次投影承诺覆盖的原生语义；
* `Transformed`：全部相关语义被保留，但经过明确、可逆的结构或类型重编码；
* `Lossy`：至少一个相关语义事实无法从结果恢复。

`Lossy` 只有在调用者明确授权时才能成功。

---

## 21.8 ProjectionReport

机器可读事件至少包括：

```text
StructureReencoded
TypeMapped
ReferenceExpanded
DuplicateCollapsed
KeyStringified
ValueRounded
FieldDropped
TagDiscarded
```

每项记录：

* 命中的 policy rule；
* source location；
* projected location；
* old semantic category；
* new semantic category；
* reversibility；
* loss classification。

---

## 21.9 局部失败

失败时可以返回分析树：

```text
Projectable
RequiresPolicy
Unsupported
Unavailable
ResourceBlocked
```

它可以帮助编辑器和迁移工具，但不能被转换成完整值，除非所有必要节点均完成并重新通过正式完成检查。

---

# 22. Provenance

`ProvenanceMap` 是多对多映射：

```text
ProjectedLocation
→ 0..n SourceOrigin
```

`ProjectedLocation` 可以是：

* ValuePath；
* AssociationLocation。

`SourceOrigin` 包含：

* Document snapshot identity；
* NodeRef；
* Span；
* relation type。

relation：

```text
Direct
Derived
Expanded
Merged
Generated
```

允许：

* 程序构造值没有来源；
* 一个值有多个来源；
* 一个来源产生多个值位置；
* 显式删除的来源只出现在 ProjectionReport，不伪造目标位置。

provenance：

* 不进入 PortableValue；
* 不参与严格相等；
* 不进入值的 PVCE；
* 不自动跨快照更新。

---

# 23. Document 编辑模型

## 23.1 不可变快照与原子事务

```text
Old Document
+
EditTransaction
→
New Document + ChangeSet
```

失败时旧 Document 完全不变。

不存在公开可观察的半修改状态。

---

## 23.2 编辑目标

最终编辑目标必须是：

```text
NodeRef
```

Path 和 Query 只负责寻找候选。

在执行编辑前必须显式完成：

* zero；
* one；
* many；

处理和唯一化。

---

## 23.3 基础快照规则

事务内所有操作均针对同一个基础快照解析。

前一个操作不会让后续 Query 或 Path 自动重新寻址。

需要依赖前一步新结构的修改必须：

* 使用一个正式 Composite Edit；
* 或提交后获得新 Document，再开始下一事务。

---

## 23.4 冲突

默认拒绝：

* 重叠 source edits；
* 一个操作删除另一个目标；
* 同一区域产生不确定重建；
* 同一插入点的多个插入没有显式顺序；
* 同一 scalar 被多次替换。

相关修改必须由一个具有明确定义的 Composite Edit 统一负责。

---

## 23.5 标量替换

v1 定义两类操作。

### SemanticScalarReplacement

输入：

```text
target NodeRef
new native/public semantic value
explicit RepresentationPolicy
```

### LiteralScalarReplacement

输入：

```text
target NodeRef
exact candidate literal bytes/text
```

候选 literal 必须通过目标 Profile 验证为一个完整、合法的对应 scalar literal。

---

## 23.6 RepresentationPolicy

```text
ExactLiteral
PreserveCompatible
CanonicalForProfile
PreserveElseCanonical
```

### ExactLiteral

调用者完全指定写法，系统只验证。

### PreserveCompatible

只有在能够保持兼容表示风格时成功；无法保持则失败。

### CanonicalForProfile

使用 Profile 定义的标准字面量表示。

### PreserveElseCanonical

明确允许 PreserveCompatible 失败后回退到 canonical。

回退不能隐藏。

---

## 23.7 Trivia 保证

普通 scalar replacement：

* 不修改前导和后随 trivia；
* 不移动 comments；
* 不运行 formatter；
* 只修改 literal 必需字节。

删除、移动、插入结构时的 trivia 规则由各自 Edit Capability 单独定义。

---

## 23.8 恢复文档编辑

每项 Edit Capability 明确声明是否支持 Recovered Document。

`0.1.0` scalar replacement 只允许目标满足：

* syntax node 完整；
* literal 完整；
* native semantics 可用；
* NodeRef 属于基础快照。

Missing value、error region 或不完整 literal 不能冒充 scalar replacement 目标。

---

## 23.9 Formatter

Formatter 是独立操作：

* 可以重写大范围内容；
* 必须声明格式化范围；
* 返回新 Document 和 ChangeSet；
* 永远不被普通 edit 隐式调用。

---

## 23.10 ChangeSet

包含：

* ordered non-overlapping source edits；
* old ranges；
* new ranges；
* affected nodes；
* known node mappings；
* unmapped reasons；
* operation diagnostics。

Node mapping 状态：

```text
Preserved
Replaced
Deleted
Split
Merged
Unmapped
```

旧 NodeRef 永远不会在背后变成新 NodeRef。

---

# 24. 资源限制、取消与安全

资源限制属于执行策略，不改变语义。

## 24.1 Parse limits

* source bytes；
* nesting depth；
* token count；
* node count；
* diagnostic count。

## 24.2 Value limits

* integer digits；
* decimal coefficient digits；
* exponent magnitude；
* String/Bytes length；
* container entries；
* total nodes。

## 24.3 Query limits

* execution steps；
* recursion；
* result count；
* buffering；
* diagnostic count。

## 24.4 Projection limits

* produced value size；
* reference expansion；
* report entries；
* provenance entries；
* partial-analysis nodes。

超过限制：

* 明确失败；
* 不截断为成功；
* 不自动降精度；
* 不跳过未处理节点；
* 不返回半值。

取消与失败、完成分别表达。

合法但恶意输入不得造成：

* panic；
* undefined behavior；
* 无限制递归；
* 无界内存分配。

---

# 25. Rust 参考实现

## 25.1 公共完成对象

```rust
Document
PortableValue
ExecutableQuery
ProjectionRequest
ProjectionResult
ChangeSet
```

全部不可变。

Rust `0.1.0` 发布目标是尽可能实现：

```text
Send + Sync
```

但这属于 Rust 实现属性，不属于跨语言语义。

---

## 25.2 Document API

使用 opaque type：

```rust
pub struct Document {
    /* private */
}
```

格式 typed adapter：

```rust
let json = document.as_json()?;
```

公共 API 不暴露：

* rowan；
* tree-sitter；
* parser crate AST；
* arena index；
* rope implementation。

---

## 25.3 PortableValue API

使用私有不可变节点和 typed views。

概念形式：

```rust
value.kind()
value.as_integer()
value.as_object()
value.as_entry_mapping()
```

避免将内部容器类型和缓存策略冻结为公共语义。

---

## 25.4 NodeRef API

NodeRef 是 opaque handle。

所有使用 NodeRef 的操作必须同时验证：

* 所属 Document snapshot；
* 节点角色；
* Edit Capability 前置条件。

---

## 25.5 Builder

提供：

* ObjectBuilder；
* EntryMappingBuilder；
* QueryDefinitionBuilder；
* ProjectionRequestBuilder；
* EditTransactionBuilder。

Builder 尚未完成时不是正式公共值或请求。

---

## 25.6 错误 API

不把以下类型作为公共稳定错误：

* `anyhow::Error`；
* parser backend error；
* arbitrary string。

公共错误至少具有：

```text
OperationKind
FailureKind
DiagnosticCode
```

panic 只表示实现自身不变量被破坏。

---

## 25.7 同步与异步

纯内存核心 API 默认同步。

异步属于：

* source adapters；
* network protocol；
* process plugins；
* hosted service。

不把 `async` 强加给每个纯内存查询、投影和编辑操作。

---

## 25.8 Serde

Serde 可以作为 adapter，但不得定义：

* PortableValue 数字语义；
* duplicate key 行为；
* Document round trip；
* Query schema；
* public error taxonomy。

---

## 25.9 Workspace 逻辑分层

建议保持有限 crate 数量：

```text
core
document
format-json
pvce
conformance
```

其中 `core` 内部再按：

* value；
* diagnostic；
* capability；
* query；
* projection；

划分模块。

第一阶段不为每个小概念建立独立 crate。

---

# 26. `0.1.0` 精确实现范围

## 26.1 格式

```text
json.strict@1
jsonc.bounded@1
```

---

## 26.2 PortableValue 与 PVCE

`0.1.0` 实现完整 PortableValue v1：

```text
Null
Boolean
Integer
Decimal
BinaryFloat32
BinaryFloat64
String
Bytes
Date
Time
LocalDateTime
OffsetDateTime
Sequence
Object
EntryMapping
```

并实现完整 `PVCE/1`。

JSON/JSONC 自然投影只会产生：

```text
Null
Boolean
Integer
Decimal
String
Sequence
Object
EntryMapping
```

但其他核心类型可以由程序构造、编码、解码、比较和测试。

---

## 26.3 Document 能力

必须完成：

1. UTF-8 SourceSnapshot；
2. Complete/Recovered parse；
3. FatalFormationFailure；
4. byte-exact unmodified round trip；
5. lossless JSON/JSONC syntax；
6. token、trivia、error region 覆盖；
7. stable Span；
8. snapshot-bound NodeRef；
9. deterministic diagnostics；
10. JSON native semantic view；
11. duplicate member preservation。

---

## 26.4 Query 能力

必须完成：

```text
core.portable-value-query@1
json.native-semantic-query@1
```

包括：

* QueryDefinition；
* validation；
* Capability binding；
* ExecutableQuery；
* snapshot-bound execution；
* typed match roles；
* deterministic order；
* materialized execution；
* lazy cursor 或 ordered stream 至少一种；
* All、First、Last、ZeroOrOne、RequireOne、Take；
* explicit completion/cancellation/failure。

无损 Syntax Query Domain 不属于 `0.1.0` 公共标准。

---

## 26.5 Projection 能力

必须完成：

```text
ProjectAsObject@1
ProjectAsEntryMapping@1
BestExactCore@1
```

重复 key policies：

```text
Reject
FirstWins
LastWins
```

`Merge` 不进入首版。

必须包含：

* CompleteProjection；
* FailedProjectionAttempt；
* fidelity；
* ProjectionReport；
* basic provenance；
* Global scope；
* Exact NodeRef scope。

---

## 26.6 Edit 能力

只实现：

```text
SemanticScalarReplacement
LiteralScalarReplacement
```

RepresentationPolicy：

```text
ExactLiteral
PreserveCompatible
CanonicalForProfile
PreserveElseCanonical
```

要求：

* 目标 NodeRef 完整；
* 失败原子；
* trivia 保持；
* 最小 literal 修改；
* ChangeSet；
* wrong-snapshot rejection。

---

## 26.7 Conformance

必须提供语言无关测试向量：

* PortableValue equality/hash；
* PVCE；
* parse formation；
* exact round trip；
* recovery；
* diagnostics；
* native semantic view；
* duplicate members；
* Query validation；
* Query order；
* Projection；
* provenance；
* scalar edit；
* ChangeSet；
* resource limits。

---

## 26.8 明确不做

`0.1.0` 不包含：

* TOML；
* YAML；
* Schema；
* Diff/Patch；
* Formatter；
* Live Query；
* Incremental Parsing；
* Expression Evaluation；
* Import；
* Reference Resolution；
* PortableGraph；
* Language Bindings；
* Stable Process Plugin Protocol；
* GUI；
* 正式 CLI 产品；
* 全量结构编辑；
* Auto-fix system。

开发调试 CLI 可以存在，但不构成公共契约。

---

# 27. 实施顺序

## 阶段一：公共值与基础协议

* PortableValue v1；
* equality/hash；
* builders；
* PVCE/1；
* value conformance vectors。

## 阶段二：Source 与 JSON Document

* SourceSnapshot；
* JSON/JSONC lexer/parser；
* lossless structure；
* recovery；
* diagnostics；
* rendering。

## 阶段三：原生语义与 Query

* JSON native semantic view；
* QueryDefinition；
* typed algebra；
* ordered execution；
* Query tests。

## 阶段四：Projection 与 Provenance

* target contracts；
* policies；
* reports；
* provenance；
* conformance。

## 阶段五：Edit

* scalar targeting；
* semantic/literal replacement；
* representation policies；
* transaction；
* ChangeSet。

## 阶段六：发布加固

* fuzzing；
* malicious corpus；
* resource limits；
* public API review；
* documentation；
* full conformance run。

---

# 28. `0.1.0` 发布门槛

必须同时满足：

* 所有 mandatory Capability 测试通过；
* 未修改 Document 字节精确往返；
* recovery corpus 行为稳定；
* duplicate members 不丢失；
* Query 数量、身份和顺序跨执行方式一致；
* 所有 Query 定义错误在首个 Match 前失败；
* Projection 无静默损失；
* provenance 能区分重复 member；
* scalar replacement 只修改允许区域；
* wrong-snapshot NodeRef 必须失败；
* PVCE 编解码和规范性向量全部通过；
* 非规范 PVCE 输入按规定拒绝；
* 合法恶意输入不触发 panic；
* resource limit 不产生截断假成功；
* parser/backend 类型不泄漏到公共 API；
* 所有 public behavior 均有语言无关测试。

---

# 29. 第二格式门槛

第二阶段优先选择 TOML，用于验证 JSON 抽象是否过拟合。

必须验证：

* table；
* inline table；
* array of tables；
* dotted keys；
* native date/time；
* comment/trivia；
* Object 与 EntryMapping；
* native semantic Query；
* format-specific edit rules。

在 TOML 验证之前：

* JSON member 不直接提升为所有格式共同 member；
* JSON typed syntax 不提升为公共 CST；
* 尚未被第二格式验证的抽象标记为 provisional；
* 不宣称已经形成完整跨格式事实标准。

---

# 30. 后续 RFC 接入边界

## 30.1 Schema

Schema 独立使用：

* Native Semantic View；
* PortableValue；
* provenance；
* Diagnostic。

Schema 不进入 Document 核心状态。

---

## 30.2 Evaluation

```text
Document + EvaluationContext
→ EvaluationResult
```

不得在 parse 或 project 时隐式执行。

---

## 30.3 Diff/Patch

必须分别设计：

* Document syntax diff；
* PortableValue diff；
* Patch target identity；
* conflict semantics；
* cross-snapshot applicability。

不存在万能 diff。

---

## 30.4 Live Query

建立在一系列不可变快照查询之上，未来事件至少考虑：

```text
Added
Removed
Updated
Moved
Reset
```

普通 Query 永远保持快照语义。

---

## 30.5 PortableGraph

只有在 YAML 等真实图语义格式验证后单独建立。

不得向 PortableValue 中加入引用、共享和 cycle。

---

## 30.6 Syntax Query

基于格式 typed syntax view 单独定义：

* Domain；
* match roles；
* operators；
* ordering；
* conformance。

它不会改变 ValueQuery 或 NativeSemanticQuery。

---

# 31. 非规范性开源与商业策略

建议开放：

* 核心规范；
* Capability 定义；
* Conformance Suite；
* Rust core；
* 基础 JSON/TOML 实现；
* PVCE。

商业价值可以集中于：

* 企业迁移工具；
* IDE 和可视化编辑器；
* 审计与 provenance；
* Schema/策略治理；
* 批量转换；
* 行业格式包；
* 企业支持；
* 托管 conformance；
* 官方兼容认证。

兼容认证应明确：

```text
Conformant with <capability set>
Verified against <suite version>
```

---

# 32. 永久不变量

1. Document 是唯一文档状态。
2. Document 是不可变快照。
3. Source 保存完整原始字节。
4. 未修改 Document 必须字节精确往返。
5. Native Semantic View 不被 PortableValue 取代。
6. 不存在万能无损语法树。
7. PortableValue 是完整、不可变、无身份的纯值。
8. Missing、失败和诊断不属于值。
9. 核心值类型封闭。
10. Extension 必须有正式语义契约。
11. Strict equality 不执行隐式转换。
12. Canonical encoding 与抽象值分离。
13. Provenance 不进入值。
14. ValuePath、AssociationLocation、Query、NodeRef、Span 职责分离。
15. Query 结果有确定顺序。
16. Query 执行绑定单一不可变目标。
17. Query Domain 不静默转换。
18. Query 在执行前完成验证与 Capability 绑定。
19. Query Operator 具有正式输入输出角色。
20. Projection 成功值必须完整。
21. Projection Target 与 Policy 分离。
22. 未授权损失默认拒绝。
23. Edit 绑定基础快照。
24. Edit 原子提交。
25. Formatter 不会隐式运行。
26. Profile 定义语言，不定义操作偏好。
27. Capability 是可验证行为承诺。
28. Result 决定流程，Diagnostic 解释问题。
29. Parser/backend 不拥有公共语义定义权。
30. 所有跨语言行为必须由共同测试验证。
31. 旧契约不会被新版本重新解释。
32. 未来 RFC 不得破坏以上不变量。

---

# 33. 五要素终审

## 33.1 哲学统一：通过

所有模块都遵守同一哲学：

* 单一真实状态；
* 完成对象不可半成功；
* 差异显式；
* 默认不猜；
* 观察与状态分离；
* 实现自由、行为稳定。

没有某个子系统依赖与其他部分相反的设计原则。

---

## 33.2 语义一致：通过

核心概念具有唯一职责：

```text
SourceSnapshot       保存原始字节
Document             保存内容快照
Lossless Syntax      表达格式结构事实
Native Semantic View 表达格式本义
PortableValue        表达公共值
ExtendedValue        表达正式扩展类型
Projection           表达跨模型转换
ProjectionReport     表达转换发生了什么
Provenance           表达结果从哪里来
Query                表达搜索意图
ValuePath            表达公共值路线
AssociationLocation  表达关联位置
NodeRef              表达文档结构身份
Span                 表达字节位置
EditTransaction      表达原子修改
ChangeSet            表达快照变化
Result               表达控制流程
Diagnostic           表达问题
Profile              表达语言契约
Capability           表达行为承诺
PVCE                 表达公共值规范字节
```

不存在一个对象根据上下文临时改变核心含义。

---

## 33.3 逻辑自洽：通过

主链条闭合：

```text
bytes
→ Document
→ native semantics
→ explicit ProjectionRequest
→ complete PortableValue
→ strict equality
→ PVCE
```

编辑链条闭合：

```text
immutable Document
→ validated Query
→ ordered matches
→ exact NodeRef
→ atomic transaction
→ new Document
→ ChangeSet
```

跨层转换均显式，不存在循环依赖或隐藏状态同步。

---

## 33.4 真实有效：通过

设计覆盖真实生态中的核心困难：

* duplicate keys；
* arbitrary precision numbers；
* exact decimal；
* signed zero 和 NaN；
* Unicode normalization；
* Bytes；
* temporal types；
* comments/trivia；
* recovered documents；
* deterministic Query ordering；
* streaming and cancellation；
* lossy conversion；
* provenance；
* minimal editing；
* malicious inputs；
* cross-language encoding；
* capability verification。

同时没有把加载、配置中心、Schema、GUI 等相邻问题塞入核心。

---

## 33.5 完整可靠：通过

在 `0.1.0` 开始实现前必须回答的基础问题均已覆盖：

* 边界；
* 核心对象；
* 类型系统；
* 生命周期；
* 身份；
* 所有权；
* 相等；
* 编码；
* 查询；
* 投影；
* provenance；
* 编辑；
* 诊断；
* Profile；
* Capability；
* 资源；
* 安全；
* Rust API；
* 测试；
* 版本；
* 发布门槛。

未来仍会有功能设计问题，但它们已经被隔离为独立 RFC，不会迫使核心架构返工。

---

# 34. 最终确认

本项目不是：

> 一个支持多种配置格式的 Rust 解析工具箱。

它是：

> **一套以无损 Document 保存内容事实、以格式原生语义保持真实性、以 PortableValue 建立共同值空间、以类型化 Query 和显式 Projection 提供标准操作、以 Capability 与 Conformance 保证跨语言一致性的配置内容处理标准。**

最高原则最终冻结为：

> **不通过抹平差异获得统一，而通过精确定义共同部分、明确表达真实差异，并让全部公共行为可记录、可重放、可验证来获得统一。**

本文是唯一有效的最终架构基线。此前快速稿和中间稿全部作废。
