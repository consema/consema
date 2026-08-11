
## 2026-08-12 — 三语言实现入库勘误

- commit 5cf680b 的 message 仅标注 fuzz 账本，但该 commit 实际同时携带了 TS/Python/Kotlin
  三语言 L0-L4 实现（typescript/ 533 文件、python/ 475 文件、kotlin/ 18467 文件，含 conformance
  runner 508/508 与 capability parity）；a0c318b 补充 .gitignore 排除 node_modules。
- 三语言 conformance：Python 508/508、TS 508/508、Kotlin 508/508（18 套 / digest 35bebc8d 共钉）。
