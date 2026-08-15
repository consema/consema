# Security and resource behavior

Consema 将资源上限作为执行策略，不把截断包装成成功：

- `ParseLimits` 限制 source、nesting、token/piece、node、number digits 和 diagnostic；
- `DecodeLimits` 限制 PVCE bytes、depth、nodes、container、integer 和 blob；
- `ProtocolLimits` 同时限制 canonical JSON/PVCE 的 transport bytes、depth、nodes、container、integer 和 blob；
- `QueryLimits` 限制 step 与 result；
- `ProjectionLimits` 限制 value、report、provenance 和 depth；
- `SourceLimits` 限制 raw bytes、decoded UTF-8 bytes 与 scalar/location count；
- `SourcePatchLimits` 限制 result source、replacement count 与 patch bytes。
- `MaterializationLimits` 限制 input nodes/depth、output bytes、report entries 与 provenance entries。

超限分别返回 `FatalFormationFailure`、`DecodeError::ResourceLimit`、`QueryFailure::ResourceLimitExceeded` 或 failed projection。取消不会被报告为完成。

解析器和 decoder 禁止 `unsafe`，严格检查 UTF‑8、长度溢出、非最短 varint、非规范整数/Decimal、容器计数和嵌套深度。`consema-conformance` 包含 63 个恶意/边界对抗测试（hardening.rs 12 个、yaml_hardening.rs 5 个、line_formats_hardening.rs 6 个、xml_hardening.rs 10 个、xml_encoding_corpus.rs 7 个、plist_hardening.rs 7 个、hcl_hardening.rs 8 个、cli_hardening.rs 8 个——普通 `#[test]`，非 property-test 框架）；另 3 个文件（property_graph / property_plist / property_protocol）含 4 个 `proptest!` 属性测试块；如果发现 panic、无界分配或规范绕过，请附最小输入与触发的 capability contract 报告。（本段为 Rust 参考实现的内部细节：`unsafe` 禁令与对抗测试的分文件清单归属 consema-rs 仓，对应文件在 consema-rs/consema-conformance/ 下；语言无关安全行为以本文其余部分与 RFC 为准。）

canonical protocol JSON 拒绝空白、替代 escape、重排/未知字段和非最短数字表示；PVCE 继续拒绝非规范 varint 与整数。默认协议任意精度整数 magnitude 上限为 1 KiB，避免十进制转换的 CPU 放大；调用方提高上限时必须同时评估输入可信度和工作预算。任何 v1-v7 envelope payload 都会进入对应 typed decoder，不能只靠匹配 `schema` 绕过字段与交叉约束。v1-v7 registry 全部冻结（v7 增量为 additive；语义模型 v6 向量断言的是 v6 发布时点的 v1-v5 冻结，属历史快照）；JSON5 专属 diagnostic 从 semantic-model v4 起可外部化（92/132/166/187-code registry 均含对应代码——187 为 v7 现行冻结码，存在性实证见 `docs/fc-manifest-0.13.0.json` digests.contract_registry）。（本段 typed decoder、registry 冻结与 JSON5 diagnostic 外部化清单为 Rust 参考实现的内部细节，归属 consema-rs 仓；协议语义的规范权威是 RFC 0002/0015 与 conformance vectors，registry 计数语义见 `docs/fc-manifest-0.13.0.json`。）

`json5.standard@1` 只实现 Standard JSON5 数据文法，不求值 JavaScript，不执行表达式、import、getter、method、computed key、regex 或模板字符串，也不访问文件与网络。IdentifierStart/Continue 使用精确锁定的 `unicode-id-start 1.4.0` 表（精确锁定仅 Rust 参考实现成立；各语言仓为宿主语义，见各仓 SECURITY.md）。有限数字进入任意精度 Integer/Decimal；只有 `±Infinity`/`±NaN` 进入四种固定 binary64 位模式，有限 binary64 和任意 NaN payload 不能通过 JSON5 文本伪造 exact round-trip。非法 escape/identifier/number/comment 进入 recovery 或 fatal failure，不暴露伪造 native 值。（JSON5 v2.2.3 gate——43 valid、39 invalid 与一个完整真实夹具——与逐字节 mutation/截断/depth/token/node/source 上限验证在 consema-rs 仓执行：consema-rs/consema-conformance/；母仓无执行者，各语言实现侧的 JSON5 gate 状态见各语言仓 SECURITY.md/README。如实注记 2026-08-15：执行侧 gate 只断言 83 总数、无 43/39 构成守卫（consema-rs json_family_v2.rs 以总数为锚）；语料 valid/invalid 构成变更不会被门禁捕获，须人工复核。）

`core.source-snapshot@1` 解码时重算 digest、BOM/encoding resolution 与 decoded status；`core.source-patch@1` 解码时检查 replacement order/count/bytes，应用时再次检查 base/original/target/encoding。极端 offset、stale content、非法 UTF 序列和超限输出都在返回新 snapshot 前失败；redaction 只影响 review/debug presentation，不删除应用所需的字节前置条件。

Materialization 在递归与输出分配前计算 input node/depth 和增长上限，并对 report/provenance 独立计数；任一上限、不可表示值、unsupported policy 或 target reparse 失败时，结果中没有 Document 或 partial output。caller string 总由 target Profile 转义，materializer 不执行表达式、不解析 import、不访问文件或网络。

结构事务首先验证 snapshot、role、target/anchor、所有权、冲突、表示能力与资源预算，再构造并重新解析完整 candidate；失败不会改变 base，也不会返回 ChangeSet、proof 或 SourcePatch。`UntouchedByteProof` 覆盖全部且仅覆盖 replacement 外的旧/新字节，并绑定 base/target digest；任何 region、digest 或 target 篡改均失败。dry-run 与 commit 必须产生相同 replacements 和 target digest，但 plan 本身不授权文件写入。

raw `NodeRef`、snapshot handle、cursor 与 `CancellationToken` 不可序列化。需要 source/node identity 的 Diagnostic、Query、Provenance、ChangeSet、MaterializationResult 和 EditPlan 必须先绑定调用方稳定 locator；缺失绑定会失败，不会省略身份事实后伪造成功。

`toml.1.0@1` 只对完整合法文档形成 snapshot，非法输入返回 `FatalFormationFailure`（五语言限定：本句为语言无关承诺——各语言仓按宿主行为如实披露，见各仓 SECURITY.md；如 consema-py 对部分非法 TOML 输入抛裸异常并经 runner 泛化分类，其 SECURITY 如实披露该宿主行为）。`toml-lang/toml-test v2.2.0` 的 205 个 valid 和 474 个 invalid TOML 1.0 decoder cases 的记录载体是 `docs/UPSTREAM-TOML-TEST.md`（`scripts/run-toml-test.ps1` 为纯执行器、零写入命令，205/474 不在脚本内——2026-08-15 波 5 归正归属；脚本与记录在母仓、**无 CI job 执行**——六仓拆分后母仓根无 Cargo.toml，脚本在母仓原位不可执行，保留为记录载体；可执行入口的迁移/重建待总指挥决策，2026-08-14 波 2 处置）；上游版本变更必须单独审计。semantic edit 不会舍入 NaN payload、亚纳秒时间或非整分钟 offset 来伪造成功。

`xml.1.0-safe@1` 的 formation 只消费调用方提供的完整 document entity bytes，绝不打开外部 DTD、实体、URI、文件、网络连接、registry、classpath 或 catalog，也不提供用户 resolver 回调。DOCTYPE 仅允许 bounded internal subset；外部 subset、外部/参数实体、notation、conditional section 与 validation 声明一律恢复并发布稳定诊断。entity 膨胀按整个文档六维记账（declaration/reference 数量、expansion depth、expanded bytes/scalars、amplification ratio），任何一维突破即恢复；攻击无法把预算拆分到多个引用。内部 subset 注释按字符数据处理，其文本不会触发排除声明误报。UTF-16 输入必须携带 BOM；encoding 声明与实际编码冲突时恢复。恢复文档永不投影、物化或编辑；`xml.safe-canonical-document@1` materialization 对生成字节执行重解析闭包验证，失败返回无目标 Document。结构编辑不接收 raw markup，新内容一律 XML-escape；编辑不猜测或伪造 namespace 声明，unbound/reserved prefix、重复 expanded attribute、ancestor placement 与根删除均在 commit 前失败。XML 语法覆盖包含 37 种细粒度 kind，实体引用与属性部件均可被 lossless query 精确区分。

`plist.xml@1`/`plist.binary@1` 的 formation 只消费调用方提供的完整文档字节，绝不打开外部 DTD、实体、URI、文件或网络连接，不 fetch Apple DTD 或任何 URI，也不读环境/locale 状态或调用应用代码。XML 表示只按声明的 UTF-8/UTF-16 source contract 读取，binary 表示只解析 object table 与 offset-table/trailer 事实，XML 文档永不暴露 binary object/offset/ref/trailer 事实，binary 文档永不暴露文本 token/trivia。date、data 与 integer 不通过字符串降维；object reference、offset 与 size 计算在分配前检查溢出与资源限制。XML/binary 双表示 round-trip 转换对目标表示无法表达的原始事实（UID、Float32 width、未配对 surrogate、分数秒/越界日期等）原子失败并发布 `plist.conversion.inexpressible@1`，不产生部分目标文档。恢复文档永不投影、物化或编辑；`plist.xml-canonical@1`/`plist.binary-canonical@1` materialization 对生成字节执行重解析闭包验证，失败返回无目标 Document。对抗门禁覆盖 mutation/truncation/nesting/overflow 与 XML/binary 编码边界，验证无 panic、无无界分配、无 partial success。（对抗门禁的 panic/无界分配验证由各语言实现各自执行；Rust 侧实现细节归属 consema-rs 仓——consema-rs/consema-conformance/tests/plist_hardening.rs。）

`hcl.native@1`/`hcl.tfvars@1` 的 parse/query/project/edit 全程不求值：无 variable/function/template 求值与展开，`hcl.expression@1` 只承载语法事实、永不执行，无 application schema 与 Terraform/cty 语义。formation 只消费调用方提供的完整文档字节，不访问文件、网络、registry 或环境。表达式/模板/heredoc depth、number digits、item/label/attribute counts 与 recovery regions 等全部尺寸算术在分配前 checked，limit 失败绝不伪装成空 body、截断表达式或缩短查询。恢复文档可查询、不可 project/materialize/commit；`hcl.canonical-document@1` materialization 生成字节必先重解析并逐节点比较闭包语义，失败返回无目标 Document、无 partial bytes、无 partial provenance。对抗门禁覆盖 expression depth、template/heredoc size、number digits、body nesting 与 item counts 的极限输入，验证无 panic、无无界分配。（对抗门禁的 panic/无界分配验证由各语言实现各自执行；Rust 侧实现细节归属 consema-rs 仓，其余语言实现细节见各语言仓 SECURITY.md。）

依赖门禁由 `Cargo.lock`、精确锁定的 TOML/Unicode 依赖、RustSec `cargo audit` 和仓库级 `deny.toml`（随六仓拆分归 consema-rs 仓，2026-08-12）共同执行。`cargo deny check` 拒绝已知公告、未知 registry/Git 来源、通配版本和重复版本（重复版本按 bans 图口径：cargo-deny 分析排除 dev-dependencies 与 lockfile-only 包；Cargo.lock 现存 3 组 justified duplicates——getrandom 0.3.4/0.4.3、syn 2.0.119/3.0.3、r-efi 5.3.0/6.0.0——全部放行，与 deny.toml 注释一致），并只允许当前实际使用的 MIT/Apache-2.0/Unicode-3.0/BSD-3-Clause 四个许可证（deny.toml `[licenses] allow` 为权威；BSD-3-Clause 为 encoding_rs 0.8.35 实际使用）；任何例外都必须携带可审计理由进入版本控制。

## 安全披露与支持周期

安全披露、响应时间与支持窗口（路线图 §19.4 的"安全披露联系方式和支持周期"；缺陷等级沿用 §18.4，P0/P1 在 1.0.0 前不允许未解决，P2 必须逐项公开评审）。

**披露渠道。** GitHub 私有漏洞报告当前未启用（2026-08-14 gh api 实测 false）；启用后为首选渠道，启用前首选维护者邮箱 franckcl1989 &lt;franckcl@icloud.com&gt;。报告请包含：受影响的版本与 Profile/contract、触发问题的 capability contract（如 `core.source-snapshot@1`）、最小复现输入、以及你观察到的行为。发现 panic、无界分配或规范绕过时，也请携带上述信息报告（见上文 hardening 段）。披露遵循协调披露：收到报告后先确认再公开，不会在修复可用前公开细节；不承诺任何形式的赏金。供应链问题（依赖、SBOM、签名、CI）同样走此渠道。

**响应 SLA（按缺陷等级）。** P0（数据破坏、静默损失、RCE/外部访问、错误写文件、跨快照误编辑）：24 小时内确认，7 天内给出修复或缓解方案。P1（panic/crash/hang、错误完成状态、明显语义不一致、limit bypass）：72 小时内确认，14 天内修复。P2（有安全替代路径的功能缺陷、非核心性能回退、诊断位置错误）：随下一个发布窗口修复，发布判断逐项记录。P3（文档、易用性、非稳定 message、低风险边角）：尽力而为。任何等级都不得用降级测试或截断包装来"修复"；资源上限与完成状态语义是安全边界（见本文档开头部分），不能因披露而放松。

**支持窗口。** 1.0.0 发布前，安全修复只承诺两个窗口：最新稳定版本与其上一 minor（当前版本见 README `Version:` 行（本段避免硬编码版本串）——发布前窗口为当前 rc 版本与其前一 rc；尚无 GA 发布 tag）；更早版本不承诺修复，除非影响面证明必须回移。正式支持的目标是 CI 矩阵（windows-latest / ubuntu-latest / macos-latest；x86_64 + arm64——macOS 腿为 arm64，GitHub macos-latest 自 2024 起为 Apple Silicon 镜像；如实注记：macOS CI 腿仅 consema-rs 具备（lint/test 三 OS 矩阵），consema-go 的 macOS 腿明确 pending（G5.4），consema-ts/py/kt 三仓 CI 仅 ubuntu+windows，各语言仓支持目标以各仓 SECURITY 为准；与 RFC 0020 §9 及 support-policy §6 一致）；MSRV 窗口为 manifest 声明的 `rust-version`（当前 1.85）起的所有版本，MSRV 提升必须走 manifest 变更记录。Go 实现（0.14.0 起）的版本窗口在 Go RC 时按当时稳定生态冻结。TypeScript（`engines.node` >= 26，consema-ts/typescript/package.json 的 `engines` 字段）、Python（`requires-python` >= 3.12，consema-py/python/pyproject.toml 的 `requires-python` 字段）与 Kotlin（Kotlin 2.2.0 + JVM 17，consema-kt/kotlin/build.gradle.kts 的 Kotlin 版本与 `jvmToolchain` 字段）的版本窗口为各自 manifest 声明的最低版本起至当时 stable 工具链，CI 在钉定版本上验证（如实注记：TS 钉 26.7.0；Python CI 矩阵为 3.12.x / 3.13.x / 3.14.x 三 minor 线（ci-python.yml python-gates job，consema-py SECURITY 的「支持窗口」段——以字段锚 `requires-python >= 3.12` 为准，行号可能漂移——自述同口径）——均为各自 minor 线的最新补丁，声明的最低版本 26.0/3.12.0 未被按精确版本验证——"really verified in CI" 由构造满足只对 Kotlin 2.2.0 精确成立；详见 docs/support-policy.md 与 RFC 0020）；最低版本提升只在 minor 发生（五语言同等地位，2026-08-11 决策；完整政策见 docs/support-policy.md 与 RFC 0020）。公共 API 与 CLI 命令的弃用期至少一个 minor；contract/Profile 退役必须走 RFC 进程，已冻结的 v1-v7 registry 永不删除 code（G058 对齐，对抗审计 2026-08-14：旧文 v1-v6 漏 v7，consema-go SECURITY 同文已改），退役只改变新输入的接受行为并在发布记录中列明。
