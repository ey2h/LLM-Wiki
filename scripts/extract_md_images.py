#!/usr/bin/env python3
"""
extract_md_images.py — 把 markitdown --keep-data-uris 产出的 .md(内嵌 base64 data URI)拆成:
  <base>.ext.md/
    ├── <base>.ext.md        ← md(引用改成 images/<hash>.<ext>)
    └── images/<hash>.<ext>  ← 拆出来的图

用法:
  extract_md_images.py <md_file>

跟扫描 PDF(mineru vlm-engine 产物)结构一致,Obsidian 渲染稳定。
"""
import sys
import re
import hashlib
import base64
import shutil
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

    # 文件夹结构: <base>.ext.md/<base>.ext.md + images/
    # 即 md 移进同名子目录,变成 <base>.ext.md/<base>.ext.md
    # 跟扫描 PDF mineru 产物结构对齐
    md_dir = md_path.parent / (md_path.name + ".d")
    images_dir = md_dir / "images"
    new_md = md_dir / md_path.name

    content = md_path.read_text(encoding="utf-8", errors="replace")
    matches = list(DATA_URI_RE.finditer(content))
    if not matches:
        # 没图,清掉空目录
        return 0

    md_dir.mkdir(parents=True, exist_ok=True)
    images_dir.mkdir(parents=True, exist_ok=True)

    # 去重(同一 base64 重复引用 → 同一 hash 文件)
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
    # 删旧的顶层 md
    md_path.unlink()

    # 报告
    n_unique = len(seen)
    total_imgs = sum(
        1 for p in images_dir.iterdir() if p.is_file()
    )
    size_kb = sum(
        p.stat().st_size for p in images_dir.iterdir() if p.is_file()
    ) / 1024
    print(
        f"  [EXTRACT-IMG] {md_path.name}: "
        f"{n_unique} unique / {len(matches)} refs → "
        f"{total_imgs} files ({size_kb:.1f} KB)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
