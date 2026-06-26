#!/usr/bin/env python3
"""
kb/lint/schema_gate.py — KB 结构层评测(L1)

校验 KB 内所有概念页(不含 KB-META / CLAUDE / index / log):
1. frontmatter 必填字段齐(KB-META §1.1)
2. slug 唯一(全局不重名)
3. 跨引用 `[[/...]]` 格式正确
4. type 值在 KB-META §1.4 枚举内
5. type → 目录映射正确(例:type=Source 必须位于 kb/sources/)
6. description ≤ 200 字
7. tags 3-7 个
8. created/updated 是 ISO 8601 日期

输出:L1 结构层评测报告 + exit code(0=绿,1=红)
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from datetime import date
from collections import defaultdict

# KB 根目录(相对脚本位置)
KB_ROOT = Path(__file__).resolve().parent.parent.parent
KB_DIR = KB_ROOT / "kb"

# KB-META §1.1 必填字段
REQUIRED_FM = ["type", "title", "description", "created", "updated"]

# KB-META §1.4 type 枚举(ai-rd-system 用,OKF 兼容 — 未知值不阻塞)
VALID_TYPES = {
    "Schema",       # 灵魂层/规范
    "Concept",      # 业务/技术概念
    "Entity",       # 实体
    "Source",       # 文档摘要
    "Module",       # 模块
    "Class",        # 核心类
    "Query",        # 问答存档
    "Playbook",     # 流程性 SOP
    "Plan",         # 设计方案
    "PRD",          # 产品需求文档(Palantir 本体论风格)
}

# KB-META §1.4 type → 目录映射(只校验明确映射的 type,未列出的 type 跳过目录校验)
TYPE_TO_DIR = {
    "Schema":    "kb",                  # 灵魂层在 kb/ 顶层
    "Concept":   "kb/concepts",
    "Entity":    "kb/entities",
    "Source":    "kb/sources",
    "Module":    "kb/code/modules",
    "Class":     "kb/code/classes",
    "Query":     "kb/queries",
    "Playbook":  "kb/playbooks",
    "Plan":      "kb/plans",
    "PRD":       "kb/prds",
}

# 顶层 Schema 文件(不需要目录映射,允许位于 kb/ 根)
TOP_LEVEL_SCHEMA = {"KB-META.md", "CLAUDE.md", "index.md", "log.md", "README.md"}

# ISO 8601 日期校验(yyyy-mm-dd)
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# 跨引用格式(OKF bundle-relative 优先,Obsidian 风格也接受)
CROSS_REF_RE = re.compile(r"\[\[([^\]]+)\]\]")


def parse_frontmatter(text: str) -> tuple[dict | None, str]:
    """解析 YAML frontmatter(简单实现,只支持 key: value / key: [list])"""
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not m:
        return None, text
    fm_text = m.group(1)
    body = m.group(2)
    fm = {}
    current_list_key = None
    for line in fm_text.split("\n"):
        # 列表项
        list_item = re.match(r"^\s+-\s+(.+)$", line)
        if list_item and current_list_key:
            fm[current_list_key].append(list_item.group(1).strip().strip('"').strip("'"))
            continue
        # key: value
        kv = re.match(r"^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$", line)
        if kv:
            key, value = kv.group(1), kv.group(2).strip()
            if value == "" or value == "[]":
                # 可能是空 list,等下一行看
                fm[key] = []
                current_list_key = key
            elif value.startswith("[") and value.endswith("]"):
                # 内联 list:[a, b, c]
                items = [x.strip().strip('"').strip("'") for x in value[1:-1].split(",") if x.strip()]
                fm[key] = items
                current_list_key = None
            else:
                fm[key] = value.strip('"').strip("'")
                current_list_key = None
    return fm, body


def slug_from_path(path: Path) -> str:
    """从文件路径提取 slug(去 .md)"""
    return path.stem


def is_top_level(path: Path) -> bool:
    """是否在 kb/ 顶层(kb-META / CLAUDE / index / log / README)"""
    rel = path.relative_to(KB_DIR)
    return len(rel.parts) == 1


def check_file(path: Path) -> list[str]:
    """检查单个文件,返回错误列表"""
    errors = []
    rel = path.relative_to(KB_ROOT)

    # 跳过顶层 Schema 文件(它们是规范本身,不是被校验的产物)
    if path.name in TOP_LEVEL_SCHEMA and is_top_level(path):
        return []

    try:
        text = path.read_text(encoding="utf-8")
    except Exception as e:
        return [f"{rel}: 读取失败:{e}"]

    fm, body = parse_frontmatter(text)

    if fm is None:
        errors.append(f"{rel}: 缺 frontmatter(必须以 --- 开头)")
        return errors

    # 1. 必填字段
    for field in REQUIRED_FM:
        if field not in fm or fm[field] == "" or fm[field] == "[待补充]":
            errors.append(f"{rel}: 缺必填字段 '{field}'")

    # 2. type 必须是字符串(不是 list)
    type_val = fm.get("type")
    if isinstance(type_val, list):
        errors.append(f"{rel}: type 是 list,应为单值")

    # 3. type 值在枚举内(未知 type 不阻塞,只警告 — OKF Consumer MUST tolerate unknown)
    if isinstance(type_val, str) and type_val not in VALID_TYPES:
        # 不计入 errors,只 warn(下面单独输出)
        pass

    # 4. type → 目录映射
    if isinstance(type_val, str) and type_val in TYPE_TO_DIR:
        expected_prefix = TYPE_TO_DIR[type_val]
        # 文件路径必须以 expected_prefix/ 开头(对顶层 Schema 除外)
        rel_str = str(rel)
        if not rel_str.startswith(expected_prefix + "/") and rel_str != expected_prefix + "/" + path.name:
            # 特例:Schema 在 kb/ 顶层允许
            if not (type_val == "Schema" and is_top_level(path)):
                errors.append(
                    f"{rel}: type={type_val} 应位于 '{expected_prefix}/' 下,实际 '{rel.parent}/'"
                )

    # 5. description ≤ 200 字
    desc = fm.get("description", "")
    if isinstance(desc, str) and len(desc) > 200:
        errors.append(f"{rel}: description {len(desc)} 字,超过 200 字上限")

    # 6. tags 5-9 个(列表)— ai-rd-system 幕墙项目关键词天然多,SKILL 1 试跑发现
    tags = fm.get("tags")
    if tags is not None:
        if not isinstance(tags, list):
            errors.append(f"{rel}: tags 应是 list,实际 {type(tags).__name__}")
        elif len(tags) < 5 or len(tags) > 9:
            errors.append(f"{rel}: tags {len(tags)} 个,应在 5-9 个之间(幕墙项目天然关键词多,SKILL 1 试跑后调整)")

    # 7. created/updated 是 ISO 8601 日期
    for date_field in ["created", "updated"]:
        d = fm.get(date_field)
        if isinstance(d, str) and d and not ISO_DATE_RE.match(d):
            errors.append(f"{rel}: {date_field}='{d}' 不是 ISO 8601 日期(yyyy-mm-dd)")

    # 8. 跨引用格式(OKF bundle-relative: [[/sources/2012/xxx]])
    cross_refs = re.findall(r"\[\[([^\]]+)\]\]", body)
    for ref in cross_refs:
        # 允许 bundle-relative(/开头)或 Obsidian 风格(无/)
        if not (ref.startswith("/") or re.match(r"^[a-zA-Z0-9_-]+$", ref)):
            # 也允许中文 slug(无特殊字符)
            if not re.match(r"^[\u4e00-\u9fa5a-zA-Z0-9_/-]+$", ref):
                errors.append(f"{rel}: 跨引用 '[[{ref}]]' 格式不规范")

    return errors


def collect_concept_files() -> list[Path]:
    """收集所有概念页(kb/ 下所有 .md,排除 .git)"""
    files = []
    for md in KB_DIR.rglob("*.md"):
        # 排除 .git(虽然 KB_DIR 应该不会包含)
        if ".git" in md.parts:
            continue
        files.append(md)
    return sorted(files)


def check_slug_uniqueness(files: list[Path]) -> list[str]:
    """检查 slug 唯一性(全局文件名不重复)"""
    errors = []
    seen = defaultdict(list)
    for f in files:
        slug = f.stem
        rel = f.relative_to(KB_ROOT)
        seen[slug].append(str(rel))

    for slug, paths in seen.items():
        if len(paths) > 1:
            errors.append(f"slug 冲突 '{slug}': 出现在 {len(paths)} 个文件 — {paths}")
    return errors


def main() -> int:
    print("=" * 70)
    print("KB L1 结构层评测 — schema_gate.py")
    print(f"扫描目录: {KB_DIR}")
    print("=" * 70)

    files = collect_concept_files()
    print(f"\n发现 {len(files)} 个 .md 文件\n")

    if not files:
        print("⚠️  KB 为空,无文件可校验(返回 0 — 不阻塞,等首批 concept 写入)")
        return 0

    # 单文件校验
    all_errors = []
    type_unknown_warnings = []

    for f in files:
        # 顶层 Schema 不校验
        if f.name in TOP_LEVEL_SCHEMA and is_top_level(f):
            continue

        file_errors = check_file(f)
        all_errors.extend(file_errors)

        # type 未知警告
        try:
            text = f.read_text(encoding="utf-8")
            fm, _ = parse_frontmatter(text)
            if fm and isinstance(fm.get("type"), str) and fm["type"] not in VALID_TYPES:
                rel = f.relative_to(KB_ROOT)
                type_unknown_warnings.append(f"{rel}: 未知 type='{fm['type']}'(OKF 允许,但建议加入枚举)")
        except Exception:
            pass

    # slug 唯一性
    slug_errors = check_slug_uniqueness(files)
    all_errors.extend(slug_errors)

    # 输出报告
    print("--- 单文件校验 ---")
    if all_errors:
        print(f"❌ {len(all_errors)} 个错误:\n")
        for e in all_errors:
            print(f"  {e}")
    else:
        print(f"✅ 全部 {len(files)} 个文件通过 schema 校验")

    print()
    print("--- type 枚举警告 ---")
    if type_unknown_warnings:
        print(f"⚠️  {len(type_unknown_warnings)} 个未知 type(不阻塞,只是警告):\n")
        for w in type_unknown_warnings:
            print(f"  {w}")
    else:
        print("✅ 所有 type 都在已知枚举内")

    print()
    print("=" * 70)
    if all_errors:
        print(f"🔴 L1 结构层评测:红灯 — {len(all_errors)} 个错误")
        print("=" * 70)
        return 1
    else:
        print(f"🟢 L1 结构层评测:绿灯 — 全部 {len(files)} 个文件合规")
        print("=" * 70)
        return 0


if __name__ == "__main__":
    sys.exit(main())