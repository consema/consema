# Consema Conformance Suite @1

`vectors/v1.json` 是语言无关的 `consema.conformance@1` 向量集合。文件只使用 strict JSON，数值位模式、任意字节和 PVCE 结果使用十六进制字符串，避免宿主语言数值或二进制模型介入。

每个 case 固定包含：

- `id`：稳定测试身份；
- `capability`：被验证的版本化行为承诺；
- `input`：可重放输入；
- `expected`：控制流与公开结果，而不是本地化消息。

Rust runner 位于 `consema-conformance`。其他语言实现可以直接消费同一 JSON 文件；不应序列化本地 AST 或异常对象来替代这些字段。

