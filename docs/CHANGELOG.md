
## 2026-08-12 — 三语言实现入库勘误

- commit 5cf680b 的 message 仅标注 fuzz 账本，但该 commit 实际同时携带了 TS/Python/Kotlin
  三语言 L0-L4 实现（typescript/ 533 文件、python/ 475 文件、kotlin/ 18467 文件，含 conformance
  runner 508/508（增补前）与 capability parity）；a0c318b 补充 .gitignore 排除 node_modules。
- 后记（5a040be purge 后）：上述 5cf680b 树计数（533/475/18,467）包含构建产物
  （node_modules、build/ 等，后被清理）；purge 后真实 tracked 文件数为 typescript/ 255、
  python/ 243、kotlin/ 229。5cf680b 树计数保留为当时提交树的历史事实（历史准确性声明不变）。
- 三语言 conformance：Python 519/519、TS 519/519、Kotlin 519/519（18 套 / digest cfd6e296 共钉——2026-08-15 波 5 如实归正：共钉集合为 rs/go/py/kt 四 runner + 母仓作业，ts runner 的 digest 断言为永久 documented skip（CI 不 provision fc-manifest）；2026-08-12 P2-B 向量补强前为 508/508 / 35bebc8d）。
