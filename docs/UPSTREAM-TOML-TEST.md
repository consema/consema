# Official TOML 1.0 compatibility gate

Consema 0.3.0 continues to pin the language-agnostic [`toml-lang/toml-test`](https://github.com/toml-lang/toml-test) suite at release `v2.2.0`, commit `ce08da1ddb075d1c7596d663c7fcba9a2ae02c5c`.

The pinned TOML 1.0 manifest contains:

- 205 valid decoder cases with tagged-JSON expectations;
- 474 invalid decoder cases that must return a non-zero status.

Last release-gate verification on 2026-08-04（如实注记：该次验证的完整输出无入库载体——205/474 为文档内唯一自证数字，上游 toml-test v2.2.0 语料不在仓内，无法复算；完整输出归档列为 1.0.0-rc 发布前置项）:

```text
toml-test v2.2.0 [consema-toml-test-decoder] [no encoder]
  valid tests: 205 passed, 0 failed
invalid tests: 474 passed, 0 failed
```

`consema-toml-test-decoder` reads TOML from standard input and produces the suite's tagged JSON exclusively through Consema's public `TomlItem`, `TomlEntry` and `TomlArrayElement` APIs. It does not expose or serialize `toml_edit` types.

> **记录载体注记（2026-08-14 波 2）**：六仓拆分后母仓根无 Cargo.toml/workspace，
> 本脚本只存在于母仓 `scripts/`（consema-rs 无副本），在母仓原位第一步
> `cargo build` 必然失败（exit 101），目前作为记录载体保留、无 CI job 执行；
> 可执行入口的迁移/重建待总指挥决策。下述运行说明为拆分前的可执行体例（保留
> 为历史记录）。

Run on Windows PowerShell:

```powershell
./scripts/run-toml-test.ps1
```

The script pins `v2.2.0`, builds the adapter from the locked Rust workspace, selects TOML 1.0 explicitly, and executes the official suite. Network access is needed only for the Go tool's first download; its module cache serves later runs.

An upstream version change is a reviewed dependency/conformance change. It must be committed separately with the new tag, commit, case counts, complete output, and any newly required Profile decision.
