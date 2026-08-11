
## 2026-08-12 — 三语言实现入库勘误

- commit 5cf680b 的 message 仅标注 fuzz 账本，但该 commit 实际同时携带了 TS/Python/Kotlin
  三语言 L0-L4 实现（typescript/ 533 文件、python/ 475 文件、kotlin/ 18467 文件，含 conformance
  runner 508/508 与 capability parity）；a0c318b 补充 .gitignore 排除 node_modules。
- 后记（5a040be purge 后）：上述 5cf680b 树计数（533/475/18,467）包含构建产物
  （node_modules、build/ 等，后被清理）；purge 后真实 tracked 文件数为 typescript/ 255、
  python/ 243、kotlin/ 229。5cf680b 树计数保留为当时提交树的历史事实（历史准确性声明不变）。
- 三语言 conformance：Python 508/508、TS 508/508、Kotlin 508/508（18 套 / digest 35bebc8d 共钉）。
