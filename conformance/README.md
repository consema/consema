# Consema 语言无关 Conformance Suites

本目录保存跨语言可复放的行为契约。向量只使用 strict JSON，二进制位模式、任意精度数字和 wire 结果使用字符串表示，避免宿主语言的数值模型改变预期事实。

当前 suite：

- `vectors/v1.json`：`consema.conformance@1`，覆盖 0.1.0 core、PVCE、JSON、query、projection 与 edit 基线，共 20 个 case；
- `vectors/toml-v1.json`：`consema.toml.conformance@1`，覆盖 `toml.1.0@1` 的 document、native items、query、projection、edit、limits 与真实工程语料，共 18 个 case；
- `vectors/protocol-v1.json`：`consema.protocol.conformance@1`，覆盖 15 个稳定 payload、canonical JSON/PVCE、registry/error code、process-local identity 拒绝与资源边界，共 32 个 case；
- `vectors/source-v1.json`：`consema.source.conformance@1`，覆盖 raw identity、五种 encoding、decoded location、binary coverage、SourcePatch 与资源失败，共 28 个 case；
- `vectors/syntax-query-v1.json`：`consema.syntax-query.conformance@1`，以共享案例覆盖 JSON/TOML lossless kind/text/order/selection/limit/cancellation 与 cursor terminal，共 19 个 case；
- `vectors/protocol-v2.json`：`consema.protocol.conformance@2`，覆盖 semantic-model v2 registry、SourceSnapshot/SourcePatch 双传输、伪造事实拒绝与 wire 后验证，共 11 个 case；
- `fixtures/toml/`：由向量按仓库相对路径引用的合法与非法 TOML 真实语料。

每个 case 固定包含：

- `id`：稳定测试身份；
- `capability`：被验证的版本化行为承诺；
- `input`：可直接重放的 source、fixture、profile、target 或 limit；
- `expected`：控制流和公开结果，不依赖本地化错误文本或内部 AST。

Rust runner 为：

- `consema_conformance::run_v1()`；
- `consema_conformance::run_toml_v1()`；
- `consema_conformance::run_protocol_v1()`；
- `consema_conformance::run_source_v1()`；
- `consema_conformance::run_syntax_query_v1()`；
- `consema_conformance::run_protocol_v2()`。

未来 Go 实现必须直接消费相同向量和 fixture。任何实现不得用序列化本地 AST、异常对象或第三方 parser 私有类型来替代向量中的公共字段。

新增或修改行为时，必须遵循：

1. capability 或 profile 的既有语义不变时，增加 case；
2. 既有语义发生不兼容变化时，创建新 suite/profile/operator version；
3. runner 只是执行器，向量和对应 RFC 才是跨语言事实；
4. 每个 suite 必须验证 case 数量，防止 runner 静默跳过未知项。
