# Consema 0.10.0 Property List 家族实现计划

> **拆分后路径注记（2026-08-14 波 2）**：本文为 2026-08 拆仓前撰写的 0.10.0 规划记录，
> 文中 `crates/consema-*` 为拆分前单仓布局路径，六仓拆分后对应物为
> `consema-rs/consema-*`；按 G76 处置约定，历史规划文档以本节注记统一标注。

- 对应规范：`docs/rfcs/0013-plist-family-profiles-v1.md`（16 节，`plist.xml@1` 与 `plist.binary@1`）
- 目标版本：0.10.0（对齐路线图 §14.9）
- 先例实现：`crates/consema-xml/`（0.9.0，9 模块约 13k 行）、`crates/consema-ini/`（lib.rs 导出组织）、`crates/consema-properties/`（Java UTF-16 字符串类型）
- 语义权威顺序（沿用 `docs/IMPLEMENTATION.md`）：永久不变量 → 已接受 RFC → 语言无关 conformance vectors → 本实现计划与 Rust API → 第三方 parser 行为仅为实现细节

本文是只读调研产出的执行计划；除本文外本次不修改任何仓库文件。所有行数估计为 Rust 源码（含该模块内测试）规模级，参考 consema-xml 各模块实际行数（parser 2649、edit 2490、projection 1945、materialization 1825、query 1735、document 884）。

---

## 0. 总体结构

RFC 0013 与 RFC 0012 的关键差异是：**两个 representation 共享一个 native value model，但语法系统完全不相交**（§1、§7）。因此新 crate 的拆分原则是：共享层（value、document、limits、operation registry）在前，两个 parser 各自成模块、互不依赖，下游操作（query/projection/materialization/edit）全部在共享层之上，按 representation 分支派发。

```text
crates/consema-plist/
├── Cargo.toml                 # 依赖：consema-core、consema-document、xmlparser（workspace 钉版）
└── src/
    ├── lib.rs                 # 模块组装、PlistProfile、PlistEncodingSelection、PlistParseLimits、parse 入口（RFC §1-3、§12）
    ├── native.rs              # PlistValue native model：arena + 共享身份 + 类型闭集 + 2001 纪元常量（RFC §6，原计划 value.rs 实收为 native.rs）
    ├── document.rs            # Document 枚举（Xml/Binary 两个变体）、原生事实访问、双 representation 统一层（RFC §7）
    ├── parser_xml.rs          # plist.xml@1 formation（RFC §4）+ PlistSyntaxKind 闭集（RFC §8.2 的 46 种 kind）+ 文本标量与 base64 编解码（原计划 xml_syntax.rs/scalar.rs/base64.rs 并入，§4.5-4.8、§10.1）
    ├── parser_binary.rs       # plist.binary@1 formation：header/marker/object/offset/trailer + 二进制结构域事实（BinaryTrailerFacts/对象表/偏移表，原计划 binary_structure.rs 并入，RFC §5、§8.3）
    ├── query.rs               # 三个查询域（RFC §8）
    ├── projection.rs          # 两个投影目标（RFC §9）
    ├── materialization.rs     # 两个 canonical style + 重解析闭包（RFC §10）
    ├── edit.rs                # 六个结构编辑操作 × 两种 representation（RFC §11）
    └── operation_registry.rs  # plist 格式操作 registry（RFC §11 契约）——in-flight：截至本文修订尚未出现在 crate 中（crate 实收 9 个文件），由并行 agent 添加中
```

模块依赖方向（单向）：

```text
lib ──> native ──> document ──> parser_xml / parser_binary ──> query / projection / materialization / edit
         │            │               │
         └────────────┴───────────────┴──> consema-document（SourceSnapshot/NodeRef/Span/ChangeSet/...）
lib / document / projection / materialization / query ──> consema-core（PortableValue/QueryDefinition/Diagnostic/...）
parser_xml ──> xmlparser 0.13.6（workspace 钉版，仅 tokenization，RFC §13）
```

RFC 章节 → 模块映射：

| RFC 0013 章节 | 模块 |
|---|---|
| §1 Decision、§2 Source、§3 Formation、§12 Resource | lib.rs（profile 选择、encoding、limits、diagnostic code 常量） |
| §4 plist.xml Profile | parser_xml.rs（formation + PlistSyntaxKind + 文本标量/base64 编解码，scalar/base64 并入） |
| §5 plist.binary Profile | parser_binary.rs（formation + 二进制结构域事实，binary_structure 并入） |
| §6 Native value model | native.rs |
| §7 双 representation | document.rs（统一层与转换入口） |
| §8 Query contracts | query.rs（三个域共用执行骨架，域注册分列） |
| §9 Projection | projection.rs |
| §10 Materialization | materialization.rs |
| §11 Structural edit | edit.rs + operation_registry.rs（in-flight，见 §0） |
| §13-14 Backend/conformance | 仓库级：conformance/vectors、consema-conformance runner、scripts（见 §6） |

## 1. crate 拓扑与复用决策

### 1.1 直接复用（consema-document，零修改或仅加枚举变体）

| 共享件 | 复用方式 | 备注 |
|---|---|---|
| `SourceSnapshot` / `EncodingRequest` | 直接复用 | **已内建 `SourceEncoding::Binary` 与 `EncodingRequest::binary()`**（source.rs），二进制 profile 无解码坐标（`DecodedStorage::None`），与 RFC §2.2 完全一致；XML profile 直接走 RFC 0012 §2 的 UTF-8/UTF-16 规则，无需新代码 |
| `ParseLimits`（common） | 直接复用，包进 `PlistParseLimits` | 照 consema-xml `XmlParseLimits { common, ... }` 体例 |
| `FatalFormationFailure` | 直接复用 | `from_diagnostic` / `resource_limit` |
| `FormationStatus` / `LosslessStructuralIndex` | 直接复用 | XML 侧 lossless 覆盖（§3） |
| `BinaryStructuralIndex` + `BinaryRegion` | **直接复用** | 已存在且正是为 opaque binary 文档设计（`NodeRole::BinaryRegion` + 格式自有 kind 字符串 + 精确覆盖校验）；二进制 plist 用它承载 header/object/offset/trailer 的穷尽字节覆盖（硬门禁 1） |
| `NodeRef` / `Span` / `DocumentAuthority` / `SnapshotIdentity` | 直接复用 | 需在 `NodeRole` 增加 plist 角色（见 1.3） |
| `ChangeSet` / `SourceEdit` / `NodeMapping` | 直接复用 | 编辑提交契约（§11） |
| `SourcePatch` / `UntouchedByteProof` | 直接复用 | 编辑交付物（§11） |
| `MaterializationRequest` / `MaterializationResult` / `MaterializationLimits` / `MaterializationFailure` | 直接复用 | `MaterializationRequest::new(profile, style)`，style id `plist.xml-canonical@1` / `plist.binary-canonical@1`（§10） |
| `EditPlan` / `FormatOperationRegistry` | 直接复用 | operation registry 照 consema-xml `format_operation_registry()` 体例 |
| `Diagnostic` / `QueryDefinition` / `QueryDomain` / `OperatorCall` 等（consema-core） | 直接复用 | 查询骨架与 consema-xml 完全同构 |
| `PortableValue` / `BigInteger` / `BinaryFloat64` | 投影目标复用 | `plist.value-tree@1` 是 PortableValue 记录（§9），非新类型 |

### 1.2 需要格式专属扩展的复用点

| 共享件 | 扩展方式 |
|---|---|
| `NodeRole` | 新增：`PlistDocument`、`PlistDictEntry`、`PlistKey`、`PlistArrayElement`、`PlistValue`（原生节点）、`PlistSyntaxPiece`（XML lossless）、二进制侧沿用现有 `BinaryRegion` 角色 |
| `FormatFamilyId` | `FormatFamilyId::new("plist", 1)`（§7 值身份统一） |
| `ProfileId` | `plist.xml`/1、`plist.binary`/1 |
| `ParseLimits` common 上限 | `max_source_bytes` 默认需覆盖 42 字节最小二进制输入；common 其余默认沿用 |
| 查询 `QueryLimits` | 直接复用；`max_results` 等无格式差异 |

### 1.3 NodeRole 增补清单（`crates/consema-document/src/lib.rs`，一次小修改）

```text
PlistDocument      完整 plist 文档句柄（native 域根）
PlistDictEntry     dict 中的一个 key/value association
PlistKey           key 身份
PlistArrayElement  数组元素 association
PlistValue         arena 原生值节点（共享身份的可被多次引用）
PlistSyntaxPiece   XML lossless piece（与 PlistSyntaxKind 平行）
```

二进制对象/偏移/trailer 全部使用既有 `BinaryRegion` 角色 + 格式自有 kind 字符串（`plist.binary.header@1`、`plist.binary.object@1`、`plist.binary.offset-entry@1`、`plist.binary.trailer@1` 等），不需要新角色。

### 1.4 依赖

`Cargo.toml`（照 consema-xml 体例，全部 workspace 钉版，**零新外部依赖**）：

```toml
[dependencies]
consema-core = { path = "../consema-core", version = "0.10.0" }
consema-document = { path = "../consema-document", version = "0.10.0" }
xmlparser.workspace = true
```

- `xmlparser 0.13.6`：仅 plist.xml 的 tokenization（RFC §13 明示）。workspace 已钉版。
- deny.toml 与 workspace 依赖策略：`[sources]` 仅允许 crates.io 钉版、`[bans]` 禁多版本/通配；**不新增 base64/chrono 等任何依赖**（见 §3.2、§3.3）。
- 版本号：crate `version.workspace = true`，0.10.0 发布时随 workspace 提升（当前 0.8.0，0.9.0 未发布；consema-xml 已在 CHANGELOG Unreleased 0.9.0 下）。

## 2. 类型设计要点

### 2.1 PlistValue native model（RFC §6）

核心事实：**共享对象身份必须保留**（二进制对象表一个对象被多处引用 = 一个原生节点多个 owner，§6 最后一段、§5.9），且重复 dict key 保留物理出现顺序与独立身份（§4.4、§5.9）。因此 native model 不能是纯拷贝树，采用 **arena + 引用** 结构：

```rust
/// 与 PortableValue 的 15 类对照（见 2.2）。
pub enum PlistValueNode {
    Dict(PlistDict),
    Array(PlistArray),
    String(PlistString),          // Arc<[u16]> + JavaStringStatus 式状态
    Integer(PlistInteger),        // i64 包装（signed 64-bit exact）
    Real(PlistReal),              // 位精确 + 宽度事实
    Boolean(PlistBoolean),        // true | false
    Date(PlistDate),              // f64 精确 double 秒（2001 纪元），构造时保证有限
    Data(PlistData),              // Arc<[u8]> 精确字节
    Uid(PlistUid),                // u32，binary-only，native 层存在但 XML 侧不可达
}

pub struct PlistDict { entries: Arc<[PlistDictEntry]> }        // 有序、重复保留
pub struct PlistDictEntry { key: PlistKey, value: PlistValueRef }  // 独立身份 + source span
pub struct PlistArray { elements: Arc<[PlistValueRef]> }

/// arena 索引引用；共享身份 = 同一引用多处出现；cycle 在 formation 时被拒绝（§5.11）。
pub struct PlistValueRef(usize);   // 仅对所属 arena 有效，与 Document 同快照绑定
```

`PlistString` 直接照 `consema-properties` 的 Java UTF-16 字符串类型（`core.java-utf16-string@1` 先例，RFC 0011 §7）：持有 `Arc<[u16]>` 精确 code units + `status: PlistStringStatus`（`WellFormedUnicode | UnpairedSurrogate`）。XML 源只产生 well-formed；二进制源可能产生 unpaired surrogate，后者阻止转向 XML 与普通 Unicode 投影（§5.6、§7）。

`PlistReal` 位精确：`{ bits: u64, width: RealWidth }`，`RealWidth = Float64 | Float32`（仅二进制 `0x22` 产生 Float32，§5.5）。相等性按位比较（含 NaN 载荷与 ±0），投影时以 double 值输出。

`PlistDate`：`f64` 精确秒，`2001-01-01T00:00:00Z` 纪元；常量 `PLIST_EPOCH_OFFSET_UNIX: f64 = 978_307_200.0`。构造时拒绝非有限（§5.5 二进制、§4.7 XML 日历验证后必然有限）。

原生节点身份 = `NodeRef`（role `PlistValue`）；dict entry / key / array element 各自有 `NodeRef` 与精确 `Span`（XML 侧指向文本 span；二进制侧指向对应对象/引用块的字节 span）。

### 2.2 与 PortableValue 15 类的关系（RFC §9 投影目标）

| PortableValue 类 | plist 关系 |
|---|---|
| `Null` | plist 无 null（§5.2 排除 null marker）；永不产生 |
| `Boolean` | PlistBoolean 直接映射 |
| `Integer` | PlistInteger 映射（BigInteger::from(i64)，精确） |
| `Decimal` | plist 无小数类型；不产生 |
| `BinaryFloat32` / `BinaryFloat64` | PlistReal 位精确投影（按宽度选择类） |
| `String` | PlistString 在 `WellFormedUnicode` 时映射；`UnpairedSurrogate` 原子失败（§9） |
| `Bytes` | PlistData 直接映射 |
| `Date` / `Time` / `LocalDateTime` / `OffsetDateTime` | **不映射**。plist.value-tree@1 的 date 是独立记录（double 秒 + 固定 2001 纪元常量，§9），不走 PortableValue 日历类型 |
| `Sequence` | PlistArray 直接映射 |
| `Object` | **仅 `plist.projection.require-object@1` 目标**下产生（全 string key、无碰撞或显式 Reject\|First\|Last 策略、无 date/data/UID 叶子，§9）；默认目标用 EntryMapping 或 value-tree 记录 |
| `EntryMapping` | 可作 value-tree 内部形态候选（有序可重复 key 关联） |

### 2.3 两个 Document 的统一性（RFC §7）

**推荐：一个公共 `Document` 枚举，两个变体**——与 RFC 0012（单 Document）不同，plist 的两个 representation 事实集不相交（§7 硬门禁 1），共用结构体必然要维护两套可选字段与"哪个字段合法"的不变量，枚举让不变量成为类型系统的一部分：

```rust
pub enum Document {
    Xml(XmlPlistDocument),
    Binary(BinaryPlistDocument),
}
```

- 公共方法（两变体一致语义，内部派发）：`render()`（字节精确）、`formation_status()`、`snapshot_identity()`、`profile()`、`diagnostics()`、`native_value()`（arena + root 引用）、`project()`、`materialize()`、`commit()`、`format_family()`。
- 变体专属视图（RFC §7 各 representation 只暴露自己的事实）：
  - `as_xml_lossless()` → XML lossless 域（`lossless_structural_index()` + `lossless_syntax_kinds()`，RFC §8.2）；
  - `as_binary_structure()` → 二进制结构域（`BinaryStructuralIndex` + 对象表/偏移表/trailer 事实，RFC §8.3）。
- `XmlPlistDocument` 内部：`SourceSnapshot`、declaration/doctype/root/epilog 事实、`LosslessStructuralIndex`、`Arc<[PlistSyntaxKind]>`、`PlistValue` arena、诊断、limits——照 consema-xml `Document` 字段体例。
- `BinaryPlistDocument` 内部：`SourceSnapshot`（Binary）、`BinaryStructuralIndex`（穷尽 region 覆盖）、`BinaryObjectTable`、`BinaryTrailerFacts`、`PlistValue` arena、诊断、limits。
- 双 representation 转换（§7）：不是内部细节，是**一等变换**——从源 Document 取 native model，以目标 profile + 目标 style 走 materialization，产出 `ConversionReport`（representation-change 报告事件 + 每值 provenance）；不可表达事实（UID/Float32 宽度/unpaired surrogate/分数秒日期/共享身份 → XML）**原子失败**（硬门禁 3）。转换 API 建议放 `document.rs`（`convert_to(other_profile)`），与 facade `conversion.rs` 的跨格式转换区分层级：plist 家族内转换在 crate 内，跨格式仍走 facade projection/materialization 组合。

### 2.4 二进制 parser 内部表示（RFC §5）

```rust
pub struct BinaryTrailerFacts {
    pub sort_version: u8,          // 0x00 | 0x01 均接受（§5.10）
    pub offset_int_size: u8,
    pub object_ref_size: u8,
    pub num_objects: u64,
    pub top_object: u64,
    pub offset_table_offset: u64,
}

/// 对象表按对象表序（非文档序）构建；marker 字节与 span 精确保留。
pub struct BinaryObject {
    pub marker: u8,
    pub span: Span,               // marker 字节起、payload 结束的半开区间
    pub kind: BinaryObjectKind,
}
pub enum BinaryObjectKind {
    False, True,
    Integer { bytes: usize, value: i64 },      // bytes = 1|2|4|8，宽度事实（§5.12）
    Real { width: RealWidth, bits: u64 },
    Date { seconds: f64 },
    Data { payload: Span },
    AsciiString { payload: Span },             // count = 字节数，每字节 < 0x80
    Utf16String { code_units: Span },          // count = code units（2 字节/个）
    Uid { value: u32 },
    Array { refs: Arc<[u64]> },                // objectRefSize 解码后的对象索引
    Dict { keys: Arc<[u64]>, values: Arc<[u64]> },  // key 引用块 + value 引用块
}
```

- 偏移表：`Arc<[u64]>`（每项 = 该对象 marker 的绝对文件偏移，解码自 offsetIntSize 宽 BE 字节）。
- 解析顺序固定：header（8 字节）→ trailer（末 32 字节，全部完整性检查 §5.11 在此先做）→ 偏移表 → 逐对象解码。**所有 `2^(8*size)`、count×ref size、count×payload size、总长度等式、偏移范围检查全部在分配前完成**（硬门禁 4）。
- 对象解码时维护 visited-offset 集合 + 深度计数拒绝交叉环（§5.11）。
- 非 canonical 输入事实（非最小宽度、扩展 size 拼写、重复标量对象）在对象表中按原样保留为事实，仅 canonical materialization 归一（§5.12、§10.2）。
- 共享身份到 native model：arena 构建时同偏移 → 同 `PlistValueRef`；cycle 已在 formation 拒绝，native arena 无环。

## 3. 复用 vs 新写决策

### 3.1 plist.xml parser：新写轻量 parser，不接 consema-xml（推荐）

**决策：不复用 `consema-xml` crate，新写 `parser_xml.rs`，直接消费 `xmlparser 0.13.6` token 流；复用点仅为 consema-document 的 source 层与 xmlparser 依赖。**

理由（对照 RFC 0016 节 0013 §16 第一项已拒绝的方案）：
1. RFC §13 明示 `plist.xml@1` 只共享 RFC 0012 的 **source 层与 xmlparser tokenization**，不共享 xml.1.0-safe 的 Document——plist 是"拥有自己 DOCTYPE、元素与值规则"的独立 Profile（§1）。
2. consema-xml 的 Document 是 namespace-aware 通用 XML 树（XmlElement/XmlAttribute/NamespaceBinding/Doctype 内部子集等事实），plist 需要的是**带类型文法（typed grammar）的窄子集**：无 namespace、唯一 attribute `version`、固定 DOCTYPE 标识、`<key>` 专有位置。从通用树映射会强迫"解析全部再丢弃"，恢复语义、diagnostics（`plist.parse.*@1`）、lossless kind 集（§8.2 的 46 种）全部要重做。
3. 复用路径的唯一真实收益（XML 语法正确性）由 xmlparser 直接提供；plist 专属规则（DOCTYPE 精确标识、元素/属性强制、值文法、base64、dict 关联规则、恢复边界）无论走哪条路都必须 Consema 自写（§13 契约）。
4. 两个 parser 的恢复边界不同：xml.1.0-safe 按通用 markup 边界恢复；plist 按"value 元素文法 + plist 完整性"恢复（§3、§4.4）。共享 consema-xml 会引入错误的恢复授权。

xmlparser token 映射要点：`Token::StartTag/EndTag/Text/Cdata/EmptyElementTag/Comment/Pi/Dtd`。plist 侧在 Dtd token 上做精确标识匹配（§4.1：`<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">`，token 间空白灵活、五个要素精确、无 internal subset）；文本处理只认五个预定义实体 + 十进制/十六进制字符引用（§4.9），不做任何实体声明收集——内部 subset 存在即 Recovered。line-end 归一（CR/CRLF→LF）在 native 文本上做，raw 字节保留在 piece 中（RFC 0012 §2 语义，CR 差分列入 §13 排除清单）。

### 3.2 base64：自写，不加依赖（推荐）

RFC §4.8 的语法是"标准字母表 + 字符间允许 ASCII 空白 + 精确 padding"，与现成 crate（base64 等）的宽松/严格语义都不同：现成 crate 不提供"字符间空白跳过 + 精确 padding 强制"这一组合，且项目依赖策略（deny.toml `[sources]` 仅 crates.io 钉版、workspace 无新依赖先例、consema-xml 全程只加 xmlparser）不鼓励引入。自写约 200 行 + 测试：严格解码（拒绝非字母表字符、拒绝缺失/多余 padding）、规范编码（标准字母表 + `=` padding + 76 字符换行、缩进计入预算 `76 - 8 * indent`，§4.8、§10.1）。解码前的长度/上限检查照 §12 体例。

### 3.3 日期解析：自写严格子集，不加 chrono（推荐）

RFC §4.7 文法 `[-]YYYY-MM-DDTHH:MM:SSZ`（整秒、无小数、无偏移）+ 日历校验（月 1-12、日按年月、时 0-23、分秒 0-59）。约 150 行：字段解析 + 格里高利日历校验（闰年规则照 consema-core `Date::new` 的 magnitude_remainder 先例，负年份天文编号）。转 double 秒：以 2001 纪元为原点做自实现的秒差计算（days_from_civil 式算法，需测试负年份与纪元前后边界）。chrono 的 proleptic Gregorian 语义与 RFC 的负年需求不完全一致且是重依赖，不引入。

### 3.4 其余新写点（无复用歧义）

- **real 文本文法**（§4.6）：`nan`/`inf`/`+inf`/`-inf`/`infinity` 系大小写不敏感 + 标准十进制文法，解析到位精确 double；Rust 无现成解析器符合"特殊拼写大小写不敏感"要求，自写约 120 行。
- **canonical real 渲染**（§10.1）：`f64` 的 Rust `Display` 已是 shortest-round-trip；自写部分是把 `inf`/`-inf`/`NaN` 映射到 plist 拼写（Apple 写法为 `nan`、`inf`、`-inf`——**实现阶段以 `plutil -convert xml1` 实测复核，见 §7 风险 R-4**）。
- **二进制宽度解码**（§5.3）：自写 1/2/4/8 字节 BE 读取（1/2/4 无符号、8 有符号），无现成 crate 需求。

## 4. 里程碑拆分

10 个里程碑，按依赖排序。`M` 为必须串行（前驱产物直接输入），`‖` 为可并行（文件域隔离，互不 import 对方中间产物；仅依赖共享的 consema-document/consema-core 与已完成里程碑的公共 API）。

| # | 里程碑 | 依赖 | 并行性 | 预估行数 | 交付物 |
|---|---|---|---|---|---|
| M1 | crate 骨架 + native value model | — | 串行起点 | 1500-1900 | Cargo.toml、lib.rs（profile/encoding/limits/parse 入口骨架）、native.rs 全量、NodeRole 增补 |
| M2 | plist.xml parser | M1 | ‖ 与 M3 并行 | 2300-2800 | parser_xml.rs（formation + PlistSyntaxKind + 文本标量/base64 编解码，scalar/base64 并入）、XML 向量初稿 |
| M3 | plist.binary parser | M1 | ‖ 与 M2 并行 | 2000-2500 | parser_binary.rs（formation + 二进制结构域事实，binary_structure 并入）、二进制向量初稿 |
| M4 | Document 统一层 + 双 representation round-trip | M2、M3 | 串行合并 | 1000-1400 | document.rs、native 提取、convert_to、字节精确 round-trip 门禁 |
| M5 | 查询 ×3 域 | M4 | ‖ 与 M6/M7/M8 并行 | 1400-1700 | query.rs（native/lossless/binary-structure 三域） |
| M6 | 投影 ×2 目标 | M4 | ‖ 与 M5/M7/M8 并行 | 1000-1300 | projection.rs（value-tree + require-object + IncludeUid） |
| M7 | 物化 ×2 style | M4 | ‖ 与 M5/M6/M8 并行 | 1400-1700 | materialization.rs（xml-canonical + binary-canonical + 重解析闭包） |
| M8 | 编辑 ×6 ×2 表示 | M4 | ‖ 与 M5/M6/M7 并行 | 1700-2100 | edit.rs、operation_registry.rs |
| M9 | conformance 向量 + runner + hardening | M2-M8 全部 | 串行收口 | 2800-3600 | `conformance/vectors/plist-v1.json`、`crates/consema-conformance/src/plist_v1.rs`、`tests/plist_hardening.rs`、`tests/plist_fixtures.rs`、`conformance/fixtures/plist/` |
| M10 | 差分 oracles + facade 集成 + 发布文档 | M2-M8（脚本可在 M2 后先搭）、M9 | 与 M9 可并行（不同文件域） | 1200-1600 + 文档 | `scripts/run-plist-macos-oracle.ps1`、`scripts/oracles/PropertyListOracle.swift`、`conformance/oracles/plist-macos-v1/`、facade 导出、CHANGELOG/IMPLEMENTATION/路线图更新、BENCHMARKS |

总规模估计：crate 源码 11k-15k 行（对照 consema-xml 13k），conformance 资产 4k-5k 行，脚本/文档另计。实施节奏（两个 agent 并行示例）：M1 → [M2 ‖ M3] → M4 → [M5 ‖ M6 ‖ M7 ‖ M8] → [M9 ‖ M10]。

### M1 — crate 骨架 + native value model（串行起点）

范围：
- workspace `Cargo.toml` members 增加 `crates/consema-plist`；`crates/consema-document` 的 `NodeRole` 增加 1.3 节五个角色。
- `lib.rs`：`PlistProfile { XmlV1, BinaryV1 }`（`id()` 返回 `plist.xml`/`plist.binary`，与 ini 三 profile 枚举同体例）、`PlistEncodingSelection { ProfileDefault, Explicit(SourceEncoding) }`（XML 侧；二进制侧 profile 固定 Binary，同 enum 但 BinaryV1 忽略）、`PlistParseLimits`（common + 对象数/嵌套/字典项/重复组/字符串 code units/data 字节/UID 数/扩展 size 整数及其量级/offsetIntSize 与 objectRefSize 宽度/偏移表字节/语法 piece 与诊断/二进制对象偏移 trailer 事实/转换节点数与报告事件，§12 逐项落字段）、`parse(source, profile, encoding, limits)` 入口（两个 parser 的薄分发，M2/M3 前先占位）。
- `native.rs`：2.1 节全量类型 + 构造校验（i64 精确、date 有限、UID ≤ 2^32-1）+ 相等性/哈希（位精确 real）+ arena builder（同偏移 → 同引用、拒绝环、上限检查）+ 类型测试（含共享身份、重复 key、unpaired surrogate 状态机）。

验收门禁：
- `cargo test -p consema-plist`（本里程碑测试全绿）；`cargo clippy -p consema-plist --all-targets -- -D warnings`；`cargo fmt --check`；missing_docs 零告警（workspace lint）。
- 类型测试覆盖：每个 PlistValue 类型构造/相等/哈希；共享身份双 owner；重复 key 保序；`PlistString` 的 well-formed/unpaired 两态；real 位精确（NaN 载荷、±0 区分）。
- `cargo check --workspace`（NodeRole 增补不破坏既有 crate）。

### M2 — plist.xml parser（‖ 与 M3 并行）

范围（RFC §4 全节）：
- 源契约：走 `SourceSnapshot::from_raw` + RFC 0012 §2 规则（UTF-8 可选 BOM；UTF-16LE/BE 必须 BOM；无 BOM 缺省 UTF-8；UTF-16 无 BOM、UTF-32、Latin-1 等显式排除）。
- prolog/DOCTYPE：declaration 规则（version 恰 `1.0`、可选 encoding/standalone、顺序固定）；DOCTYPE 精确 Apple 标识匹配（§4.1），internal subset/参数实体 → Recovered。
- 根元素 `<plist version="1.0">` 精确校验（§4.2）；值元素文法（§4.3-4.4）；`<key>` 位置文法（值元素出现在 key 位置 / key 后缺值 / `</dict>` 时 key 挂起 → Recovered）。
- 标量文法与 base64 编解码在 parser_xml.rs 内实现（原计划 scalar.rs/base64.rs 并入，§4.5-4.8）；文本/CDATA/预定义实体/字符引用与 line-end 归一（§4.9）；尾随内容（§4.10）。
- parser_xml.rs：§8.2 的 46 种 `PlistSyntaxKind` + 穷尽 piece 装配（根开标签按 `PlistOpen`/`Whitespace`/`PlistVersionName`/`PlistVersionValue`/`PlistOpen` 五片分区，§8.2 明示）；`ErrorRegion` 收容。
- 恢复语义：三路 outcome；Recovered 保留已证明 piece 与 value 元素，绝不虚构闭合标签/count/值（§3）。
- diagnostics：`plist.parse.*@1`、`plist.limit.*@1` 常量注册（§12 命名模式），不进入 consema-protocol 核心注册表。

验收门禁：
- 测试矩阵覆盖 §4 每一条规则：DOCTYPE 变体（精确/空白灵活/错误名/内子集/外子集）、根属性、每种值元素（含 `<true/>`/`<false/>` 显式闭合、空元素合法表 §4.3）、重复 key 保序、integer 十进制/十六进制/符号后空白/前导零/越界 Recovered、real 特殊拼写、date 文法与日历边界（含闰年、负年份）、base64 空白/精确 padding、CDATA/引用、尾随内容、每种恢复路径。
- **每类测试断言穷尽覆盖**（照 consema-xml/ini 的 `assert_exact_coverage` 体例：pieces 无空洞无重叠、首尾相接、kind 数组与 pieces 平行）。
- 字节精确 round-trip：Complete 文档 `render() == 输入字节`。
- `cargo test -p consema-plist`、clippy、fmt 全绿。

### M3 — plist.binary parser（‖ 与 M2 并行）

范围（RFC §5 全节）：
- 源契约：`EncodingRequest::binary()`；最小 42 字节前置检查（§2.2）。
- header（§5.1：`bplist00` 精确，其他版本 Recovered）；trailer 先行解析与 §5.11 全量完整性检查（`numObjects ≥ 1`、`topObject < numObjects`、`offsetTableOffset ∈ [9, datalen-32)`、`offsetIntSize/objectRefSize ≥ 1`、宽度 < 8 时的 `2^(8*size)` 上界、末 5 字节零、总长度等式、每项偏移 ∈ `[8, offsetTableOffset)`、top object 偏移同界）；偏移表解码。
- 对象表逐对象解码：全部 admitted marker（§5.2 表）+ 全部 v1 排除 marker 的稳定 Recovered diagnostic（0x00/0x0C/0x0D/0x0E/0x0F/0x14/0x20/0x21/0x70/0xB0/0xC0/0x0A/0x0B/0x90-0x9F/0xE0-0xFF 逐项列常量表）；扩展 size（§5.4，count 对象 marker 必须 0x10-0x13 无符号）；整数宽度/符号规则（§5.3：1/2/4 无符号、8 有符号、非最小宽度合法且记录）；`0x22` Float32 宽度事实、`0x23` double；`0x33` 有限校验；ASCII 字符串高位置位字节 Recovered（§5.6 明确差分）；UTF-16BE count 按 code units、unpaired surrogate 精确保留；data 原样字节；UID `n+1` 字节 ≤ 2^32-1；array/dict 引用解码与越界拒绝；dict key 必须 string（§5.9 差分）。
- 环检测：visited-offset 集合 + 深度上限（§5.11）。
- parser_binary.rs：`BinaryTrailerFacts`、`BinaryObject` 等公共类型 + 二进制结构域事实装配（region kind 字符串固定常量，原计划 binary_structure.rs 并入）。
- 恢复语义：三路 outcome；Recovered 保留已通过检查的对象/偏移表项/trailer 字段（§3）。
- 全部尺寸运算 checked（`usize::checked_mul/checked_add`、`2_u128.pow` 预检），**在分配前**完成（硬门禁 4）。

验收门禁：
- 测试矩阵覆盖 §5 每条：header 版本矩阵、每个 marker 正例、排除 marker 全表 Recovered + 稳定 code、扩展 size（含 count 对象 marker 错误）、整数宽度矩阵（1/2/4 无符号 8 有符号、负数 8 字节、非最小宽度保留）、Float32 宽度、分数秒日期、非有限日期 Recovered、ASCII/UTF-16 字符串（含 unpaired surrogate）、UID 边界（2^32-1 通过、2^32 Recovered）、共享引用（多容器引用同一对象）、环（交叉引用 Recovered）、trailer/offset 完整性逐条负例、非 canonical 宽度事实保留。
- 字节精确 round-trip；region 穷尽覆盖断言；`render() == 输入字节`（二进制文档的默认渲染，硬门禁 1）。
- 全部负例以十六进制夹具编写（向量后续直接复用）。

### M4 — Document 统一层 + 双 representation round-trip（串行合并）

范围：
- `document.rs`：2.3 节 `Document` 枚举、两个变体文档结构、公共方法派发、变体专属视图。
- native 提取统一：两个 parser 的 formation 结果（syntax/结构事实 + arena）组装为公共 `Document`；`native_value()` 提供 arena + root。
- 双 representation 转换：`convert_to`（native 提取 → 目标 profile 物化 → 报告事件；§7 表达力矩阵、原子失败）。
- 跨表示 round-trip 门禁：XML→binary→XML 与 binary→XML→binary 的 native-model 相等 + 每步 representation-change 报告（§7 最后一段）。

验收门禁：
- round-trip 测试：可表达矩阵全对（含重复 key、共享身份、非最小宽度经 canonical 归一后 native 相等）、不可表达矩阵原子失败（UID→XML、Float32 宽度→XML 无策略时、unpaired surrogate→XML、分数秒日期→XML 无 TruncateWithReport）、报告事件断言。
- 快照绑定：跨文档 NodeRef 拒绝（WrongSnapshot）；Recovered 文档可查询但 project/materialize/commit 拒绝（§3）。
- 既有 crate 回归（NodeRole 增补后 workspace 全测试）。

### M5 — 查询 ×3 域（‖ 并行）

范围（RFC §8）：三个 `QueryDomain` 注册 + 执行器（照 consema-xml query.rs 骨架：`QueryDefinition.validate().bind() → execute_*_query/_cursor`）：
- `plist.native-semantic-query@1`：15 个操作符（§8.1 列表逐条，`plist.document-root@1` 至 `plist.value-as-uid@1`）；类型访问器先验证类型再返回，类型不匹配是查询失败而非 null/转换（§8.1）；`plist.dict-key-equals@1` 精确 Unicode 匹配不折叠大小写；`plist.duplicate-key-group@1` 展开全部同 key 关联。
- `plist.lossless-syntax-query@1`（仅 XML 变体）：46 种 kind 过滤 + 解码文本过滤（照 xml_v1.rs 的 UTF-16 感知 span 解码先例）。
- `plist.binary-structure-query@1`（仅 Binary 变体）：6 个操作符（§8.3），返回 marker/span/offset/引用/trailer 事实，不发明文本 trivia。
- 域/操作符/角色/profile 校验先于首个结果（§8.3）。

验收门禁：三域各覆盖 §8 操作符清单的向量（M9 前以 crate 内测试先行）；类型不匹配失败断言；结果保序；cursor/limit/cancellation 沿用公共契约。

### M6 — 投影 ×2 目标（‖ 并行）

范围（RFC §9）：`plist.projection.value-tree@1`（默认精确目标：root 值 + 有序 dict 关联 + 有序数组 + 类型化叶子；date 以 double 秒 + 2001 纪元常量记录；UID 仅 `IncludeUid` 策略下进类型化成员，绝不伪装成 integer；unpaired surrogate 原子失败）+ `plist.projection.require-object@1`（string key、值仅 string/integer/real/boolean、无碰撞或 `Reject | First | Last` 版本化策略；date/data/UID 叶子带诊断失败；授权折叠为 `Transformed` + 每丢弃关联一条报告事件 + 保留/丢弃 provenance）。provenance 区分 dict 关联/key/值/二进制共享引用 owner/XML 文本与引用片段/转换表示变化（§9 末段）。投影不排序 key、不格式化日期、不发明 JSON 惯例。

验收门禁：两目标正负例矩阵；IncludeUid 策略开关；碰撞策略 Reject/First/Last 三态 + 报告事件数与内容断言；provenance 关联计数断言（照 xml_v1.rs `run_projection` 体例）。

### M7 — 物化 ×2 style（‖ 并行）

范围（RFC §10）：
- `plist.xml-canonical@1`：UTF-8 无 BOM、Apple 头拼写精确（`<?xml version="1.0" encoding="UTF-8"?>` + DOCTYPE 行 + `<plist version="1.0">`）、四空格缩进、LF、`</plist>` 尾换行；key 保输入序（§10.1 差分）；`& < >` 与 XML 1.0 非法字符转义；base64 76 字符换行缩进计入预算；integer 十进制；real shortest-round-trip + 特殊拼写映射；date 整秒，分数秒需 `TruncateWithReport` 否则整体失败。
- `plist.binary-canonical@1`：最小整数宽度（负数恒 8 字节）、Float32 宽度保留、date 8 字节 double、标量对象首次出现去重（容器恒新写）、UID 最小宽度、引用/偏移表最小宽度满足 §5.11 充分性检查、sortVersion 0x00 + 零未用字节。
- 公共契约：输入先全量验证再分配；编码后**重解析精确生成字节**并与承诺 native model 逐节点比较；失败不返回目标 Document/partial 字节/partial provenance（§10.3）。

验收门禁：两 style 的 golden byte 测试（含缩进、换行、base64 折行 76 字符预算、去重、最小宽度选择）；重解析闭包失败注入测试（破坏生成器产物必须被闭包抓住）；TruncateWithReport 报告事件断言；输入限制/输出限制/节点数/算术限制。

### M8 — 编辑 ×6 ×2 表示（‖ 并行）

范围（RFC §11）：六个操作（`plist.edit.set-value@1`、`insert-dict-entry@1`、`remove-dict-entry@1`、`rename-dict-key@1`、`insert-array-element@1`、`remove-array-element@1`）独立按 profile 类型化：
- XML 侧：照 RFC 0012 编辑体例——只替换操作自有 span 内文本/元素、未触及字节全部保留、重解析目标并验证 plist 语义；六操作 × `AssociationPlacement`。
- Binary 侧：set-value 重写目标对象 marker+payload；insert/remove 重写所属容器引用块 + 尺寸变化时的偏移表与 trailer；共享引用保留（删除 dict entry 只删该 entry 引用，仍被他处引用的对象不动）；cycle 拒绝；全部 offset/size/引用算术输出前检查（硬门禁 4）。
- 值以类型化 native 事实提供（integer/real/boolean/date/data/string/UID），绝不以 raw markup/raw bytes。
- 冲突校验全表（§11 末段：错误 profile/角色/快照、缺失或重复目标、stale anchor、重叠源所有权、非 string key、向 XML Document 插 UID、不可表示值、限制失败、重解析失败）。成功返回新 Document + `ChangeSet` + `UntouchedByteProof` + 可重放 `SourcePatch`；失败返回无。
- `operation_registry.rs`（in-flight）：`format_operation_registry()` 注册六操作 × 两 profile 的描述符（照 consema-xml 125 行体例）。截至本文修订，该文件尚未出现在 crate 中（crate 实收 9 个文件），由并行 agent 添加中；`edit.rs` 的六个操作本身已实现并随 M9 向量覆盖。

验收门禁：每操作正例（XML 文本渲染精确 + binary 字节精确 + 两表示下 native 结果一致）；未触及字节证明（`UntouchedByteProof` 区域与 SourcePatch 重放：patch 应用到旧快照 → 字节等于新快照渲染）；冲突矩阵每条负例；共享引用保留断言；dry-run/commit 等价（§14 要求）。

### M9 — conformance 向量 + runner + hardening（串行收口）

范围（§14 全节）：
- `conformance/vectors/plist-v1.json`：suite id `consema.plist.conformance@1`（见 §6.1）；case 带 `input.profile`（`plist.xml@1`/`plist.binary@1`）与 capability（实收六类：`plist.xml-formation@1`、`plist.binary-formation@1`、`plist.query@1`、`plist.projection@1`、`plist.materialization@1`、`plist.edit@1`；原计划九类中的 conversion/limit 向量由并行 agent 添加中）；二进制输入以 `input.hex` 承载（照 consema-conformance 现有 `decode_hex` 先例）。覆盖 §14 清单：XML DOCTYPE 变体/prolog-epilog/空与嵌套值/全元素类型/重复 key/整数两种文法与边界/real 特殊值/date 文法与日历边缘/base64 padding 与空白/CDATA 与引用/尾随内容/每种恢复；二进制 header 版本/每个 admitted marker/扩展 size/整数宽度矩阵与符号规则/float32-float64/分数秒日期/两种字符串含 unpaired surrogate/UID 尺寸与边界/数组/dict/重复 key/共享引用/环/每个 trailer 与 offset 完整性检查/非 canonical 宽度事实；原生查询/投影/两种 canonical 物化重解析闭包/六编辑 dry-run-commit 等价/untouched proof/patch replay；转换向量（每个可表达与不可表达事实 + representation-change 报告）；截断/变异/嵌套/count/引用/offset/算术对抗；生产夹具（macOS preference plist、Info.plist 形状、NSKeyedArchiver 含 UID 样本，license 钉版无密钥）。
- `crates/consema-conformance/src/plist_v1.rs`：照 xml_v1.rs 全模式（SUITE 常量、`PLIST_V1_VECTORS_JSON` include_str、`run_plist_v1`/`run_plist_v1_json`、按 capability 分派 run_case、xml-formation/binary-formation/query/projection/materialization/edit 六个处理器、materialization_failure_code 映射、suite id 检查测试）。
- `tests/plist_hardening.rs`：照 xml_hardening.rs 体例（mutation/truncation/nesting/count/reference/offset/算术对抗 + 不 panic + 穷尽覆盖闭包断言）。
- `tests/plist_fixtures.rs`：生产夹具投影→物化→重解析不动点门禁（照 xml_fixtures.rs）。
- `conformance/fixtures/plist/`：`xml/` 与 `binary/` 两子目录 + README（来源/许可证钉版）。

验收门禁：`cargo test -p consema-conformance` 全套全绿（对齐既有"15 套 suite 366/366"体例——0.10.0 时为 16 套 + plist 新增案例数）；向量数据驱动（改一个期望必须失败，照 lib.rs tests 体例）；suite id 检查测试。

### M10 — 差分 oracles + facade 集成 + 发布文档（与 M9 可并行）

范围：
- `scripts/oracles/PropertyListOracle.swift`：钉版 Swift 驱动，调用 Foundation `PropertyListSerialization.data(from:format:)` 与 `propertyList(from:)` 双向（§13）。
- `scripts/run-plist-macos-oracle.ps1`：照 run-python-configparser-oracle.ps1 模式——pin macOS 版本/工具链版本与 digest/plutil 调用旗标/输入 digest/期望输出/排除清单；运行 `plutil -lint`、`plutil -convert xml1|binary1`（每个 fixture 双向）、`plutil -p` 值比较 + Swift 驱动；manifest 校验（suite `consema.plist.macos-differential@1`）。macOS runner 专属（CI 上标记非 Windows 可跳过）。
- `scripts/run-plistlib-oracle.ps1`：次要对齐（钉版 CPython plistlib；如实注记（2026-08-14 波 2）：仅 Windows 10.0.26200.0 精确 build 可执行——Linux/macOS 无法运行 windows-amd64 embeddable zip，hosted Windows 10.0.26100 亦不匹配，现按 documented skip exit 3 处理；libplist 可选），明确"非语义权威"（§13）。
- `conformance/oracles/plist-macos-v1/manifest.json`：§13 的排除清单逐条落表（UTF-32 BOM 与未知声明编码、重复 key 保留 vs last-wins、严格 base64 与 version 属性、严格 DOCTYPE、尾随内容拒绝、日历校验、64 位整数范围、bplist01 拒绝、16 字节整数与 null marker 拒绝、非有限日期拒绝、ASCII 高位置位字节拒绝、非 string 二进制 dict key、含 CR 字符串、更严偏移表项界、Apple writer key 排序）。
- facade（`crates/consema/src/`）：`pub use consema_plist as plist`；`DocumentInner::Plist(Box<plist::Document>)` + `parse_plist`/`as_plist`；`FormatMismatch::Plist`；conversion.rs 增加 `convert_plist`（跨格式经 projection/materialization 组合，照 convert_ini 体例）。facade 测试照既有体例（parse_plist 两 profile、render、as_* 误用拒绝）。
- 文档：CHANGELOG 0.10.0 条目、`docs/IMPLEMENTATION.md` 新增 plist 章节（crate 边界表更新）、路线图 §14.9 落实状态更新、`docs/BENCHMARKS-0.10.0.md`。

验收门禁：facade 测试全绿；`cargo test --workspace` 全绿；差分 manifest 在钉版 macOS runner 上通过（或记录允许跳过路径）；文档评审。发布门禁沿用仓库体例：conformance 全绿 + hardening + fixtures + benchmarks + `scripts/verify-package-archives.ps1` 对 13 个可发布 crate 全量通过。

## 5. 多 agent 并行化建议（文件域划分）

每个并行里程碑派发一个 agent，文件域互不重叠，仅共享已完成里程碑的公共 API：

| Agent | 文件域 | 里程碑 | 前置（公共 API 输入） |
|---|---|---|---|
| A | `crates/consema-plist/src/native.rs` + `lib.rs` 骨架 | M1 | 无（最先） |
| B | `parser_xml.rs` | M2 | M1 的 value/limits API |
| C | `parser_binary.rs` | M3 | M1 的 value/limits API |
| D | `document.rs`（M4 合并） | M4 | M2 + M3 的 formation 产物类型 |
| E | `query.rs` | M5 | M4 的 Document 公共 API |
| F | `projection.rs` | M6 | M4 的 Document 公共 API |
| G | `materialization.rs` | M7 | M4 的 Document 公共 API + M2/M3 parser（重解析闭包） |
| H | `edit.rs` + `operation_registry.rs`（in-flight） | M8 | M4 的 Document 公共 API |
| I | 向量 JSON + `plist_v1.rs` + 两个测试文件 + fixtures | M9 | M2-M8 全部公共 API |
| J | 脚本 + oracle manifest + facade + 文档 | M10 | M2-M8 公共 API（脚本只依赖夹具生成，可与 B/C 同期启动） |

约束：
- E/F/G/H 四个 agent 并行时，`document.rs`、`native.rs`、`lib.rs` 为只读共享域；任何 API 调整须先经过 M4 稳定（M4 的验收门禁应包含"公共 API 冻结"检查）。
- 向量 JSON 与 runner 必须同批（runner 是向量的唯一权威执行者，照 xml_v1.rs "vector data drives results" 体例）。
- 差分脚本的 fixture 集应取自 M9 的 fixtures 目录（先写脚本框架 + manifest，再在 M9 完成后回填 fixture digest——这是 M10 与 M9 并行的唯一交接点）。

## 6. conformance 集成细节

### 6.1 向量套件命名

`consema.plist.conformance@1`（对齐 `consema.ini.conformance@1` / `consema.java-properties.conformance@1` 家族体例；json-family 用 `consema.json-family.conformance@2` 的 family 拼写也成立，但 plist 是单家族双 profile，`plist` 后缀 + 文件内 `profiles` 数组更贴合 ini 先例）：

```json
{
  "suite": "consema.plist.conformance@1",
  "profiles": ["plist.xml@1", "plist.binary@1"],
  "cases": [ ... ]
}
```

每 case：`id`（稳定）、`capability`（实收六类：`plist.xml-formation@1`、`plist.binary-formation@1`、`plist.query@1`、`plist.projection@1`、`plist.materialization@1`、`plist.edit@1`——formation 按 profile 分列，query 域三合一，conversion/limit 向量由并行 agent 添加中）、`input`（`profile`、`source` 文本或 `hex` 字节、`encoding`（utf16le-bom 先例）、limits 覆盖字段）、`expected`（status/render/render_hex/diagnostic/matches/failure/records）。

### 6.2 runner 模式

`crates/consema-conformance/src/plist_v1.rs` 完全对齐 `xml_v1.rs`：
- SUITE 常量 + include_str 嵌入；`run_plist_v1()` / `run_plist_v1_json()`；suite 标识校验；case id 去重。
- `capability` 分派：xml-formation/binary-formation/query/projection/materialization/edit 各一个处理器函数（与 `plist-v1.json` 现存六类 capability 一一对应，见 `plist_v1.rs` 的 `run_case` 六臂分派）；conversion/limit 处理器随并行 agent 补充的向量一并落地。
- 二进制输入 `hex` 解码（复用 lib.rs 的 `decode_hex` 模式）；`render_hex` 期望比对（二进制渲染非 UTF-8）。
- limit case 在 runner 内分支（照 xml_v1.rs `run_limit` 的注释扩展点：formation 类委托 + 非 formation 类在此扩展）。
- 测试：全量通过（`report.passed.len()` 断言，与向量同批更新）、suite id 篡改失败、输入篡改失败、UTF-16 syntax-query 文本断言。

### 6.3 差分脚本

- `scripts/run-plist-macos-oracle.ps1`：PowerShell 包装（对齐仓库既有 oracle 脚本：manifest 校验 → runtime 事实校验 → 逐 fixture 执行 → TSV 报告 → 退出码）。钉版 macOS 版本 + Xcode/Swift toolchain digest + plutil 版本；`plutil -lint`、`plutil -convert xml1|binary1`（每个 fixture 双向）、`plutil -p`、Swift 驱动双向序列化。
- Swift 驱动与 manifest 放 `conformance/oracles/plist-macos-v1/`；排除清单按 §13 逐条落表并**不允许 untracked allowlist**。
- 次要对齐脚本 `scripts/run-plistlib-oracle.ps1`（钉版 CPython plistlib），仅结构交叉检查。
- 差分失败的处理政策：不得改 Consema 行为匹配（须走 RFC 或记录排除），照 §13 末段。

## 7. 风险清单与实现阶段复核点

| # | 风险/复核点 | 说明与缓解 | 复核时机 |
|---|---|---|---|
| R-1 | Apple writer 的 SInt128 写入 | RFC §5.2 将 `0x14`（16 字节整数）列为 v1 排除，但 Apple writer 对超 64 位量会写 16 字节——夹具与差分向量**不得包含**此类输入，且 §13 排除清单需明示 64 位范围；若 `plutil -convert binary1` 对超大值输出 `0x14`，差分 fixture 生成阶段必须剔除或记录 | M3、M10 差分 fixture 生成 |
| R-2 | plistlib 与 Foundation 三处分歧（§5 前言） | UID 上界、`0x0F` fill 字节、扩展 size marker 三处 plistlib 与 Foundation 不一致——RFC 以 Foundation 为准，plistlib 仅次要对齐，其三处分歧不进差分清单但需在 runner 文档注明 | M3、M10 |
| R-3 | `0x0F` fill 字节的读取宽容 | Foundation reader 容忍 fill 字节而 RFC 排除（Recovered）；写入复现时需确认 plutil 输出不含 `0x0F` | M3 |
| R-4 | canonical real 特殊拼写 | RFC §10.1 要求 shortest-round-trip，但 nan/inf 的精确拼写（`nan`/`inf`/`-inf` vs `NaN`/`Infinity`）需以钉版 `plutil -convert xml1` 实测定格；Rust `Display` 输出 `NaN`/`inf`/`-inf`，需映射层 | M7 前以 plutil 探针、M10 差分钉版 |
| R-5 | Apple writer 的 base64 折行预算 | §4.8：折行点 `76 - 8*indent`（缩进计入预算）——实现与差分 fixture 都按此公式；Apple 源码 MAXLINELEN 语义需在实现时复核 | M2、M7 |
| R-6 | UID 语义测试策略 | UID 是值不是解析目标：测试覆盖 2^32-1 边界、`n+1` 字节宽度（0x80-0x8F 全宽度）、引用保留、向 XML 转换原子失败、NSKeyedArchiver 夹具只验证 UID 值保留**绝不**重建 `$objects`/class 表（§15） | M3、M9、M10 |
| R-7 | 负年份日期 | §4.7 允许 `-YYYY`，日历校验需用天文年份编号（照 consema-core `Date` 的 magnitude_remainder 闰年先例）；double 秒换算的 days_from_civil 负年路径必须有专项测试 | M2（parser_xml.rs） |
| R-8 | unpaired surrogate 全链路 | 二进制解析保留 → native 两态 → 查询/投影（普通投影原子失败）/XML 转换（原子失败）/binary canonical 物化（精确重写 2 字节/unit）→ 重解析闭包相等；任何环节不得替换/丢弃 | M2-M9 全链路、M9 专项向量 |
| R-9 | 非有限日期 vs 非有限 real 不对称 | real 的 nan/inf 是 admitted 值（§4.6、§5.5），date 的非有限是 Recovered（§5.5）——两处校验不可共用同一"接受非有限"路径 | M2、M3 |
| R-10 | `sortVersion` 双值 | 0x00（Apple writer）/0x01（第三方 writer）都接受、canonical 写 0x00（§5.10）；差分 fixture 需含一个 0x01 样例确认 plutil 行为 | M3、M10 |
| R-11 | 偏移表项界更严差分 | RFC 要求每项 ∈ `[8, offsetTableOffset)`，Foundation 只查 `off < offsetTableOffset`——实现按 RFC；差分排除清单已列，但 fixture 生成器不能依赖 Foundation 行为反推 | M3 |
| R-12 | 共享身份在 canonical 物化后的 reparse 等价 | 去重后共享身份必须仍是一对多引用；闭包比较需在"native 语义"层（引用图等价）而非"对象数"层（去重改变了表） | M7 |
| R-13 | 42 字节最小输入与空文档 | `numObjects ≥ 1` 且最小 42 字节——空 dict/array 的最小合法文件是多少需要实测（Apple 对 `<dict/>` 的 binary 输出）并进向量 | M3、M9 |
| R-14 | 编辑后的 SourcePatch 重放与二进制字节保持 | XML 侧沿用 RFC 0012 patch 语义；binary 侧 patch 是整对象/引用块替换——UntouchedByteProof 区域断言需覆盖"未触及引用块字节逐字节相同" | M8 |
| R-15 | macOS runner 可用性 | 差分门禁依赖钉版 macOS runner；Windows CI 上脚本应显式跳过并在 manifest 记录允许跳过路径（照仓库 oracle 脚本的 `windows_build` 先例精神） | M10 |
| R-16 | 查询操作符与 RFC 0011 注册边界 | plist 查询 wire 契约不属 v6（RFC 头注）：`core.plist-*` 注册留给后续 semantic-model 版本；实现只注册 `QueryDomain` 与操作符字符串，不触碰 consema-protocol 注册表 | M5、M10 |

## 8. 验收门禁总表（对照仓库既有体例）

| 门禁 | 体例来源 | 适用里程碑 |
|---|---|---|
| `cargo test -p consema-plist` + clippy `-D warnings` + fmt + missing_docs | consema-xml 开发门禁 | 每个里程碑 |
| `cargo test --workspace` | 发布门禁 | M4 起每个里程碑 |
| `assert_exact_coverage` 穷尽覆盖断言 | ini/xml lib.rs 与 tests 体例 | M2、M3 |
| 字节精确 `render() == source` | 全格式不变量（IMPLEMENTATION.md §2） | M2、M3、M4 |
| 重解析闭包（materialization 字节 → 重解析 → native 相等） | xml materialization 先例（RFC 0012 §10、§14） | M7 |
| 向量数据驱动（改期望必失败）+ suite id 检查 | conformance lib.rs/xml_v1.rs tests | M9 |
| hardening 不 panic + 覆盖闭包 | tests/xml_hardening.rs | M9 |
| 生产夹具投影→物化→重解析不动点 | tests/xml_fixtures.rs | M9 |
| 差分 manifest 钉版 + 排除清单逐条落表 | scripts/run-*-oracle.ps1 + conformance/oracles/*/manifest.json | M10 |
| 全套 suite 计数（0.10.0：16 套全绿） | CHANGELOG/RELEASE 记录体例 | M10 |
| 打包/解包验证（13 个可发布 crate） | scripts/verify-package-archives.ps1 | M10 |
| 性能基线文档 BENCHMARKS-0.10.0.md | docs/BENCHMARKS-0.8.0.md 等 | M10 |
