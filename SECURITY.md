# Security and resource behavior

Consema 将资源上限作为执行策略，不把截断包装成成功：

- `ParseLimits` 限制 source、nesting、token/piece、node 和 diagnostic；
- `DecodeLimits` 限制 PVCE bytes、depth、nodes、container、integer 和 blob；
- `ProtocolLimits` 同时限制 canonical JSON/PVCE 的 transport bytes、depth、nodes、container、integer 和 blob；
- `QueryLimits` 限制 step 与 result；
- `ProjectionLimits` 限制 value、report、provenance 和 depth。

超限分别返回 `FatalFormationFailure`、`DecodeError::ResourceLimit`、`QueryFailure::ResourceLimitExceeded` 或 failed projection。取消不会被报告为完成。

解析器和 decoder 禁止 `unsafe`，严格检查 UTF‑8、长度溢出、非最短 varint、非规范整数/Decimal、容器计数和嵌套深度。`consema-conformance` 包含恶意/边界 corpus 回归；如果发现 panic、无界分配或规范绕过，请附最小输入与触发的 capability contract 报告。

0.3.0 的 canonical protocol JSON 拒绝空白、替代 escape、重排/未知字段和非最短数字表示；PVCE 继续拒绝非规范 varint 与整数。默认协议任意精度整数 magnitude 上限为 1 KiB，避免十进制转换的 CPU 放大；调用方提高上限时必须同时评估输入可信度和工作预算。任何 envelope payload 都会进入对应 typed decoder，不能只靠匹配 `schema` 绕过字段与交叉约束。

raw `NodeRef`、snapshot handle、cursor 与 `CancellationToken` 不可序列化。需要 source/node identity 的 Diagnostic、Query、Provenance 和 ChangeSet 必须先绑定调用方稳定 locator；缺失绑定会失败，不会省略身份事实后伪造成功。

TOML 0.2.0 只对完整合法文档形成 snapshot，非法输入返回 `FatalFormationFailure`。发布门禁固定运行 `toml-lang/toml-test v2.2.0` 的 205 个 valid 和 474 个 invalid TOML 1.0 decoder cases；上游版本变更必须单独审计。semantic edit 不会舍入 NaN payload、亚纳秒时间或非整分钟 offset 来伪造成功。

依赖门禁由 `Cargo.lock`、精确锁定的 TOML 后端、RustSec `cargo audit` 和仓库级 `deny.toml` 共同执行。`cargo deny check` 拒绝已知公告、未知 registry/Git 来源、通配版本和重复版本，并只允许当前实际使用的 MIT/Apache-2.0 许可证；任何例外都必须携带可审计理由进入版本控制。
