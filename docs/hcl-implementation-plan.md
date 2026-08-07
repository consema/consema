# Consema 0.11.0 HCL family 实现计划

- 对应规范：`docs/rfcs/0014-hcl-family-profiles-v1.md`（16 节，`hcl.native@1` 与 `hcl.tfvars@1` 双 profile）
- 目标版本：0.11.0（对齐路线图 §14.10）
- 先例实现：`crates/consema-plist/`（0.10.0，9 模块，共享 value model + 双 parser + operation registry 模式）、`crates/consema-xml/`（0.9.0，9 模块约 13k 行，parser 2649、edit 2490、projection 1945、materialization 1825、query 1735、document 884）
- 语义权威顺序（沿用 `docs/IMPLEMENTATION.md`）：永久不变量 → 已接受 RFC → 语言无关 conformance vectors → 本实现计划与 Rust API → 第三方行为仅为 differential oracle，非契约

本文是只读调研产出的执行计划；除本文外本次不修改任何仓库文件。所有行数估计为 Rust 源码（含该模块内测试）规模级，参考 consema-xml 与 consema-plist 各模块实际行数。

---

## 0. 总体结构

RFC 0014 与 RFC 0013 的关键差异是：**两个 profile 拥有同一个语法系统与同一个 native semantic model**（body/attribute/block/label/expression/template facts，RFC §1、§6），`hcl.tfvars@1` 只是 `hcl.native@1` 的一条结构限制（顶层仅 attributes，§5）。因此 crate 的拆分原则是：**原生模型（含 expression AST）在前，自研 lexer + parser 居中，下游四操作（query/projection/materialization/edit）全部在 Document 统一层之上、按 profile 类型化**。没有后端 parser crate（RFC §12：tokenizer、body/expression 文法、恢复、全部下游操作 Consema 自有；`hcl-rs` 已考虑并拒绝）。

```text
crates/consema-hcl/
├── Cargo.toml                 # 依赖：consema-core、consema-document、unicode-ident（workspace 钉版，见 §3.3）
└── src/
    ├── lib.rs                 # HclProfile、HclEncodingSelection、HclParseLimits、parse 入口、diagnostic code 常量（RFC §1-3、§5、§11）
    ├── native.rs              # HclDocument/HclBody/HclAttribute/HclBlock/HclBlockLabel/HclErrorRegion/HclNumber（RFC §6）
    ├── expression.rs          # HclExpression AST + HclTemplatePart + 结构相等 + literal-complete 谓词（RFC §4.3-4.6、§6、§8.1）
    ├── lexer.rs               # 自研 tokenizer：token 流 + 30 种 HclSyntaxKind 的 lossless piece 装配（RFC §2、§4.1、§7.2）
    ├── parser.rs              # body/expression 文法 + 恢复语义 + native 模型装配 + duplicate-attribute 门禁（RFC §3-4、§6）
    ├── document.rs            # Document 统一层（profile 为字段）、formation 状态、profile 关闭操作派发（RFC §1、§3、§5）
    ├── query.rs               # hcl.native-semantic-query@1 + hcl.lossless-syntax-query@1（RFC §7）
    ├── projection.rs          # hcl.projection.body@1 + ProjectExpression 策略 + hcl.expression@1 ExtendedValue（RFC §8）
    ├── materialization.rs     # hcl.canonical-document@1 + 重解析闭包（RFC §9）
    ├── edit.rs                # 六个结构编辑操作 × 两 profile 类型化（RFC §10）
    └── operation_registry.rs  # hcl 格式操作 registry（RFC §10 契约）
```

模块依赖方向（单向，对齐 plist 体例）：

```text
lib ──> native ──> expression ──> lexer ──> parser ──> document ──> query / projection / materialization / edit
         │           │             │         │            │
         └───────────┴─────────────┴─────────┴────────────┴──> consema-document（SourceSnapshot/NodeRef/Span/ChangeSet/...）
lib / document / projection / materialization / query / edit ──> consema-core（PortableValue/ExtendedValue/QueryDefinition/Diagnostic/...）
```

RFC 章节 → 模块映射：

| RFC 0014 章节 | 模块 |
|---|---|
| §1 Decision、§2 Source、§3 Formation、§5 tfvars、§11 Resource | lib.rs（profile 选择、encoding、limits、diagnostic code 常量）+ document.rs（tfvars 门禁接线） |
| §4.1 Token facts、§7.2 Lossless domain | lexer.rs（token 流 + 30 种 kind piece） |
| §4.2-4.6 Body/expression/template/heredoc/constructor 文法 | parser.rs + expression.rs（AST 变体） |
| §6 Native semantic model | native.rs + expression.rs |
| §7 Query contracts | query.rs（两域共用执行骨架） |
| §8 Projection | projection.rs + expression.rs（literal-complete 谓词） |
| §9 Materialization | materialization.rs |
| §10 Structural edit | edit.rs + operation_registry.rs |
| §12 Differential contract | 仓库级：scripts + conformance/oracles（见 §6.3） |
| §13 Conformance evidence | 仓库级：conformance/vectors + consema-conformance runner + tests（见 §6） |

## 1. crate 拓扑与复用决策

### 1.1 直接复用（consema-document / consema-core，零修改或仅加枚举变体）

| 共享件 | 复用方式 | 备注 |
|---|---|---|
| `SourceSnapshot` / `EncodingRequest` | 直接复用 | HCL 编码恒为 UTF-8（§2），**BOM 不得被剥离**（BOM 是 Recovered 而非 fatal，且 §7.2 无 `Bom` kind）——按 consema-properties 的 `TreatAsContent` BOM policy 先例，BOM 字节作为内容进入 decoded text，由 lexer 报 `hcl.parse.byte-order-mark@1` 并收容为 ErrorRegion piece（见 §7 R-2） |
| `ParseLimits`（common） | 直接复用，包进 `HclParseLimits` | 照 consema-plist `PlistParseLimits { common, ... }` 体例 |
| `FatalFormationFailure` | 直接复用 | `from_diagnostic` / `resource_limit`；invalid UTF-8 走此路径（§2、§3，RFC 0012 §4 先例） |
| `FormationStatus` / `LosslessStructuralIndex` | 直接复用 | Complete / Recovered / FatalFormationFailure 三路（§3） |
| `NodeRef` / `Span` / `DocumentAuthority` / `SnapshotIdentity` | 直接复用 | 需在 `NodeRole` 增加 hcl 角色（见 1.3） |
| `ChangeSet` / `SourceEdit` / `NodeMapping` | 直接复用 | 编辑提交契约（§10） |
| `SourcePatch` / `UntouchedByteProof` | 直接复用 | 编辑交付物（§10） |
| `MaterializationRequest` / `MaterializationResult` / `MaterializationLimits` / `MaterializationFailure` | 直接复用 | `MaterializationRequest::new(profile, style)`，style id `hcl.canonical-document@1`（§9） |
| `EditPlan` / `FormatOperationRegistry` / `FormatOperationDescriptor` / `OperationArgumentKind` | 直接复用 | operation registry 照 consema-xml `operation_registry.rs` 体例（六操作 × 两 profile） |
| `Diagnostic` / `QueryDefinition` / `QueryDomain` / `OperatorCall` 等（consema-core） | 直接复用 | 查询骨架与 plist/xml 完全同构；**QueryDomain 增加两个构造器**（见 1.2） |
| `PortableValue` / `BigInteger` / `Decimal` | 投影目标复用 | `hcl.body@1` 是 PortableValue 记录（§8.2），非新类型 |
| `ExtendedValue` / `ExtensionContract`（consema-core value.rs） | 投影目标复用 | `hcl.expression@1` 是 authorized ExtendedValue：`ExtensionContract` 的 `type_id`/`semantic_version`/`payload_codec_id`/`validate_canonical` 四件套直接套用（§8.2、§16 roadmap §5.5） |

### 1.2 需要格式专属扩展的复用点

| 共享件 | 扩展方式 |
|---|---|
| `NodeRole` | 新增 9 个角色（见 1.3） |
| `FormatFamilyId` | `FormatFamilyId::new("hcl", 1)` |
| `ProfileId` | `hcl.native`/1、`hcl.tfvars`/1（§1） |
| `QueryDomain`（consema-core/src/query.rs） | 新增构造器 `hcl_native_v1()`（`hcl.native-semantic-query@1`）与 `hcl_lossless_syntax_v1()`（`hcl.lossless-syntax-query@1`），照 `plist_native_v1()` 先例（§7）。**仅此两处**；`hcl.*` diagnostic codes 与查询 wire 契约不进 consema-protocol 核心注册表（§11：HCL query-result wire 契约不属 semantic-model v6，`core.hcl-query-result@1` 留给后续版本，遵循 RFC 0011 external-locator 模式） |
| `ParseLimits` common 上限 | 默认沿用；expression/template 深度等格式专属上限在 `HclParseLimits` 字段层（§2.6） |

### 1.3 NodeRole 增补清单（`crates/consema-document/src/lib.rs`，一次小修改）

```text
HclDocument       完整 hcl 文档句柄（native 域根）
HclBody           body 项容器（root 与嵌套 body 共用）
HclAttribute      attribute 项身份
HclBlock          block 项身份
HclBlockLabel     label 身份（quote/naked 事实）
HclExpression     expression 节点身份（AST 节点）
HclTemplatePart   template 有序 part 身份（Literal/Interpolation/Directive）
HclErrorRegion    恢复错误区域（与 XmlErrorRegion 体例平行）
HclSyntaxPiece    lossless piece（与 HclSyntaxKind 平行）
```

### 1.4 依赖

`Cargo.toml`（照 consema-plist 体例，workspace 钉版）：

```toml
[dependencies]
consema-core = { path = "../consema-core", version = "0.11.0" }
consema-document = { path = "../consema-document", version = "0.11.0" }
unicode-ident.workspace = true
```

- `unicode-ident 1.0.24`（已在 Cargo.lock，deny.toml 已允许 Unicode-3.0 许可证）：RFC §4.1 的 `Identifier = ID_Start (ID_Continue | "-")*`（UAX #31）要求完整 Unicode 属性表，自写属性表不现实；这是本次唯一新加的直接依赖，理由与 xmlparser 先例同类（契约要求健壮 Unicode tokenization）。见 §3.3。
- deny.toml 与 workspace 依赖策略不变（`[sources]` 仅 crates.io 钉版、`[bans]` 禁多版本/通配）。
- 版本号：crate `version.workspace = true`，0.11.0 发布时随 workspace 提升（当前 0.8.0，0.9.0/0.10.0 在 CHANGELOG Unreleased 下）。

## 2. 类型设计要点

### 2.1 Native semantic model（RFC §6）

HCL 是 **body 树**，不是值树，也不是共享身份 arena：与 plist 不同（plist 的共享对象身份要求 arena + 引用），HCL 的 body 项是每 occurrence 独立身份的有序树，plist 的 arena 模式**不适用**。原生模型按 §6 的类型清单直接落类型：

```rust
/// 根文档：一棵 body + formation 事实（§6）。
pub struct HclDocument {
    snapshot: Arc<SourceSnapshot>,       // 冻结源（§2：所有公共 span 为半开原始字节区间）
    body: HclBody,                       // root body，有序项
    status: FormationStatus,
    profile: HclProfile,                 // 模型 profile 无关；profile 决定 Complete 门禁与操作表面
    diagnostics: Arc<[Diagnostic]>,
    pieces: Arc<[StructuralPiece]>,      // lossless 穷尽覆盖（§7.2）
    kinds: Arc<[HclSyntaxKind]>,         // 与 pieces 平行
    limits: HclParseLimits,
}

pub struct HclBody { items: Arc<[HclBodyItem]> }          // 顺序保留；attribute/block 身份按 occurrence（§6）
pub enum HclBodyItem { Attribute(HclAttribute), Block(HclBlock) }

pub struct HclAttribute {
    name: Arc<str>, name_span: Span,
    equals_span: Span,                   // 含 `=` 的精确区间
    expression: HclExpression,           // 一等公民（§6：AST + 精确 span 双保留）
}

pub struct HclBlock {
    block_type: Arc<str>,                // 关键字拼写可作 block type（§4.1）
    labels: Arc<[HclBlockLabel]>,
    body: HclBody,                       // 嵌套 body（one-line block 同为 HclBlock，§4.2）
    span: Span,
}

pub struct HclBlockLabel { text: Arc<str>, span: Span, quoted: bool }   // quote/naked 事实（§6）

pub struct HclErrorRegion { span: Span, code: &'static str }           // 恢复区域（§3）
```

不变量（§6 冻结语义）：duplicate attribute 在 formation 已被排除（§3），**永不进入 native 模型**——重复 occurrence 只是可检视的 proven syntax piece，与 RFC §3 明示的 "never a native attribute" 一致；duplicate object-constructor keys、duplicate block occurrences、attribute/block 同名共享全部保留为有序 native facts（独立 span，永不折叠）；无变量绑定、函数表、模板展开或迭代（unevaluated 是默认契约）；无 application 类型（无 variable declaration/resource/provider/schema，硬门禁 2）。

### 2.2 Expression AST（RFC §4.3-4.6、§6 核心决策）

**关键决策（RFC §15 的 rejected alternatives 背面）：AST 与 span 派生原文双保留。** `HclExpression` 持有 kind + 有序子节点 + 精确 span；`text()` 是从冻结源 span 派生的精确原文（零重编码、零信息损失）。两种表示永远同时可用：AST 供结构（query kind/children、结构相等、literal 谓词），原文供精确性（trivia、转义、heredoc marker、数字拼写）。

```rust
/// 半开原始字节区间内的表达式 AST；文本永远由 span 从源派生。
pub struct HclExpression {
    kind: HclExpressionKind,
    span: Span,                    // 精确原文区间（§6 双保留）
}

pub enum HclExpressionKind {
    // 字面量族（§4.1、§4.3）
    Number(HclNumber),                      // 精确拼写 + canonical decimal（§2.3）
    Boolean(bool),                          // true/false 关键字字面量
    Null,                                   // null 字面量
    // 模板族（§4.4-4.5）
    Template { parts: Arc<[HclTemplatePart]> },   // 引号模板或 heredoc；heredoc mode/marker 由 span 指向原文
    // 引用族（§4.1、§4.3）
    FunctionCall { name: Arc<str>, name_span: Span, args: Arc<[HclCallArg]>, expand: bool },  // 尾随逗号、`...` 标记
    VariableRef { name: Arc<str> },         // 遍历根
    Traversal { root: HclTraversalRoot, steps: Arc<[HclTraversalStep]> },  // GetAttr | Index | attrSplat | fullSplat
    // 运算族（§4.3 优先级表）
    Unary { op: UnaryOp, operand: Box<HclExpression> },           // `-` | `!`；`!!x` = !(!x)；无 unary `+`
    Binary { op: BinaryOp, lhs: Box<HclExpression>, rhs: Box<HclExpression> },
    Conditional { condition: Box<HclExpression>, then: Box<HclExpression>, else_: Box<HclExpression> },
    // 构造器族（§4.6）
    ForTuple { intro: HclForIntro, value: Box<HclExpression>, condition: Option<Box<HclExpression>> },
    ForObject { intro: HclForIntro, key: Box<HclExpression>, value: Box<HclExpression>,
                grouping: bool, condition: Option<Box<HclExpression>> },   // `...` 分组标记为源事实
    Tuple { elements: Arc<[HclExpression]> },
    Object { entries: Arc<[HclObjectEntry]> },   // 有序、重复 key 保留（§4.6）
    Paren { inner: Box<HclExpression> },
}

pub struct HclCallArg { expression: HclExpression, expand: bool }   // `...` 标记
pub struct HclObjectEntry {
    key: HclObjectKey,                       // Identifier | Number | Template | Paren（§4.6）
    separator: ObjectSeparator,              // `=` | `:`（源事实）
    value: HclExpression,
}
pub enum HclObjectKey { Identifier(Arc<str>), Number(HclNumber), Template(TemplateKey), Paren(Box<HclExpression>) }
pub struct HclForIntro { key: Option<Arc<str>>, value: Arc<str>, collection: Box<HclExpression>, span: Span }

pub enum HclTemplatePart {                   // 有序 parts（§6）
    Literal { span: Span },                  // 精确转义文本；`$${`/`%%{` 转义即字面文本（§4.4）
    Interpolation { expression: HclExpression },   // `${ ... }`；`~` strip 标记是 span 内源事实，永不应用
    Directive { kind: HclDirectiveKind },    // if/else/endif/for/endfor（§4.4）
}
pub enum HclDirectiveKind {
    If { condition: Box<HclExpression> },
    Else, EndIf,
    For { intro: HclForIntro },              // 单标识符形式合法（冻结实现行为，§4.4、§12）
    EndFor,
}
```

`HclTraversalRoot` 与 `HclTraversalStep`：

```rust
pub enum HclTraversalRoot { Variable(Arc<str>), Boolean(bool), Null }   // 关键字双读：literal 与 static traversal（§4.1）
pub enum HclTraversalStep {
    GetAttr { name: Arc<str>, span: Span },        // `.Identifier`，绝不接受数字步（§12 D-5）
    Index { key: Box<HclExpression>, span: Span },
    AttrSplat { steps: Arc<[HclTraversalStep]> },  // `. * GetAttr*`
    FullSplat { steps: Arc<[HclTraversalStep]> },  // `[ * ] (GetAttr | Index)*`
}
```

要点：

- **关键字双读**（§4.1）：`true`/`false`/`null` 在 term 位置是字面量，同时规范允许其作 static traversal 根。AST 保留 kind（Boolean/Null）+ 精确 span——两种读法都由 span 指向的原文可重建，永不求值其中任一种。
- **`for` 歧义**（§4.6）：tuple 首元素或 object 首 key 拼写为 `for` 时 for-expression 解释优先；解析器按此冻结，`for` 作 key 必须加括号或引号。
- **结构相等**（§6 末段）：递归于 kind + 子节点；number 相等是 canonical-decimal 相等；template 相等是 part-wise（字面文本精确 + interpolation/directive 结构比较）；constructor 相等是 element-wise；节点身份永不参与值相等。此相等契约被 query 过滤、projection 比较与 `hcl.expression@1` 共用。
- **模板 unwrap**（§4.4）：单 interpolation 模板在求值下 unwrap——Consema 永不求值，此语义只记录不实现。

### 2.3 HclNumber 与 canonical decimal（RFC §4.1、§6、§9）

```rust
/// 精确源拼写 + canonical decimal 值（纯十进制字符串归一，零浮点运算）。
pub struct HclNumber {
    span: Span,                     // 精确拼写
    canonical_decimal: Arc<str>,    // 归一拼写：去前导零、去尾随分数零、指数折叠进小数点位置；`0` 表示零
}
```

- 文法：`decimal+ ("." decimal+)? (expmark decimal+)?`，`expmark = ("e"|"E") ("+"|"-")?`；无前导符号（`-` 是 unary operator）、无 hex/octal/binary/underscore（§4.1，`hcl.parse.invalid-number@1`）。
- 归一化是纯十进制字符串运算（十进制展开 + 移位 + 截尾），**不做任何浮点计算**（硬门禁 1）；digit 计数受 `max_number_digits` 限制（§11）。
- 数值相等 = canonical 字符串相等：`1.50`、`1.5`、`15e-1` 等值而拼写仍是独立源事实（§6）。
- 投影的 typed 成员判定（§8.2 的 "integer or real"）：canonical 无分数部分 → `Integer`（BigInteger），有分数部分 → `Decimal`（consema-core 类型）。`1e3` 归一为 `1000` 因此投影为 Integer——实现阶段以向量定格此边界。

### 2.4 literal-complete 的纯语法判定（RFC §8.1）

`expression.rs` 提供两个纯函数（**无求值器、无算术折叠**，硬门禁 1）：

```rust
/// 精确实现 §8.1 的边界；递归深度受 expression depth 限制。
pub fn is_literal_complete(expression: &HclExpression) -> bool;

/// literal-complete 表达式提取类型化字面值；derived 表达式返回 NonLiteral 错误。
pub fn literal_value(expression: &HclExpression)
    -> Result<HclLiteralValue, NonLiteralExpression>;
```

`HclLiteralValue` 变体 = String（精确 code points）/ Integer / Real（canonical decimal）/ Boolean / Null / Tuple / Object（有序 entries，重复 key 保留，§8.2）。

边界逐条落测试（§8.1 每个 bullet 正例 + 每个 derived 反例）：number/true/false/null 正例；零 interpolation 零 directive 的引号与 heredoc 模板正例（`$${`/`%%{` 转义计为字面文本；`<<-` heredoc 的字面值取 indentation-stripped 内容——**剥离只在读取字面值时执行，绝不破坏性改写**，§4.5）；tuple/object 全元素字面；object key ∈ {identifier, number literal, quoted literal template, parenthesized literal-complete}；unary minus 仅对 number literal；括号包裹。一切其他为 derived：variable/traversal、function call、binary（`1 + 2` 包含在内）、conditional、index/splat、for-expression、含任何 interpolation/directive 的模板、对非 number 的 unary。

### 2.5 tfvars 与 native 的关系（RFC §5）

- `hcl.tfvars@1` 不是独立文法：§4 每条 token/expression/template/comment 规则原样适用（含 per-body duplicate-attribute 规则）。唯一 profile 限制：**顶层 body 只收 attributes**；顶层出现 block → formation Recovered + `hcl.tfvars.block-not-allowed@1`。
- 设计决策：该门禁在 parser 组装后、status 判定处执行（profile 参数传入 parser）；顶层 block 是 proven 语法构造，**保留为 Recovered 文档的 native item**（Recovered 文档可对其 proven parts 查询，§3、§7）——对照 duplicate-attribute 的 "never a native attribute" 特例：duplicate 被排除是因为原生 body 的唯一性不变量（§3），而 tfvars 限制是 profile 级规则、不破坏原生模型不变量；此点与 plist "Recovered 保留已证明 value 元素" 先例一致。实现阶段在 M4 以向量复核（见 §7 R-8）。
- 两条边界不复制（§5）：Terraform 的 static-only 求值规则（`hcl.tfvars@1` formation 接受完整表达式文法，derived 表达式在 literal 投影失败而非 formation——硬门禁 3）；"value for undeclared variable"（无 schema，硬门禁 2）。
- profile 规则在每项操作下封闭（§5、§9、§10）：tfvars materialization 拒绝含 block 的记录（`hcl.materialization.unrepresentable@1`）；tfvars 不发布 block 编辑操作。

### 2.6 Expression 编辑边界（RFC §10、§14）

- 值以**类型化 literal-complete 值**提供（`EditValue` 枚举：string/integer/real/boolean/null/tuple/object），绝不以 raw markup、绝不以 unevaluated expression 文本（§10）。
- `set-attribute-value` 用 typed 值的 canonical 渲染替换目标 attribute 的 expression span；`insert-attribute`/`insert-block` 同样以 typed literal-complete 值构造。
- expression-AST 编辑、derived-expression 插入、任何需要求值的编辑都是 v1 显式 non-goal（§14）。
- tfvars profile 只发布四个 attribute 操作（`set-attribute-value`、`insert-attribute`、`remove-attribute`、`rename-attribute`），不发布 `insert-block`/`remove-block`（§10）。
- 编辑照 RFC 0012 体例：只替换操作自有 span 内文本，未触及字节全保留，重解析目标并验证承诺的 HCL 语义（§10 冲突校验全表：错误 profile/role/snapshot、缺失或重复目标、stale anchor、重叠源所有权、duplicate-attribute 创建、tfvars block 插入、不可表示值、限制失败、重解析失败）。成功返回新 Document + `ChangeSet` + `UntouchedByteProof` + 可重放 `SourcePatch`；失败返回无。dry-run/commit 有相同 replacement set 与 target digest。

### 2.7 HclParseLimits（RFC §11）

```rust
pub struct HclParseLimits {
    pub common: ParseLimits,                    // max_source_bytes、max_diagnostics 等公共上限
    pub max_decoded_utf8_bytes: usize,          // 解码后 UTF-8 字节数
    pub max_decoded_scalars: usize,             // 解码后 Unicode scalar 数
    pub max_body_depth: usize,                  // block 嵌套深度（root body 计 1）
    pub max_expression_depth: usize,            // expression 深度（解析递归预算与字面判定共用）
    pub max_template_depth: usize,              // 模板嵌套深度
    pub max_attribute_count: usize,
    pub max_block_count: usize,
    pub max_label_count: usize,
    pub max_body_item_count: usize,
    pub max_identifier_len: usize,
    pub max_string_len: usize,                  // 引号模板字节长
    pub max_number_digits: usize,               // canonical-decimal digit 数
    pub max_template_len: usize,
    pub max_template_interpolations: usize,     // 单模板内插值/指令序列数
    pub max_heredoc_lines: usize,               // 单 heredoc 行数上限
    pub max_heredoc_bytes: usize,               // heredoc 字节上限；含 unterminated heredoc 的错误区域边界（§3、§11）
    pub max_tuple_elements: usize,
    pub max_object_entries: usize,
    pub max_for_extent: usize,                  // for-expression 范围
    pub max_recovery_regions: usize,
    pub max_error_regions: usize,
    pub max_syntax_pieces: usize,               // lossless piece 数
    pub max_report_events: usize,               // projection/materialization/edit 报告事件
}
```

全部尺寸算术在分配前 checked（硬门禁 4）；limit 失败绝不伪装成空 body、截断 expression、缩短 query、部分 target 或成功 edit。两 profile 全程无副作用（§11 末段清单）。

## 3. 复用 vs 新写决策

### 3.1 Expression AST 与 PlistValue：无共享模式（推荐：完全新写）

plist 的 `PlistValue` 是**共享身份的值 arena**（同一对象多处引用要求 arena + ref）；HCL 的表达式是**每 occurrence 独立身份的语法树**（body 项按 occurrence 保留，无共享引用需求，§6）。两者的 shape、不变量（arena 环检测 vs 无环树 + span 双保留）、相等性（值相等 vs 结构相等）全部不同，**没有任何可共享的代码**。共享的只是 consema-document 的 NodeRef/Span 纪律与 consema-core 的 PortableValue/ExtendedValue 契约（§1.1）。RFC §15 亦已拒绝 "JSON 值树映射" 与 "纯 span 文本" 两个替代——AST + 原文双保留是唯一满足 query/相等/projection 需求的形态。

### 3.2 Lexer 自研（RFC §12 决策，与 xml/plist 完全不同的 tokenizer）

- plist.xml 消费 xmlparser token 流、plist.binary 是字节表解析——两者都不需要自研 tokenizer；HCL 的 tokenizer（注释/引号模板/heredoc/插值/指令扫描）无现成 crate 符合（RFC §12：无第三方 HCL parser 后端，`hcl-rs` 已考虑并拒绝），**lexer 全部自写**。
- Lexer 同时产出两样东西：parser 消费的 token 流，与 lossless 域的 30 种 `HclSyntaxKind` piece 数组（§7.2，无 `Bom` kind）。**每非空原始字节恰属一个有序 structural piece**。
- kind 闭集（30 种，逐字取自 §7.2）：

```text
Whitespace, LineBreak, LineComment, InlineComment, Identifier, Equals, Number,
StringOpen, StringContent, StringClose, InterpolationOpen, InterpolationContent, InterpolationClose,
DirectiveOpen, DirectiveContent, DirectiveClose, HeredocOpen, HeredocContent, HeredocClose,
BraceOpen, BraceClose, BracketOpen, BracketClose, ParenOpen, ParenClose,
Comma, Colon, QuestionMark, Operator, ErrorRegion
```

- piece 分区设计（M2 落测试）：引号模板 = `StringOpen` + [ `StringContent` | `InterpolationOpen`+`InterpolationContent`+`InterpolationClose` | `DirectiveOpen`+`DirectiveContent`+`DirectiveClose` ]* + `StringClose`；heredoc = `HeredocOpen`（`<<`/`<<-` + marker 标识符）+ 内容行（同上插值/指令分区，字面运行保持 `HeredocContent`）+ `HeredocClose`（closing marker 行）；`ErrorRegion` 收容 BOM、lone CR、非法字符、unterminated 构造等恢复区域。
- 字符串/heredoc 内的插值与指令**不在 piece 层再展开**（kind 闭集只有 Open/Content/Close 三层）；parser 从 `InterpolationContent`/`DirectiveContent` 的 span 二次解析表达式。

### 3.3 UAX #31 标识符属性表：引入 unicode-ident（推荐）

RFC §4.1 冻结 `Identifier = ID_Start (ID_Continue | "-")*`（UAX #31），§13 conformance 要求 Unicode 字母矩阵。Rust 标准库无 ID_Start/ID_Continue 查询；自写属性表不可维护。`unicode-ident 1.0.24` 已在 Cargo.lock（传递依赖），deny.toml 已允许其许可证（Unicode-3.0），workspace 钉版后作直接依赖是低风险变更——与 xmlparser 先例同类（契约要求健壮 Unicode 处理）。备选（不推荐）：自写 ASCII+常用表，会在 conformance 向量上产生不可接受的属性缺口。

### 3.4 Differential oracle：新脚本，钉版 Go hashicorp/hcl，只比 parse 接受/拒绝

- `scripts/run-hcl-go-oracle.ps1`（PowerShell，对齐仓库 oracle 脚本模式：manifest 校验 → runtime 事实校验 → 逐 fixture 执行 → TSV 报告 → 退出码）+ `conformance/oracles/hcl-go-v1/`（Go 驱动 + manifest + fixture 集）。
- 钉版：hashicorp/hcl 具体 commit（go.mod/go.sum 钉死）、Go toolchain 版本与 digest、调用旗标、输入 digest、期望输出、每条排除（§12 清单）。Windows CI 无 Go runner 时按仓库先例显式跳过并在 manifest 记录。
- 驱动调用 `hclsyntax.ParseConfig` / `hclparse.ParseHCL`（文档 fixture）与 `hclsyntax.ParseExpression`（表达式 fixture），输出 parse 接受/拒绝。**只比较 parse outcome 与 Profile 的 Complete/Recovered outcome**；绝不调用 cty 求值、绝不比较值（§12）。
- 差分分歧的处理政策照 §12 末段：不得改 Consema 行为匹配（须走 RFC 或记录排除），不允许 untracked allowlist。

### 3.5 其余新写点（无复用歧义）

- **canonical decimal 归一化**（§2.3）：十进制字符串运算，自写约 150 行 + 边界测试。
- **heredoc 处理**（§4.5）：marker 扫描、TrimSpace closing-line 匹配（冻结实现行为，比规范更宽）、`<<-` 缩进分析（只在读字面值时剥离）、unterminated → `hcl.parse.unterminated-heredoc@1`（错误区域到 heredoc size 上限，§3、§11）。
- **canonical 渲染**（§9）：字符串最小确定性转义集（`\n` `\r` `\t` `\"` `\\` + `\uNNNN`/`\UNNNNNNNN`）、数字 canonical 拼写、label 恒加引号、两空格缩进、`type "label" {` 头。

## 4. 里程碑拆分

10 个里程碑，按依赖排序。`M` 为必须串行（前驱产物直接输入），`‖` 为可并行（文件域隔离，互不 import 对方中间产物；仅依赖共享的 consema-document/consema-core 与已完成里程碑的公共 API）。

**与 plist 计划的关键差异**：plist 有两波并行（M2‖M3 双 parser、M5-M8 四路）；HCL 的 lexer → parser 是严格串行（自研 tokenizer 没有 xmlparser 式后端可代劳），并行机会收敛为**一波四路**（M5-M8）+ 收口期 M9‖M10。缓解：expression.rs + native.rs 并入 M1（AST 类型与 literal-complete 谓词先行冻结，M5-M8 的公共 API 输入不受 parser 延迟影响）；oracle 脚本框架可在 M3 后即搭（§5 约束）。

| # | 里程碑 | 依赖 | 并行性 | 预估行数 | 交付物 |
|---|---|---|---|---|---|
| M1 | crate 骨架 + native model | — | 串行起点 | 1900-2400 | Cargo.toml、lib.rs 骨架（profile/encoding/limits/parse 入口）、native.rs 全量、expression.rs 全量（AST + 结构相等 + literal-complete）、NodeRole 增补 |
| M2 | lexer | M1 | 串行（M3 前置） | 1300-1700 | lexer.rs（token 流 + 30 种 kind piece 装配）、token 级测试矩阵 |
| M3 | parser | M2 | 串行 | 1700-2200 | parser.rs（body/expression 文法 + 恢复语义 + duplicate 门禁 + native 装配）、formation 向量初稿 |
| M4 | tfvars 限制层 + 统一 Document | M3 | 串行合并 | 900-1200 | document.rs、profile 接线、tfvars 门禁、encoding 契约、字节精确 round-trip 门禁、公共 API 冻结 |
| M5 | 查询 ×2 域 | M4 | ‖ 与 M6/M7/M8 并行 | 1300-1700 | query.rs（native 21 操作符 + lossless 30 kind）+ consema-core QueryDomain 构造器 |
| M6 | 投影 | M4 | ‖ 与 M5/M7/M8 并行 | 1300-1700 | projection.rs（hcl.projection.body@1 + ProjectExpression 策略 + hcl.expression@1 ExtendedValue） |
| M7 | 物化 | M4 | ‖ 与 M5/M6/M8 并行 | 1200-1600 | materialization.rs（hcl.canonical-document@1 + 重解析闭包） |
| M8 | 编辑 | M4 | ‖ 与 M5/M6/M7 并行 | 1700-2200 | edit.rs、operation_registry.rs |
| M9 | conformance 向量 + runner + hardening + 差分 oracle | M2-M8 全部 | 串行收口（‖ M10） | 3000-4000 | `conformance/vectors/hcl-v1.json`、`crates/consema-conformance/src/hcl_v1.rs`、`tests/hcl_hardening.rs`、`tests/hcl_fixtures.rs`、`conformance/fixtures/hcl/`、`scripts/run-hcl-go-oracle.ps1`、`conformance/oracles/hcl-go-v1/` |
| M10 | facade 集成 + 发布文档 | M4 起的公共 API、M9 可并行 | ‖ M9（不同文件域） | 1000-1400 + 文档 | facade 导出、CHANGELOG/IMPLEMENTATION/路线图更新、BENCHMARKS-0.11.0.md |

总规模估计：crate 源码 11.5k-15k 行（对照 consema-xml 实际 13k、plist 计划 11k-15k；parser+lexer 全自研为最大增量），conformance 资产 4k-6k 行，脚本/文档另计。实施节奏：M1 → M2 → M3 → M4 → [M5 ‖ M6 ‖ M7 ‖ M8] → [M9 ‖ M10]。

### M1 — crate 骨架 + native model（串行起点）

范围：
- workspace `Cargo.toml` members 增加 `crates/consema-hcl`；`unicode-ident` 进 `[workspace.dependencies]`；`crates/consema-document` 的 `NodeRole` 增加 1.3 节九个角色。
- `lib.rs`：`HclProfile { NativeV1, TfvarsV1 }`（`id()` 返回 `hcl.native`/`hcl.tfvars`，与 PlistProfile 同体例）、`HclEncodingSelection`（UTF-8-only：`ProfileDefault` 与 `Explicit(SourceEncoding::Utf8)` 合法；其他编码是 v1 排除、source-contract 冲突，§2）、`HclParseLimits`（2.7 节全字段）、`parse(source, profile, limits)` 入口（M4 前先占位薄分发）。
- `native.rs`：2.1 节全量类型 + 构造校验（duplicate-attribute 不在模型层重复——formation 排除）+ 类型测试。
- `expression.rs`：2.2-2.4 节全量——AST 变体、HclTemplatePart/HclDirectiveKind、HclNumber + canonical decimal 归一化、结构相等（PartEq 式递归）、`is_literal_complete` + `literal_value`、`HclTraversalRoot/Step`。
- 30 种 `HclSyntaxKind` 枚举在此冻结（M2/M3 共用闭集），放 `lexer.rs` 的公共类型区或 native.rs 导出。

验收门禁：
- `cargo test -p consema-hcl`（本里程碑测试全绿）；clippy `-D warnings`；fmt；missing_docs 零告警。
- 类型测试覆盖：每个 AST 变体构造/结构相等；canonical number 相等矩阵（`1.50`/`1.5`/`15e-1` 等值、拼写独立、前导零/尾零/指数折叠、`0`）；literal-complete 正反矩阵（§8.1 每个 bullet + `-true`/`1 + 2`/`$${x}` 转义字面/`<<-` 剥离读取等边界）；`HclSyntaxKind` 闭集恰 30 种。
- `cargo check --workspace`（NodeRole 增补不破坏既有 crate）。

### M2 — lexer（串行，M3 前置）

范围（RFC §2、§4.1、§7.2）：
- 标识符：UAX #31（unicode-ident），`ID_Start (ID_Continue | "-")*`；`_` 不可作 start（`_foo` → 文法错误 Recovered，§12 D-4）；`foo-bar` 合法；关键字拼写（true/false/null）是合法标识符 token（§4.1 双读）。
- 数字：§4.1 文法精确；hex/octal/binary/underscore/`+1` 前导符号 → `hcl.parse.invalid-number@1` 的 error token（Recovered 由 parser 定夺）。
- 注释：`//`、`#` line comment（等价于 newline，终止 attribute/block，§4.1）；`/* */` inline（可跨行、不可嵌套、不终止构造）；模板字面文本内无注释（插值/指令序列内除外）。
- 换行：LF / CRLF 是 newline token；lone CR → error token（`hcl.parse.lone-cr@1`，§12 D-2）；括号/方括号/花括号内的换行由 parser 按 whitespace 忽略（§2）。
- 引号模板扫描：`\n` `\r` `\t` `\"` `\\` `\uNNNN`（BMP）`\UNNNNNNNN`（supplementary）转义；非法转义 → error；字面换行序列 → 文法错误；`$${`/`%%{` 转义；`${~`/`~}`、`%{~`/`~}` strip 标记（源事实保留）；unterminated string → error token（恢复边界到行尾，§3）。
- heredoc 扫描：`<<`/`<<-` + bare identifier marker；closing line 以 `bytes.TrimSpace` 语义匹配（§4.5、§12 D-8）；marker 行含其他内容不是 closing；引号 marker（`<<"EOT"`）→ 文法错误（§4.5）；`<<-` 缩进分析（模式/marker/leading spaces 全部表示事实）；unterminated heredoc → 到 EOF 收容、错误区域以 `max_heredoc_bytes` 为界（§3、§11、§12）。
- piece 装配：§3.2 的 30 种 kind 穷尽覆盖（无空洞无重叠、kinds 与 pieces 平行、首尾相接、`render() == 输入字节`）；`ErrorRegion` 收容 BOM/lone CR/非法字符/错误 token 区域。

验收门禁：
- token 矩阵测试覆盖 §4.1 每条：identifier（ASCII/Unicode 字母、数字、连字符续、`_` start 拒绝、关键字拼写）、number（decimal/exponent/sign 边、hex/octal/binary/underscore/`+1` 拒绝）、注释（`#`、`//`、`/* */`、嵌套拒绝、comment-as-newline、跨行 inline）、换行（LF/CRLF/lone CR）、字符串（全部转义、非法转义、`$${`/`%%{`、strip 标记、unterminated）、heredoc（两模式、marker 规则、TrimSpace closing、unterminated）。
- 每个源断言 `assert_exact_coverage` 体例（pieces 无空洞无重叠、kind 数组平行）；BOM 字节以 ErrorRegion 收容且**无 `Bom` kind**（§7.2）。
- `cargo test -p consema-hcl`、clippy、fmt 全绿。

### M3 — parser（串行）

范围（RFC §3、§4.2-4.6）：
- body 文法：`Attribute`（identifier `=` expression + newline/EOF 终止，§4.2）、`Block`（type + labels（quoted literal string 无插值 | naked identifier）+ 嵌套 body）、`OneLineBlock`（至多一个 attribute、无嵌套 block，native 上同为 HclBlock）；空源 = 空 body；EOF 终止最后一个 body item（§12 D-9）；attribute/block 同名共享保留（§4.2，differential expected-no-divergence）。
- duplicate-attribute 门禁（§3）：同 body 同名 attribute → Recovered + `hcl.parse.duplicate-attribute@1`；重复 occurrence 是 proven syntax piece，**永不 native**。
- expression 文法：§4.3 优先级表（unary 最高 → `* / %` → `+ -` → 比较 → `== !=` → `&&` → `||` → conditional 最低，binary 左结合）；unary 在 term 层（`-46+5` = `(-46)+5`、`!!x`、`2 * -1`、`+1` 拒绝）；条件 `? :` 唯一 unparenthesized colon 语境；括号/函数参数内换行忽略；函数调用尾随逗号与 `...` 展开标记；遍历（GetAttr 仅 Identifier——`foo.0` 拒绝，§12 D-5；Index；两种 splat）；函数名仅 Identifier——`foo::bar()` 拒绝（§12 D-6）；tuple/object（逗号或换行分隔、尾随逗号；object key 四形；`=`/`:` 分隔）；for-expression（guard `if`、object 分组 `...`、intro 的 `for` 优先解释）；`for`-as-key 歧义。
- template/heredoc：插值与指令在表达式内可嵌套 template（§4.4）；单标识符 for-directive 合法（§12 D-7）；heredoc 模式/marker 表示事实。
- 恢复语义（§3 全边界）：expression 失败 → 行尾为界的错误区域；unterminated bracket/paren/brace → 到匹配 close（有则）否则行尾；unterminated string → 行尾；unterminated heredoc → EOF（heredoc size 为界）；template 内 unterminated interpolation/directive → 覆盖模板余下部分；恢复后 body 解析从下一行继续。**绝不虚构 closing delimiter/identifier/equals/value**（§3）。
- 三路 outcome 判定（Complete 需穷尽覆盖 + 每项配置 limit + profile 结构规则——profile 结构规则在 M4 接线，parser 先以参数接收 profile）。
- diagnostics：`hcl.parse.*@1`、`hcl.limit.*@1` 常量注册（§11 命名模式），不进 consema-protocol 核心注册表。
- native 装配：HclBody/HclAttribute/HclBlock/HclExpression 全量（每项精确 span）。

验收门禁：
- §4 文法矩阵测试：body（attribute/block/one-line/labels 两形/空 body/EOF 终止/同名共享）、expression（每操作符与优先级边、unary 复合矩阵、条件、括号换行、函数尾随逗号 + `...`、遍历/index/两 splat、for 带 guard 与分组、tuple/object 换行分隔与尾随逗号、重复 object key、for-as-key 歧义）、template（嵌套、strip 标记、单标识符 for-directive）、heredoc（两模式、TrimSpace closing、unterminated）。
- 恢复矩阵覆盖 §3 每条边界；Recovered 保留已证明 piece 与 native 项；duplicate-attribute 负例（occurrence 是 piece 非 native）。
- 字节精确 `render() == 输入字节`（Complete 与 Recovered 皆然）；`assert_exact_coverage` 穷尽断言。
- 解析递归深度受 `max_expression_depth` 预算（对抗输入不 panic，见 §7 R-5）。

### M4 — tfvars 限制层 + 统一 Document（串行合并）

范围：
- `document.rs`：`HclDocument`（2.1 节）+ 公共方法（`render()`、`formation_status()`、`snapshot_identity()`、`profile()`、`diagnostics()`、`body()`、`query`/`project`/`materialize`/`commit` 派发、`lossless_structural_index()` + `lossless_syntax_kinds()`）。**一个结构、profile 为字段**——与 plist 的双变体 `Document` 枚举不同：HCL 两 profile 共享同一语法与模型，枚举没有收益（§1、§5）；tfvars 由 profile 字段驱动门禁与操作表面。
- profile 接线：`parse(source, profile, limits)` 完整化；tfvars 门禁（顶层 block → Recovered + `hcl.tfvars.block-not-allowed@1`，§5；block 保留为 native item 的决策见 §2.5、§7 R-8）。
- encoding 契约（§2）：UTF-8-only；BOM（前导或他处）→ Recovered + `hcl.parse.byte-order-mark@1`（BOM 字节以 ErrorRegion 收容，无 Bom kind）；invalid UTF-8 → `FatalFormationFailure` + `hcl.parse.invalid-utf8@1`（RFC 0012 §4 先例）；lone CR → Recovered + `hcl.parse.lone-cr@1`。
- profile 关闭操作：Recovered 文档可查询、不可 project/materialize/commit（§3）；tfvars 下 materialization 拒绝含 block 记录、edit 不发布 block 操作（§5、§9、§10）。
- 公共 API 冻结检查（M5-M8 四路并行的输入契约）。

验收门禁：
- tfvars 矩阵：attribute-only 完整文档；顶层 block 各位置 → Recovered + 稳定 code；值内完整表达式文法 formation 接受（§5 静态规则不复制）；Complete tfvars 无嵌套 body。
- encoding 矩阵：BOM 前导/他处、invalid UTF-8 fatal、lone CR；等价性断言（lone CR 下 Consema 与 oracle 都不产生 Complete，§12）。
- round-trip：Complete 与 Recovered 文档 `render() == 输入字节`；Recovered query 可用、project/materialize/commit 拒绝断言。
- 既有 crate 回归（NodeRole 增补后 workspace 全测试）；公共 API 冻结清单评审。

### M5 — 查询 ×2 域（‖ 并行）

范围（RFC §7）：
- consema-core `QueryDomain` 增补 `hcl_native_v1()` / `hcl_lossless_syntax_v1()` 构造器（§1.2）。
- `hcl.native-semantic-query@1`（§7.1，21 个操作符逐条注册）：`hcl.document-body@1`、`hcl.body-items@1`、`hcl.body-attributes@1`、`hcl.body-blocks@1`、`hcl.body-block-type-equals@1`、`hcl.attribute-name@1`、`hcl.attribute-name-equals@1`、`hcl.attribute-expression@1`、`hcl.attribute-literal-value@1`（typed accessor 族：`as-string`/`as-integer`/`as-real`/`as-boolean-is`/`as-null-is`——先验证 literal-complete 再验证类型，非字面或类型不匹配是查询失败，**永不返回 null/空/转换结果**）、`hcl.block-type@1`、`hcl.block-type-equals@1`、`hcl.block-labels@1`、`hcl.block-label-equals@1`、`hcl.block-nested-body@1`、`hcl.expression-kind-is@1`、`hcl.expression-is-literal@1`（§8.1 谓词精确复用 expression.rs）、`hcl.expression-text@1`（span 派生原文）、`hcl.expression-children@1`、`hcl.template-parts@1`（有序 parts）、`hcl.tuple-elements@1`、`hcl.object-entries@1`（有序 entries，重复 key 全保留）。结果保源序（§7.1）。
- `hcl.lossless-syntax-query@1`（§7.2）：30 种 kind 过滤 + 解码文本过滤；无 `Bom` kind；`HeredocOpen` 覆盖 `<<`/`<<-` + marker、`HeredocClose` 覆盖 closing marker 行。
- 域/操作符/角色/profile 校验先于首个结果；common ordered selection、limits、cancellation、terminal-state 规则不变。
- 执行器照 plist query.rs 骨架（`QueryDefinition::new(QueryDomain::hcl_native_v1()).validate().bind() → execute_hcl_native_query/_cursor`）。

验收门禁：21 + 30 操作符清单逐条有 crate 内测试；typed accessor 失败断言（非字面/类型不匹配 → 失败非转换）；结果保序；cursor/limit/cancellation 公共契约；`hcl.expression-is-literal@1` 与 `is_literal_complete` 全矩阵一致。

### M6 — 投影（‖ 并行）

范围（RFC §8）：
- 默认精确目标 `hcl.projection.body@1`（§8.2）：产出版本化 `hcl.body@1` PortableValue 记录——有序 body items，每 item 为 attribute（name string + 类型化 value）或 block（type + 有序 labels + 嵌套 `hcl.body@1`）；attribute 值须 literal-complete，渲染为 typed member：string（精确 code points）、integer 或 real（精确 canonical decimal，§2.3 的 Integer/Decimal 判定）、boolean、null、tuple、object。attribute 序、block 序、label 序、重复 object key 全保（§8.2）。
- derived 表达式：默认原子失败 `hcl.projection.non-literal-expression@1`；显式 `ProjectExpression` 策略下每个 derived 表达式投影为 authorized ExtendedValue `hcl.expression@1`（§8.2）：type_id `hcl.expression`、semantic_version 1、版本化 payload codec、payload = kind + 精确原文 + structural fingerprint 的版本化编码；`ExtensionContract::validate_canonical` 重解析 payload 内嵌原文并比对 fingerprint（与 materialization 的 reparse 闭包同一纪律）；相等性走 §6 结构相等。每替换一个表达式报一条 `Transformed` 事件（value + expression provenance）。
- 无其他变换（硬门禁 4）：无 expression-to-string 渲染、无 error-to-value 替换、无上下文猜测；Recovered 文档永不投影（§8.2 末段）。
- 投影限额：node counts 与报告事件（§11）。

验收门禁：literal-complete 矩阵正负例（§8.1 全 bullet）；`hcl.body@1` golden 记录（typed members、顺序、重复 object key 保留、整数/实数判定边界如 `1e3`）；derived → 原子失败 + 稳定 code；ProjectExpression 策略下 `hcl.expression@1` 的 type_id/version/encoding/fingerprint 断言 + `Transformed` 事件数与内容；Recovered 投影拒绝；provenance 关联计数断言（照 xml_v1.rs `run_projection` 体例）。

### M7 — 物化（‖ 并行）

范围（RFC §9）：
- style id `hcl.canonical-document@1`：UTF-8 无 BOM、LF、每 body 嵌套级两空格缩进、`name = value` attributes、block 头 `type "label" {`、末项后尾换行（§9）。
- 规则：字符串重加引号 + 最小确定性转义（`\n` `\r` `\t` `\"` `\\` + 歧义/控制字符用 `\uNNNN`/`\UNNNNNNNN`）；数字发 canonical 拼写（`1.50` 与 `15e-1` 都物化为 `1.5`，`0` 为 `0`）；boolean/null 发 `true`/`false`/`null`；tuple/object 逗号分隔、确定性的 one-item-per-line 布局于所选缩进、`=` keys；`hcl.expression@1` ExtendedValues 发其 canonical 文本并**必须重解析回相同 structural fingerprint**（§9）；labels 恒加引号（§9）。
- tfvars target 只收 attribute-only 记录；含 block 的记录 → `hcl.materialization.unrepresentable@1`（§5、§9）。
- 公共契约：输入先全量验证再按比例分配；编码后**重解析精确生成字节**（承诺的 Profile 下）并比较重解析 native model 与承诺输入语义——数字按 canonical-decimal 值相等、其余按 §6 结构相等；失败返回无目标 Document、无 partial bytes、无 partial provenance（§9）。
- 限额：输入/输出大小、node counts、全部算术（§9、§11）。

验收门禁：golden byte 测试（缩进、换行、转义、canonical 数字折叠、label 引号、尾换行）；tfvars block-in-record 失败矩阵；重解析闭包失败注入（破坏生成器产物必须被闭包抓住）；`hcl.expression@1` reparse fingerprint 闭包；输入/输出/节点/算术限额负例。

### M8 — 编辑（‖ 并行）

范围（RFC §10）：
- 六操作按 profile 类型化：`hcl.edit.set-attribute-value@1`、`hcl.edit.insert-attribute@1`、`hcl.edit.remove-attribute@1`、`hcl.edit.rename-attribute@1`、`hcl.edit.insert-block@1`、`hcl.edit.remove-block@1`；tfvars 只发布前四个（§10）。
- 值以 typed literal-complete 提供（§2.6）；`set-attribute-value` 替换目标 expression span 为 typed 值的 canonical 渲染；`insert-attribute` 在位置锚（first/last/after 精确 NodeRef）插入；`remove-attribute` 移除 name/equals/expression/owned trivia；`rename-attribute` 改 name；`insert-block` 加 block（type、labels、嵌套 body 的 attributes 全 typed literal-complete）；`remove-block` 按精确 NodeRef 移除。
- 编辑照 RFC 0012 体例：只替换操作自有 span 内文本、未触及字节全保留、重解析目标并验证承诺 HCL 语义；冲突校验全表（§10 末段：错误 profile/role/snapshot、缺失或重复 target、stale anchor、重叠源所有权、duplicate-attribute 创建、tfvars block 插入、不可表示值、limit 失败、reparse 失败）。成功返回新 Document + `ChangeSet` + `UntouchedByteProof` + 可重放 `SourcePatch`；失败返回无。dry-run/commit 相同 replacement set 与 target digest；不写文件、不求值（硬门禁 1）。
- `operation_registry.rs`：`format_operation_registry(profile)` 注册六（或四）操作描述符（照 consema-xml 125 行体例；id 即 `hcl.edit.set-attribute-value@1` 等，target role 用 1.3 节的 HclAttribute/HclBlock 角色）。

验收门禁：每操作正例（字节精确渲染 + 两 profile 下 native 结果一致）；tfvars 操作表面（block 操作缺失断言）；typed-value-only 约束（raw markup/expression 文本被类型系统拒绝）；冲突矩阵每条负例；`UntouchedByteProof` 区域与 `SourcePatch` 重放（patch 应用旧快照 → 字节等于新快照渲染）；dry-run/commit 等价；operation registry id 清单测试。

### M9 — conformance 向量 + runner + hardening + 差分 oracle（串行收口）

范围（§13 全节）：
- `conformance/vectors/hcl-v1.json`：suite id `consema.hcl.conformance@1`（§6.1）；case 带 `input.profile`（`hcl.native@1`/`hcl.tfvars@1`）与 capability（`hcl.native-formation@1`、`hcl.tfvars-formation@1`、`hcl.query@1`、`hcl.projection@1`、`hcl.materialization@1`、`hcl.edit@1`、`hcl.limit@1`）。覆盖 §13 清单：token facts（identifier 矩阵含 Unicode/`_` 拒绝/关键字拼写如 `true = 1`、number 矩阵、keywords、注释矩阵、newline 矩阵）；body（attributes/blocks/labels 两形/one-line/duplicate/同名共享/空 body/EOF 终止）；expressions（操作符与优先级边、unary 复合矩阵、`? :`、括号换行、函数尾随逗号 + `...`、遍历/index/两 splat、for 带 guard 与分组、tuple/object 换行与尾随逗号、重复 object key、for-as-key 歧义）；templates/heredocs（转义、strip 标记、单标识符 for-directive、`$${`/`%%{`、两 heredoc 模式、TrimSpace closing、unterminated 形）；tfvars（attribute-only、block 拒绝、值内全表达式文法）；recovery（§3 每边界与错误区域形状）；query（两域）；projection（literal-complete 矩阵、derived 失败、ProjectExpression 策略 + `hcl.expression@1` ExtendedValue 专属向量）；两种 canonical materialization + 重解析闭包；六个编辑操作 dry-run/commit 等价、untouched proof、patch replay；adversarial（expression depth、template/heredoc size、number digit count、body nesting、item counts、算术 overflow）；生产形夹具（Terraform-like `.tf`/`.tfvars`：module/resource/variable/locals 形；HCL-using 项目文件：Packer/Nomad/Vault 形，无 secrets、license 钉版）。
- `crates/consema-conformance/src/hcl_v1.rs`：照 plist_v1.rs 全模式（SUITE 常量、`HCL_V1_VECTORS_JSON` include_str、`run_hcl_v1`/`run_hcl_v1_json`、按 capability 分派、suite id 检查、case id 去重、formation/query/projection/materialization/edit/limit 处理器、materialization_failure_code 映射）。
- `tests/hcl_hardening.rs`：照 plist_hardening.rs 体例（mutation/truncation/nesting/depth/count/算术对抗 + 不 panic + 穷尽覆盖闭包断言 + kinds 平行断言）。
- `tests/hcl_fixtures.rs`：生产夹具投影→物化→重解析不动点门禁（照 xml_fixtures.rs）。
- `conformance/fixtures/hcl/`：`tf/` 与 `tfvars/` 子目录 + README（来源/许可证钉版）。
- `scripts/run-hcl-go-oracle.ps1` + `conformance/oracles/hcl-go-v1/`：§3.4 的钉版 Go 驱动 + `manifest.json`（§6.3）；suite id `consema.hcl.go-differential@1`。

验收门禁：`cargo test -p consema-conformance` 全套全绿（对齐 "17 套 suite" 体例——0.10.0 为 16 套 411/411，0.11.0 加 HCL 57 例（17 套 468/468））；向量数据驱动（改一个期望必须失败）；suite id 检查测试；oracle manifest 排除清单与 §12 逐条对齐（见 §7 D-1..D-9）。

### M10 — facade 集成 + 发布文档（与 M9 可并行）

范围：
- facade（`crates/consema/src/`）：`pub use consema_hcl as hcl`；`DocumentInner::Hcl(Box<consema_hcl::Document>)` + `parse_hcl`/`as_hcl`；`FormatMismatch::Hcl`；conversion.rs 增加 `convert_hcl`（跨格式经 projection/materialization 组合，照 convert_plist 体例；**从 HCL 转换遇 derived 表达式按默认精确目标原子失败**——conversion 不隐式启用 ProjectExpression 策略，文档明示）。facade 测试照既有体例（parse_hcl 两 profile、render、as_* 误用拒绝）。
- 文档：CHANGELOG 0.11.0 条目、`docs/IMPLEMENTATION.md` 新增 hcl 章节（crate 边界表更新）、路线图 §14.10 落实状态更新、`docs/BENCHMARKS-0.11.0.md`。

验收门禁：facade 测试全绿；`cargo test --workspace` 全绿；文档评审；发布门禁沿用仓库体例：conformance 全绿 + hardening + fixtures + benchmarks + `scripts/verify-package-archives.ps1` 对 14 个可发布 crate 全量通过。

## 5. 多 agent 并行化建议（文件域划分）

每个并行里程碑派发一个 agent，文件域互不重叠，仅共享已完成里程碑的公共 API：

| Agent | 文件域 | 里程碑 | 前置（公共 API 输入） |
|---|---|---|---|
| A | `crates/consema-hcl/src/native.rs` + `expression.rs` + `lib.rs` 骨架 + workspace Cargo.toml + consema-document NodeRole | M1 | 无（最先） |
| B | `lexer.rs` | M2 | M1 的 HclSyntaxKind 闭集与 limits API |
| C | `parser.rs` | M3 | M2 的 token API + M1 的 native/expression API |
| D | `document.rs` + `lib.rs` parse 接线（tfvars 门禁） | M4 | M3 的 formation 产物类型 |
| E | `query.rs` + `crates/consema-core/src/query.rs`（两个构造器） | M5 | M4 的 Document 公共 API |
| F | `projection.rs` | M6 | M4 的 Document 公共 API + M1 的 literal-complete |
| G | `materialization.rs` | M7 | M4 的 Document 公共 API + M3 parser（重解析闭包） |
| H | `edit.rs` + `operation_registry.rs` | M8 | M4 的 Document 公共 API |
| I | `conformance/vectors/hcl-v1.json` + `hcl_v1.rs` + 两个测试 + fixtures + oracle 脚本与 manifest | M9 | M2-M8 全部公共 API |
| J | `crates/consema/src/`（facade + conversion）+ 文档 | M10 | M4 起的公共 API（可与 I 同期） |

约束：
- E/F/G/H 四个 agent 并行时，`document.rs`、`native.rs`、`expression.rs`、`lib.rs` 为只读共享域；任何 API 调整须先经过 M4 稳定（M4 验收门禁包含"公共 API 冻结"检查）。
- 向量 JSON 与 runner 必须同批（runner 是向量的唯一权威执行者，照 plist_v1.rs "vector data drives results" 体例）。
- oracle 脚本框架可在 M3 完成后先搭（formation 已可产出），fixture 集取自 M9 的 fixtures 目录；digest 回填是 M9 与 M10 的唯一交接点。

## 6. conformance 集成细节

### 6.1 向量套件命名

`consema.hcl.conformance@1`（对齐 `consema.plist.conformance@1` / `consema.ini.conformance@1` 家族体例；`hcl` 单家族双 profile，`hcl` 后缀 + 文件内 `profiles` 数组）：

```json
{
  "suite": "consema.hcl.conformance@1",
  "profiles": ["hcl.native@1", "hcl.tfvars@1"],
  "cases": [ ... ]
}
```

每 case：`id`（稳定）、`capability`（七类：`hcl.native-formation@1`、`hcl.tfvars-formation@1`、`hcl.query@1`、`hcl.projection@1`、`hcl.materialization@1`、`hcl.edit@1`、`hcl.limit@1`——formation 按 profile 前缀，对齐 plist 先例）、`input`（`profile`、`source` 文本、limits 覆盖字段）、`expected`（status/render/diagnostic/matches/failure/records）。`hcl.expression@1` ExtendedValue 专属向量在 `hcl.projection@1` capability 下断言 type_id/version/编码/fingerprint。

### 6.2 runner 模式

`crates/consema-conformance/src/hcl_v1.rs` 完全对齐 `plist_v1.rs`：
- SUITE 常量 + include_str 嵌入；`run_hcl_v1()` / `run_hcl_v1_json()`；suite 标识校验；case id 去重。
- `capability` 分派：native-formation/tfvars-formation/query/projection/materialization/edit/limit 各一个处理器函数。
- limit case 在 runner 内分支（照 xml_v1.rs `run_limit` 体例：formation 类委托 + 非 formation 类扩展）。
- 测试：全量通过（`report.passed.len()` 断言，与向量同批更新）、suite id 篡改失败、输入篡改失败。

### 6.3 差分 oracle

- `scripts/run-hcl-go-oracle.ps1`：PowerShell 包装（manifest 校验 → runtime 事实校验（Go toolchain 版本与 digest、hcl commit）→ 逐 fixture 执行 → TSV 报告 → 退出码）。
- `conformance/oracles/hcl-go-v1/`：Go 驱动（`main.go` + go.mod/go.sum 钉版 hashicorp/hcl commit）——文档 fixture 走 `hclsyntax.ParseConfig`/`hclparse.ParseHCL`，表达式 fixture 走 `hclsyntax.ParseExpression`；输出 parse 接受/拒绝；**只比 parse outcome 与 Profile 的 Complete/Recovered outcome，绝不调 cty 求值**（§12）。
- `manifest.json`：钉版 commit、toolchain 版本与 digest、调用旗标、输入 digest、期望输出、排除清单——§12 的 9 条 divergence inventory（D-1..D-9，见 §7）逐条落表 + shape-level 排除（recovery-region 边界形状、duplicate-attribute 两 parser 都拒绝、attribute/block 同名共享 expected-no-divergence）+ Terraform loader 规则记录为 application-layer 行为（硬门禁 3）。**不允许 untracked allowlist**；差分分歧不得改 Consema 行为匹配（须走 RFC 或记录排除）。
- suite id `consema.hcl.go-differential@1`；Windows CI 无 Go runner 时按仓库 oracle 先例显式跳过并在 manifest 记录允许跳过路径。

## 7. 风险清单与实现阶段复核点

### 7.1 §12 divergence inventory 的实现对照点（9 条）

| # | 分歧 | 实现对照点 | 差分处理 |
|---|---|---|---|
| D-1 | 前导 BOM | oracle 静默 strip（`stripUTF8BOM`）；Consema Recovered + `hcl.parse.byte-order-mark@1`（§2）。SourceSnapshot 必须走 `TreatAsContent` 类 BOM policy，**不得** Strip/Detect 剥除；BOM 字节进 decoded text 由 lexer 以 ErrorRegion 收容（§7.2 无 Bom kind） | exclusion |
| D-2 | lone CR | oracle 拒绝（`Newline = '\r'? '\n'`）；Consema Recovered + `hcl.parse.lone-cr@1`。结果等价：两 parser 下 lone CR 永不进 Complete 文档 | exclusion（等价） |
| D-3 | invalid UTF-8 | oracle parse error；Consema `FatalFormationFailure` + `hcl.parse.invalid-utf8@1`（RFC 0012 §4 先例）。两者都拒收 | exclusion |
| D-4 | `_foo` 下划线开头标识符 | oracle 接受（scanner `Ident` 允许前导 `_`）；Consema 拒绝（UAX #31 `ID_Start` 排除 `_`）→ Recovered。unicode-ident 属性表必须给出与 spec 一致的 start 闭集；`_` 仍是 ID_Continue（`foo_bar` 合法） | exclusion |
| D-5 | `foo.0` 数字属性访问 | oracle 接受（HIL 遗留）；Consema 拒绝（`GetAttr = "." Identifier`）→ Recovered。TraversalStep 只收 Identifier | exclusion |
| D-6 | `foo::bar()` 命名空间函数 | oracle 接受；Consema 拒绝（`FunctionCall = Identifier "(" ...`）→ Recovered。lexer 的 `::` 不进 operator 集（`::` 是文法错误 token） | exclusion |
| D-7 | 单标识符 for-directive | oracle 接受（key 仅在逗号后读取）；Consema **冻结实现行为**：`%{ for x in list }` 合法（§4.4）。`HclForIntro.key: Option<...>` 支持此形 | 冻结实现行为，非 divergence |
| D-8 | heredoc closing-line 空白 | oracle 用 `bytes.TrimSpace` 匹配 closing line；Consema 冻结实现行为（§4.5）。实现**必须**接受 tabs 与尾随空白，比规范 "arbitrary spaces" 宽 | 冻结实现行为，非 divergence |
| D-9 | EOF 终止 body item | 实现接受 EOF 终止末 attribute/block/one-line（§4.2）；Consema 冻结实现行为。parser 的 newline 终止符在 EOF 处可选 | 冻结实现行为，非 divergence |

### 7.2 实现风险

| # | 风险/复核点 | 说明与缓解 | 复核时机 |
|---|---|---|---|
| R-1 | BOM 与 SourceSnapshot policy | HCL 是"BOM → Recovered 但源仍完整形成"的特殊契约（RFC 0012 的 Strip/Detect 语义都不适用）；需复核 consema-document 的 BOM policy 组合能否让 BOM 字节作为内容保留进 decoded text，否则需在 lexer 层对 raw 前导字节单独判定（3 字节 EF BB BF） | M2、M4 |
| R-2 | expression 恢复边界形状 | §3：表达式失败恢复区域 = 行尾（unterminated bracket 扩展至匹配 close 否则行尾；string 到行尾；heredoc 到 EOF 受 size 限制）。错误区域（ErrorRegion piece）与 `hcl.parse.*@1` diagnostic 一一对应；Recovered 后 body 从下一行恢复。形状与 oracle 内部恢复**不同**，shape-level exclusion 记录，向量不可反推 oracle 形状 | M3、M9 |
| R-3 | 解析递归与 expression depth | 对抗性深嵌套（`((((...`、`a+a+a+...`）必须被 `max_expression_depth` 预算在递归前截断（checked，非 panic、非栈溢出）——parser 递归与 literal-complete/结构相等/`hcl.expression@1` 编码共用同一预算语义 | M3、M6、M9 |
| R-4 | heredoc 处理细节 | `<<-` 缩进分析只读；TrimSpace closing-line 匹配含 tabs/尾随空白；marker 后跟内容不是 closing；`<<"EOT"` 拒绝；unterminated heredoc 的错误区域边界 = `max_heredoc_bytes`（§3、§11） | M2、M9 |
| R-5 | canonical decimal 归一化 | 纯十进制字符串运算（无浮点）；`max_number_digits` 限制 digit 数；`1e3 → 1000` 的 Integer/Decimal 投影判定以向量定格（§2.3）；材料化时 `1.50`/`15e-1` → `1.5`（§9） | M1、M6、M7、M9 |
| R-6 | `hcl.expression@1` ExtendedValue 编码 | 版本化 payload（kind + 原文 + structural fingerprint）需自定义 `ExtensionContract`（type_id `hcl.expression`、version 1、codec id 固定、`validate_canonical` 重解析比对）；投影写入与材料化读出必须同一 codec；reparse fingerprint 闭包是硬门禁 | M6、M7、M9 |
| R-7 | tfvars 顶层 block 在 Recovered 文档中的归属 | 推荐：block 保留为 Recovered 文档的 native item（§2.5，对照 duplicate-attribute "never a native attribute" 的排除仅因模型不变量）；实现阶段以向量复核该读法与 §3 "Recovered 保留每个独立证明构造" 一致 | M4、M9 |
| R-8 | keyword 双读与 for 歧义 | `true = 1` 合法 attribute name；`true` 作遍历根双读（§4.1）；tuple/object 首元素 `for` 的 for-expression 优先（§4.6）——三处都靠 kind + span 双保留，不需特殊分支 | M1、M3 |
| R-9 | consema-core 边界 | 只加 `QueryDomain` 两个构造器；`hcl.*` diagnostic codes 与查询 wire 契约不进 consema-protocol（§11）；`core.hcl-query-result@1` 留给后续 semantic-model 版本（RFC 头注 external-locator 模式） | M5、M10 |
| R-10 | 差分 runner 可用性 | Go toolchain 与 hcl commit 钉版；Windows CI 上脚本显式跳过并在 manifest 记录允许跳过路径（照仓库 oracle 脚本先例）；oracle fixture 必须避免依赖 Go parser 内部恢复形状（只比接受/拒绝） | M9、M10 |
| R-11 | `hcl.expression@1` 的 Transformed 报告 | 每替换一个 derived 表达式报一条 `Transformed`（value + expression provenance）；`max_report_events` 上限；no 其他变换（硬门禁 4） | M6、M9 |

## 8. 验收门禁总表（对照仓库既有体例）

| 门禁 | 体例来源 | 适用里程碑 |
|---|---|---|
| `cargo test -p consema-hcl` + clippy `-D warnings` + fmt + missing_docs | consema-plist 开发门禁 | 每个里程碑 |
| `cargo test --workspace` | 发布门禁 | M4 起每个里程碑 |
| `assert_exact_coverage` 穷尽覆盖断言（pieces 无空洞无重叠、kinds 平行） | ini/xml/plist tests 体例 | M2、M3 |
| 字节精确 `render() == source`（Complete 与 Recovered） | 全格式不变量（IMPLEMENTATION.md §2） | M2、M3、M4 |
| literal-complete 谓词与查询/投影/物化全矩阵一致 | RFC §8.1 | M5、M6、M7 |
| 重解析闭包（materialization 字节 → 重解析 → native 相等 + `hcl.expression@1` fingerprint） | xml/plist materialization 先例（RFC §9、§13） | M7 |
| 向量数据驱动（改期望必失败）+ suite id 检查 | conformance plist_v1.rs/xml_v1.rs tests | M9 |
| hardening 不 panic + 覆盖闭包 | tests/plist_hardening.rs | M9 |
| 生产夹具投影→物化→重解析不动点 | tests/xml_fixtures.rs | M9 |
| 差分 manifest 钉版 + §12 排除清单逐条落表（9 + 3 shape-level + application-layer） | scripts/run-*-oracle.ps1 + conformance/oracles/*/manifest.json | M9 |
| 全套 suite 计数（0.11.0：17 套全绿） | CHANGELOG/RELEASE 记录体例 | M10 |
| 打包/解包验证（14 个可发布 crate） | scripts/verify-package-archives.ps1 | M10 |
| 性能基线文档 BENCHMARKS-0.11.0.md | docs/BENCHMARKS-0.8.0.md 等 | M10 |
