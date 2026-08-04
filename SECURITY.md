# Security and resource behavior

Consema 将资源上限作为执行策略，不把截断包装成成功：

- `ParseLimits` 限制 source、nesting、token/piece、node 和 diagnostic；
- `DecodeLimits` 限制 PVCE bytes、depth、nodes、container、integer 和 blob；
- `QueryLimits` 限制 step 与 result；
- `ProjectionLimits` 限制 value、report、provenance 和 depth。

超限分别返回 `FatalFormationFailure`、`DecodeError::ResourceLimit`、`QueryFailure::ResourceLimitExceeded` 或 failed projection。取消不会被报告为完成。

解析器和 decoder 禁止 `unsafe`，严格检查 UTF‑8、长度溢出、非最短 varint、非规范整数/Decimal、容器计数和嵌套深度。`consema-conformance` 包含恶意/边界 corpus 回归；如果发现 panic、无界分配或规范绕过，请附最小输入与触发的 capability contract 报告。

