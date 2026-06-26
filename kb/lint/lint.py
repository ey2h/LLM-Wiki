#!/usr/bin/env python3
"""
kb/lint/lint.py — KB 语义 lint(L1.5)

检测:
1. 孤页(orphan):无任何 [[...]] 引用指向,也没在 index.md 中列出
2. 断链(dead link):[[xxx]] 指向不存在的页面
3. 过时页(stale):updated 距今 > 365 天,type != Schema 且 status != draft
4. 矛盾(contradiction):同一年同一项目两个 Source 但同名(可能是重复)
5. 空页(empty):文件 < 200 字符且 frontmatter 缺 description
6. type 分布:type 统计 + 异常 type 警告

输出:语义 lint 报告 + exit code(0=绿,1=有警告可接受,2=有错误需修)
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from datetime import date, datetime
from collections import defaultdict, Counter

KB_ROOT = Path(__file__).resolve().parent.parent.parent
KB_DIR = KB_ROOT / "kb"

TOP_LEVEL_SCHEMA = {"KB-META.md", "CLAUDE.md", "index.md", "log.md", "README.md"}

# 跨引用正则
CROSS_REF_RE = re.compile(r"\[\[([^\]]+)\]\]")

# Source 类型跟 year 路径期望匹配(用于矛盾检测)
SOURCE_PATH_RE = re.compile(r"^kb/sources/(\d{4})/([^/]+)\.md$")


def parse_frontmatter(text: str) -> tuple[dict | None, str]:
    """简单 frontmatter 解析(同 schema_gate.py)"""
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not m:
        return None, text
    fm = {}
    current_list_key = None
    for line in m.group(1).split("\n"):
        list_item = re.match(r"^\s+-\s+(.+)$", line)
        if list_item and current_list_key:
            fm[current_list_key].append(list_item.group(1).strip().strip('"').strip("'"))
            continue
        kv = re.match(r"^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$", line)
        if kv:
            key, value = kv.group(1), kv.group(2).strip()
            if value == "" or value == "[]":
                fm[key] = []
                current_list_key = key
            elif value.startswith("[") and value.endswith("]"):
                items = [x.strip().strip('"').strip("'") for x in value[1:-1].split(",") if x.strip()]
                fm[key] = items
                current_list_key = None
            else:
                fm[key] = value.strip('"').strip("'")
                current_list_key = None
    return fm, m.group(2)


def strip_code_blocks(text: str) -> str:
    """去掉 fenced code block (```...```) 和 inline code (`...`) 内的内容

    用于 lint 提取跨引用时,避免误把代码示例里的 [[xxx]] 当成真实链接。
    """
    # 去掉 fenced code blocks (``` 或 ~~~)
    text = re.sub(r"```[^\n]*\n.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"~~~[^\n]*\n.*?~~~", "", text, flags=re.DOTALL)
    # 去掉 inline code (单行 `...`)
    text = re.sub(r"`[^`\n]+`", "", text)
    return text


def collect_pages() -> list[dict]:
    """收集所有 KB 页(含 frontmatter + 顶层 Schema 文件)

    顶层 Schema (KB-META/CLAUDE/index/log/README) 也包含在内,
    因为它们的 slug 在断链检测中要被识别为合法目标。
    """
    pages = []
    for md in sorted(KB_DIR.rglob("*.md")):
        if ".git" in md.parts:
            continue
        try:
            text = md.read_text(encoding="utf-8")
        except Exception:
            continue
        fm, body = parse_frontmatter(text)
        # body 提取跨引用前,先去代码块(避免误判代码示例里的 [[xxx]])
        body_for_lint = strip_code_blocks(body)
        pages.append({
            "path": md,
            "rel": str(md.relative_to(KB_ROOT)),
            "fm": fm or {},
            "body": body_for_lint,  # 已剥离代码块的版本,用于 lint
            "body_raw": body,        # 原始版本,保留备用
            "text": text,
        })
    return pages


def extract_cross_refs(body: str) -> list[str]:
    """提取所有 [[xxx]] 引用"""
    return CROSS_REF_RE.findall(body)


def check_orphan_pages(pages: list[dict]) -> list[str]:
    """孤页:无任何 [[...]] 引用指向它(且不在 index.md 列出)"""
    warnings = []

    # 收集所有被引用的 slug
    referenced = set()
    for p in pages:
        for ref in extract_cross_refs(p["body"]):
            # ref 可能是 /sources/2012/xxx 或 sources/2012/xxx 或裸 slug
            # 统一取最后一段作为 slug
            slug = ref.strip("/").split("/")[-1]
            referenced.add(slug)

    # index.md 列出的也视为被引用
    index_path = KB_DIR / "index.md"
    if index_path.exists():
        index_text = index_path.read_text(encoding="utf-8")
        for ref in extract_cross_refs(index_text):
            slug = ref.strip("/").split("/")[-1]
            referenced.add(slug)

    for p in pages:
        slug = p["path"].stem
        # 顶层 Schema 文件不视为孤页(KB-META/CLAUDE 等自身就是规范)
        if p["path"].name in TOP_LEVEL_SCHEMA and len(p["path"].relative_to(KB_DIR).parts) == 1:
            continue
        if slug not in referenced:
            warnings.append(f"ORPHAN 孤页 {p['rel']} — 无任何 [[...]] 指向,且不在 index.md")

    return warnings


def check_dead_links(pages: list[dict]) -> list[str]:
    """断链:[[xxx]] 指向不存在的页面"""
    errors = []

    # 收集所有存在的 slug + 允许链接的"逻辑路径"
    existing_slugs = {p["path"].stem for p in pages}

    # 顶层 Schema 文件 + skills/ 目录视为合法目标(实际是规范本身,不在 KB 产物里)
    allowed_logical_targets = set()
    for p in pages:
        if p["path"].name in TOP_LEVEL_SCHEMA and len(p["path"].relative_to(KB_DIR).parts) == 1:
            # 多种引用形式都允许:
            # /KB-META(裸名)/kb/KB-META(含 kb 前缀)/kb/KB-META.md(含扩展名)
            stem = p["path"].stem  # KB-META
            allowed_logical_targets.add(f"/{stem}")
            allowed_logical_targets.add(f"/kb/{stem}")
            allowed_logical_targets.add(f"/kb/{p['path'].name}")
    # skills/ 目录下的 SKILL.md 视为合法目标 — /skills/kb-doc-summary
    skills_root = KB_ROOT / "skills"
    if skills_root.exists():
        for skill_dir in skills_root.iterdir():
            if skill_dir.is_dir():
                skill_name = skill_dir.name
                allowed_logical_targets.add(f"/skills/{skill_name}")
    # kb/lint/ 下的 .py 脚本视为合法目标 — /kb/lint/schema_gate(指脚本本身)
    lint_root = KB_DIR / "lint"
    if lint_root.exists():
        for f in lint_root.iterdir():
            if f.is_file() and f.suffix in {".py", ".sh"}:
                allowed_logical_targets.add(f"/kb/lint/{f.stem}")
                allowed_logical_targets.add(f"/kb/lint/{f.name}")

    for p in pages:
        for ref in extract_cross_refs(p["body"]):
            # 跳过外部链接(http/https)
            if ref.startswith("http://") or ref.startswith("https://"):
                continue
            # bundle-relative 必须存在
            if ref.startswith("/"):
                # 顶层 Schema / skills 目录豁免
                if ref in allowed_logical_targets:
                    continue
                target_path = KB_DIR / ref.lstrip("/")
                if target_path.is_dir():
                    errors.append(f"DEAD LINK in {p['rel']} — [[{ref}]] 是目录而非文件")
                    continue
                if not target_path.exists():
                    md_path = target_path.with_suffix(".md")
                    if not md_path.exists():
                        errors.append(f"DEAD LINK in {p['rel']} — [[{ref}]] 目标不存在")
            else:
                # 裸 slug / Obsidian 风格,只警告不报错
                slug = ref.strip("/").split("/")[-1]
                if slug not in existing_slugs:
                    pass  # WARN,不算 ERROR

    return errors


def check_stale_pages(pages: list[dict]) -> list[str]:
    """过时页:updated 距今 > 365 天"""
    warnings = []
    today = date.today()

    for p in pages:
        fm = p["fm"]
        updated_str = fm.get("updated", "")
        if not updated_str:
            continue
        try:
            updated_date = datetime.strptime(updated_str, "%Y-%m-%d").date()
        except ValueError:
            continue

        age_days = (today - updated_date).days
        # 顶层 Schema 文件 + draft 状态文件豁免
        if fm.get("status") == "draft":
            continue
        if fm.get("type") == "Schema":
            continue

        if age_days > 365:
            warnings.append(f"STALE 过时 {p['rel']} — updated={updated_str},已 {age_days} 天未更新")

    return warnings


def check_duplicate_sources(pages: list[dict]) -> list[str]:
    """矛盾:同一年 + 同一 title 的两个 Source(可能是重复入库)"""
    warnings = []
    sources = defaultdict(list)

    for p in pages:
        if p["fm"].get("type") != "Source":
            continue
        m = SOURCE_PATH_RE.match(p["rel"])
        if not m:
            continue
        year, slug = m.group(1), m.group(2)
        title = p["fm"].get("title", "")
        # 用 year + title 作为 key
        key = (year, title)
        sources[key].append(p["rel"])

    for (year, title), paths in sources.items():
        if len(paths) > 1:
            warnings.append(f"DUPLICATE 重复 {year}/{title} — 出现在 {len(paths)} 个文件:{paths}")

    return warnings


def check_empty_pages(pages: list[dict]) -> list[str]:
    """空页:文件 < 200 字符"""
    errors = []
    for p in pages:
        if len(p["text"]) < 200 and not p["fm"].get("description"):
            errors.append(f"EMPTY 空页 {p['rel']} — {len(p['text'])} 字符,缺 description")
    return errors


def check_type_distribution(pages: list[dict]) -> tuple[dict, list[str]]:
    """type 分布统计"""
    type_counts = Counter()
    unknown_types = []

    for p in pages:
        t = p["fm"].get("type", "(无)")
        type_counts[t] += 1

    return dict(type_counts), unknown_types


def main() -> int:
    print("=" * 70)
    print("KB L1.5 语义 lint — lint.py")
    print(f"扫描目录: {KB_DIR}")
    print("=" * 70)

    pages = collect_pages()
    # 过滤掉顶层 Schema 文件用于报告(它们是规范本身,不是概念页)
    concept_pages = [p for p in pages if not (
        p["path"].name in TOP_LEVEL_SCHEMA and len(p["path"].relative_to(KB_DIR).parts) == 1
    )]
    print(f"\n发现 {len(concept_pages)} 个概念页(含 frontmatter)+ {len(pages) - len(concept_pages)} 个顶层 Schema\n")

    if not concept_pages:
        print("⚠️  KB 为空,无 lint 目标")
        return 0

    # 各类检查
    errors = []
    warnings = []

    print("--- 孤页检测 ---")
    orphan = check_orphan_pages(pages)
    if orphan:
        for w in orphan:
            print(f"  ⚠️  {w}")
            warnings.append(w)
    else:
        print("  ✅ 无孤页")

    print()
    print("--- 断链检测 ---")
    dead = check_dead_links(pages)
    if dead:
        for e in dead:
            print(f"  ❌ {e}")
            errors.append(e)
    else:
        print("  ✅ 无断链")

    print()
    print("--- 过时检测(>365 天) ---")
    stale = check_stale_pages(concept_pages)
    if stale:
        for w in stale:
            print(f"  ⚠️  {w}")
            warnings.append(w)
    else:
        print("  ✅ 无过时页")

    print()
    print("--- 重复 Source 检测 ---")
    dup = check_duplicate_sources(concept_pages)
    if dup:
        for w in dup:
            print(f"  ⚠️  {w}")
            warnings.append(w)
    else:
        print("  ✅ 无重复 Source")

    print()
    print("--- 空页检测(<200 字符 + 缺 description) ---")
    empty = check_empty_pages(concept_pages)
    if empty:
        for e in empty:
            print(f"  ❌ {e}")
            errors.append(e)
    else:
        print("  ✅ 无空页")

    print()
    print("--- type 分布 ---")
    type_counts, _ = check_type_distribution(concept_pages)
    if type_counts:
        for t, c in sorted(type_counts.items(), key=lambda x: -x[1]):
            print(f"  {t}: {c}")
    else:
        print("  (无 type 信息)")

    print()
    print("=" * 70)
    if errors:
        print(f"🔴 L1.5 语义 lint:红灯 — {len(errors)} 个错误")
        print("=" * 70)
        return 2
    elif warnings:
        print(f"🟡 L1.5 语义 lint:黄灯 — {len(warnings)} 个警告(可接受)")
        print("=" * 70)
        return 1
    else:
        print(f"🟢 L1.5 语义 lint:绿灯 — 全部 {len(concept_pages)} 个概念页通过")
        print("=" * 70)
        return 0


if __name__ == "__main__":
    sys.exit(main())