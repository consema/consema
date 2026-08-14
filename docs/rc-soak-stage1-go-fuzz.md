# RC soak 阶段 1 — Go RC fuzz clean-run 重跑流程

- 依据：`docs/rc-1.0.0-candidate.md` §4 阶段 1（"Go 侧 release-candidate fuzz
  clean-run 记录 §22.4"）与 §4.1（"已有（2026-08-10，consema-go/go/README.md
  的「Fuzz targets」节，
  16 targets 各 30s，零 panic/hang/limit bypass）"——六仓拆分后该记录位于
  `consema-go/go/README.md` "## Fuzz targets" 节（clean-run 记录）
  在 :674-727）；
  路线图 §22.4 第 1909 行（release-candidate fuzz clean-run）。
- 目标：RC soak 阶段对 Go 16 个 fuzz target 各 30s 的 clean-run **重跑**并记录
  （对照 2026-08-10 基线：execs/30s 与 PASS），验证候选代码状态下零
  panic / hang / limit bypass。
- **本手册只含命令清单与记录模板；执行本身不在本准备批次内。**

## 1. 目标清单（16 targets，consema-go/go/README.md 的「Fuzz targets」节两个 target 表）

| Target | 包 | 断言属性 |
|---|---|---|
| `FuzzPVCE` | `core/` | 任意字节 → DecodePVCE：永不 panic；limit 语义不被绕过；decode→encode 定点（成功解码再编码 = 输入字节） |
| `FuzzPVCEEncodeDecode` | `core/` | 生成值 `decode(encode(x)) == x`，Equal 成立，re-encode 字节稳定 |
| `FuzzPGCE` | `graph/` | 任意字节 → DecodePGCE：永不 panic；limit 不被绕过；decode→encode 定点 |
| `FuzzPGCEEncodeDecode` | `graph/` | `decode(encode(g))` Equal g（含 sharing/cycles），re-encode 字节稳定 |
| `FuzzCanonicalJSON` | `protocol/` | 任意字节 → DecodeJSON：永不 panic；limit 不被绕过；decode→encode 定点 |
| `FuzzJSONEncodeDecode` | `protocol/` | canonical transport `decode(encode(x)) == x`，Equal 成立，re-encode 字节稳定 |
| `FuzzParse` | `json/` | strict/JSONC/JSON5 任意字节：永不 panic；render 闭包（字节精确）；status closed；Recovered → 诊断；诊断 ≤ MaxDiagnostics |
| `FuzzParse` | `toml/` | 任意字节 → TOML 1.0：永不 panic；render 闭包；恒 Complete 无诊断 |
| `FuzzParse` | `yaml/` | 任意字节 → YAML 1.2：永不 panic；render 闭包；alias 数 ≤ 源字节数 |
| `FuzzAlias` | `yaml/` | 生成 anchor/alias 文档：alias 数恰等于引用数；render 闭包 |
| `FuzzParse` | `ini/` | portable/Windows/Python profiles：永不 panic；render 闭包；Recovered → 诊断 |
| `FuzzParse` | `properties/` | 任意字节 → Java Properties reader：永不 panic；render 闭包；Recovered → 诊断 |
| `FuzzParse` | `xml/` | 任意字节 → `xml.1.0-safe@1`（entity 语料已播种）：永不 panic；render 闭包；entity 计数不被绕过 |
| `FuzzParseXML` | `plist/` | 任意字节 → `plist.xml@1`：永不 panic；render 闭包；Recovered → 诊断 |
| `FuzzParseBinary` | `plist/` | 任意字节 → `plist.binary@1`（Rust hardening 种子）：永不 panic；render 闭包；无伪 Complete |
| `FuzzParse` | `hcl/` | native/tfvars profiles（heredoc/template 种子）：永不 panic；render 闭包；Recovered → 诊断 |

资源上限全部固定为生产默认（`core.DefaultDecodeLimits` /
`graph.DefaultPGCELimits` / `protocol.DefaultProtocolLimits`）；**limit 失败是
pass 不是 crash**（与 Rust fuzz 契约同构，consema-go/go/README.md 的「Fuzz targets」节）。

## 2. 前置条件

| 项 | 要求 |
|---|---|
| 检出 | `consema-go` 检出（模块在 `go/` 下），工作树干净 |
| 工具链 | go 1.26.5（基线同款；go.mod 声明最低 1.26（0.14.0 冻结，RFC 0020 §9.2）——2026-08-12 曾临时下调 1.24 为实验状态，2026-08-13 已回正；CI go-matrix 腿为精确 1.26.0 + 1.26.5；基线记录用 go 1.26.5） |
| 环境 | 空闲或与 fuzz 驱动错峰（Go 本机 fuzz 用满核数；记录负载状态） |
| 时长 | 16 × 30s + 首次构建 ≈ 10-15 分钟 |

## 3. 命令清单（consema-go 检出，照 consema-go/go/README.md 的「Fuzz targets」节命令）

```text
cd go
go test -fuzz='^FuzzPVCE$'            -fuzztime=30s ./core/
go test -fuzz='^FuzzPVCEEncodeDecode$' -fuzztime=30s ./core/
go test -fuzz='^FuzzPGCE$'            -fuzztime=30s ./graph/
go test -fuzz='^FuzzPGCEEncodeDecode$' -fuzztime=30s ./graph/
go test -fuzz='^FuzzCanonicalJSON$'   -fuzztime=30s ./protocol/
go test -fuzz='^FuzzJSONEncodeDecode$' -fuzztime=30s ./protocol/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./json/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./toml/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./yaml/
go test -fuzz='^FuzzAlias$'           -fuzztime=30s ./yaml/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./ini/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./properties/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./xml/
go test -fuzz='^FuzzParseXML$'        -fuzztime=30s ./plist/
go test -fuzz='^FuzzParseBinary$'     -fuzztime=30s ./plist/
go test -fuzz='^FuzzParse$'           -fuzztime=30s ./hcl/
```

注意（go/README.md:653）：**锚定正则必须带 `^` `$`**——裸
`-fuzz=FuzzParse` 会匹配所有 `FuzzParse` 前缀 target 并拒绝运行。

## 4. 预期断言

- 每个 target：30s fuzz 后 `ok`/PASS，无 `panic`、无 `hang`、无 limit bypass
  （"limit bypass" = limit 失败被当作成功；limit 失败本身是 pass）。
- 每 target 的 `execs` 数与 2026-08-10 基线同数量级即可（机器/负载差异允许
  波动；**异常数量级（如骤降 10×）记录并说明**，不作 pass/fail 依据）。
- 新 crash 输入若产生，Go 会写入 `<pkg>/testdata/fuzz/<Target>/`——任何新文件
  即事件（§5 处置）。

## 5. 发现处置（新 crash 协议）

首个 clean-run 曾发现 4 缺陷并全部修复，失败输入已钉为回归种子（go/README.md:
674-727 clean-run 记录；回归种子实况：③ yaml plain-block 挂起钉入
yaml/testdata/fuzz/FuzzParse、④ plist.xml 恢复循环钉入 plist/testdata/fuzz/
FuzzParseXML 两个目录；① plist.binary trailer limit 伪 Complete 与 ②
json.strict.trailing-comma 分类为 fuzz target 内 f.Add 种子，无 testdata
目录——"每个失败输入钉入 testdata/fuzz/"对 4 缺陷中 2 个不成立）。
重跑若发现**新**输入：

1. 记录最小输入（`testdata/fuzz/` 新文件即最小输入）与 target；
2. 按路线图 §18.4 分级（P0/P1 = 立即报告；P2 = 记录并给发布判断）；
3. 修复后把输入钉为回归种子（保持 `testdata/fuzz/` 提交）并重跑该 target 30s；
4. clean-run 记录更新为修复后的状态（与 Rust 侧"新 crash 清零 target 计时"
   的账本语义对应——Go 侧以 clean-run 记录为准，无累计账本）。

## 6. 结果记录模板

```markdown
## RC soak 阶段 1 — Go RC fuzz clean-run 记录（YYYY-MM-DD）

- 环境：<OS/机器>；go <ver>；consema-go HEAD <commit>；负载状态：<…>
- 命令：cd go && 16 × `go test -fuzz='^<Target>$' -fuzztime=30s ./<pkg>/`（清单见 rc-soak-stage1-go-fuzz.md §3）
- 结果：

| Target | 包 | execs in 30s | 结果 |
|---|---|---|---|
| FuzzPVCE | core/ | <n> | PASS |
| …（16 行全量） | | | |

- 与 2026-08-10 基线对照：<execs 数量级同 / 差异项说明>
- 发现：<无；或逐条：输入 + target + 分级 + 处置 + 回归种子路径>
- 结论：<16/16 PASS，零 panic/hang/limit bypass；clean-run 记录成立>
```

诚实记录体例：execs 与 PASS 只取本次实际输出；任何非 PASS 或 panic/hang
即事件，按 §5 处置并记录，不重跑掩盖。

## 7. 相关文件

- `consema-go/go/README.md` :604-727（target 表、命令、2026-08-10 基线记录、
  4 缺陷与回归种子）
- `docs/rc-1.0.0-candidate.md` §4/§4.1（soak 计划与 Go 侧现状）
- `docs/fuzz-evidence-0.13.0.md` §2（Rust fuzz 契约与 limit-failure-is-pass 的
  对应口径）
