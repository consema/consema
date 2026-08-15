# SHA256SUMS-0.8.0.txt 注记（2026-08-15 波 5 移入旁注文件）

本旁注与 `SHA256SUMS-0.8.0.txt` 同目录存放。2026-08-15 波 5 把原先写在
`SHA256SUMS-0.8.0.txt` 内的注记行移出：该文件格式契约是「每行
`<64 位小写十六进制>  <文件名>.crate`（双空格分隔，文件名无路径）」
（release-process-0.13.0.md §3），`scripts/release-sign.ps1` 的
Get-ManifestEntries 对任何不匹配该格式的非空行 throw——注记行使官方
校验命令无法解析该清单（波 5 修复；签名失效注记内容原样保留如下）。

## 签名失效注记（2026-08-15，波 4 R29）

- 本清单的签名对（`SHA256SUMS-0.8.0.txt.asc` clearsign +
  `SHA256SUMS-0.8.0.txt.sig` detached）因 2026-08-13 的内容编辑已不可验证
  ——按 docs/release-process-0.13.0.md §3.4 的消费者验证路径
  （gpg --verify .asc/.sig）对现行文件必然报 bad signature。
- 不重签不下架：文件与签名对仅作历史产物存档，签名失效不代表文件被篡改，
  而是注记编辑的已知后果。

## 预检产物注记（2026-08-13 如实披露）

- 本清单由 7e9de38（2026-08-07）dry-run 生成，构成与真实 v0.8.0 发布
  （tag f79dd99，2026-08-05）不符——含 consema-hcl/plist/xml
  （0.9.0-0.11.0 才新增的 crate），而真实 v0.8.0 树仅 12 目录/11 可发布；
  对 v0.8.0/9c1ede2/7e9de38 干净重建均无法复现（0/14 匹配，见
  rc-1.0.0-candidate.md D-1）。发布时须从干净发布 commit 重新生成。
