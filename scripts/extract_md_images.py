#!/usr/bin/env python3
"""
extract_md_images.py — 把 markitdown --keep-data-uris 产出的 .md(内嵌 base64 data URI)拆成:

    <base>.ext.md            ← 顶层 schema Gate 主入口(无图时也是这个,目录留空占位)
    <base>.ext/              ← 附属资源目录(对齐 mineru vlm-engine 输出格式)
        ├── <base>.ext.md    ← md 内容,引用改成 images/<hash>.<ext> 相对路径
        └── images/<hash>.<ext>  ← 拆出来的图

用法:
    extract_md_images.py <md_file>

跟扫描 PDF (mineru vlm-engine 产物结构 <base>.pdf.md + <base>.pdf/) 完全一致,
Obsidian 渲染稳定。

注意:
    - 即便 md 没有任何 base64 图,也会建空目录 <base>.ext/(带 .gitkeep)
      保证 schema Gate 结构一致(扫描 PDF 无图时 mineru 也照样建子目录)
"""
import sys
import re
import hashlib
import base64
from pathlib import Path

# 匹配 ![](data:<mime>;base64,<payload>) — 也兼容 alt text
DATA_URI_RE = re.compile(
    r"!\[[^\]]*\]\(data:([^;,]+);base64,([A-Za-z0-9+/=]+)\)"
)


def mime_to_ext(mime: str) -> str:
    return {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/gif": "gif",
        "image/webp": "webp",
        "image/svg+xml": "svg",
    }.get(mime.lower(), "bin")


def main() -> int:
    if len(sys.argv) < 2:
        print(f"用法: {sys.argv[0]} <md_file>", file=sys.stderr)
        return 1

    md_path = Path(sys.argv[1]).resolve()
    if not md_path.is_file():
        print(f"❌ 不是文件: {md_path}", file=sys.stderr)
        return 1

    # 文件夹结构(对齐 mineru 格式):
    #   <base>.ext.md        ← 顶层 md(原文件保留)
    #   <base>.ext/          ← 附属资源目录
    #       <base>.ext.md    ← md 内容副本(引用改相对路径)
    #       images/<hash>.<ext>
    #
    # 命名:strip 掉 .md 后缀当目录名,即 <md_path>.parent / <md_path.stem>
    # 例:/dst/2012/中航/ZY.doc.md → /dst/2012/中航/ZY.doc/
    md_dir = md_path.parent / md_path.stem
    images_dir = md_dir / "images"
    new_md = md_dir / md_path.name

    content = md_path.read_text(encoding="utf-8", errors="replace")
    matches = list(DATA_URI_RE.finditer(content))

    # 始终建目录(对齐 mineru 格式,无图也建占位)
    md_dir.mkdir(parents=True, exist_ok=True)
    images_dir.mkdir(parents=True, exist_ok=True)

    if not matches:
        # 无图:md 副本放在子目录里(资源目录结构完整),顶层 md 保留
        new_md.write_text(content, encoding="utf-8")
        # 加 .gitkeep 占位,避免空目录被 git 忽略
        gitkeep = images_dir / ".gitkeep"
        if not gitkeep.exists():
            gitkeep.touch()
        print(f"  [EXTRACT-IMG] {md_path.name}: 0 images → {md_dir.name}/ (空目录占位)")
        return 0

    # 有图:去重 + 拆 base64
    seen: dict[str, str] = {}  # base64 → 相对路径
    for m in matches:
        payload = m.group(2)
        if payload in seen:
            continue
        mime = m.group(1)
        ext = mime_to_ext(mime)
        h = hashlib.sha256(payload.encode("ascii")).hexdigest()[:32]
        rel = f"images/{h}.{ext}"
        seen[payload] = rel
        out = images_dir / f"{h}.{ext}"
        if not out.exists():
            out.write_bytes(base64.b64decode(payload))

    # 替换 md 内容
    def repl(m: re.Match) -> str:
        return f"![]({seen[m.group(2)]})"

    new_content = DATA_URI_RE.sub(repl, content)
    new_md.write_text(new_content, encoding="utf-8")

    # 报告
    n_unique = len(seen)
    total_imgs = sum(
        1 for p in images_dir.iterdir() if p.is_file() and p.suffix != ".gitkeep"
    )
    size_kb = sum(
        p.stat().st_size for p in images_dir.iterdir()
        if p.is_file() and p.suffix != ".gitkeep"
    ) / 1024
    print(
        f"  [EXTRACT-IMG] {md_path.name}: "
        f"{n_unique} unique / {len(matches)} refs → "
        f"{total_imgs} files ({size_kb:.1f} KB) in {md_dir.name}/"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())