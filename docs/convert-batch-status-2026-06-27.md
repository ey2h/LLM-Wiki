# KB 文档批量转换 — 后台跑批状态

> 创建于 2026-06-27
> 用途:把 `项目存档/<year>/` 下未转换的 .pdf/.doc/.docx/.ppt/.pptx/.xls/.xlsx/.txt/.log 转成 .md,放到 `LLM-WIKI/raw/<year>/` 下
> 命名规则:**原名.ext.md**(如 `RFI.pdf` → `RFI.pdf.md`)
> **状态**:🟢 跑批中(后台任务)

---

## 1. 跑批任务

| 项 | 值 |
|----|---|
| 脚本 | `~/LLM-Wiki/scripts/convert_archive_double_ext.sh` |
| 调用 | `bash convert_archive_double_ext.sh all` |
| 启动时间 | 2026-06-27 09:14 |
| 进程 PID | 75866 |
| session_id | `proc_c8c1779926f1` |
| 通知方式 | 完成自动通知 |

## 2. 范围

| 年份 | 未转文档数 | 备注 |
|------|----------:|------|
| 2012 | **跳过** | 已用 `原名.md` 规则跑过(convert_year_2012.sh,643 个 .md) |
| 2013 | 89 | |
| 2014 | 7(已实测通过) | 端到端验证:7 个文件全部成功 |
| 2015 | 324 | |
| 2016 | 0 | 已全转 |
| 2017 | 240 | |
| 2018 | 169 | |
| 2019 | 697 | |
| 2020 | 260 | |
| 2021 | 70 | |
| 2022 | 697 | |
| 2023 | 445 | |
| 2024 | 496 | |
| 2025 | 506 | |
| 2026 | 70 | |
| **合计** | **~4,070** | |

## 3. 工具栈(沿用 `convert_year_2012.sh`)

| 类型 | 工具 | 备注 |
|------|------|------|
| `.pdf` 文本版(avg char ≥ 30) | `pdftotext -layout` | 快 |
| `.pdf` 扫描版(avg char < 30) | MinerU(`mineru -p ... -o tmp`) | GPU,慢但准 |
| `.docx` / `.pptx` / `.xlsx` | markitdown | `/home/jack/projects/ai-rd-system/toolchain/envs/markitdown/bin/markitdown` |
| `.doc` / `.ppt` / `.xls` | LibreOffice → markitdown | LO 3 次重试,临时目录隔离 |
| `.txt` / `.log` | `cp` | 直接复制 |

**跳过扩展**:`dwg dxf bak jpg arw cr2 thm rar zip 7z tar gz bz2 cab exe dll msi ins bin mp4 mpg mp3 dat st7 lsl lsa bxs mpp dwl dwl2 sat lid ctb wmf themepack xmcd crdownload tmp`

**跳过规则**:
- `~$xxx` Office 临时文件
- `@eaDir/` Synology thumbnail
- `.DS_Store`
- 输出 `.md` 已存在 → 跳过(避免覆盖)

## 4. 关键决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 命名规则 | `原名.ext.md` | 你 2026-06-27 最新指示(覆盖 2026-06-26 的 `原名.md`) |
| 输出目录 | `LLM-WIKI/raw/<year>/` | 沿用 2012 脚本,与 NFS 已转文件并存 |
| 2012 是否重转 | 否 | 已用旧规则转过 643 个,改名意义不大 |
| Aurecon | 不动 | 你说"已转过的不转了",Aurecon 是另一来源 |
| 是否后台跑 | 是 | 4121 个文件估 2-4 小时,前台跑影响其他工作 |

## 5. 跟之前脚本的关系

| 脚本 | 关系 |
|------|------|
| `~/LLM-Wiki/scripts/convert_year_2012.sh` | **模板来源**(本脚本 90% 复用其逻辑) |
| `~/LLM-Wiki/scripts/convert.sh` | 通用版(默认 kb-source → kb-md),不适用本任务 |
| `~/LLM-Wiki/scripts/pdf_is_scanned.py` | **直接调用**(PDF 扫描判断) |
| `~/LLM-Wiki/scripts/rename_double_ext.py` | 反向归一(把 `.pdf.md` 改成 `.md`),本任务**不用** |
| `/mnt/nfs/LLM-WIKI/scripts/*.py` | NFS 备份版,无关 |

## 6. 进度查询命令

```bash
# 查看后台任务状态
process action=poll session_id=proc_c8c1779926f1

# 看最新日志
ls -lt /home/jack/projects/ai-rd-system/toolchain/logs/convert_*_double_ext_*.log | head -5
tail -50 <最新日志>

# 看 raw 各年新增的 .md 数
for y in 2013 2014 2015 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026; do
  cnt=$(find /mnt/nfs/LLM-WIKI/raw/$y -type f -name "*.md" 2>/dev/null | wc -l)
  echo "$y: $cnt .md"
done
```

## 7. 跑完后要做的事

1. **校验**:对照 `LLM-WIKI/raw/<y>/` 各年 `.md` 数 vs 项目存档下 `.pdf/.doc/.docx/.ppt/.pptx/.xls/.xlsx/.txt/.log` 文件数,看是否都覆盖了
2. **失败重试**:日志里 `⚠️ xxx failed` 的文件,用 `lo_retry_failed.sh` 重试
3. **写 log.md**:在 `~/LLM-Wiki/kb/log.md` 追加本次跑批记录
4. **commit 脚本**:把 `convert_archive_double_ext.sh` 提交到 git
5. **SKILL 1 跑全量**:用 `kb-doc-summary` 处理新增的 ~4,000 个 .md → 入 KB

## 8. 已知问题

| 问题 | 影响 | 缓解 |
|------|------|------|
| PDF 扫描判断阈值 30 字符 | 部分文档可能误判 | 跑完后人工抽查 |
| LO 处理中文路径偶发失败 | 3 次重试后跳过 | 走 `lo_retry_failed.sh` |
| MinerU 首次跑会下模型(~几百 MB) | 启动慢 | 已下载过,2014 跑时缓存命中 |
| NFS I/O 慢(50 万文件) | 总耗时可能 >4 小时 | 后台跑,可挂起 |

## 9. 跑完通知

完成时 terminal 会自动通知 → 届时我来:
1. 检查所有年的输出统计
2. 找失败文件
3. commit 新脚本 + 更新 log.md
4. 触发 SKILL 1 跑全量

---

**maintainer**: jack (via Hermes)
**created**: 2026-06-27
**updated**: 2026-06-27
**status**: draft(后台跑批中)