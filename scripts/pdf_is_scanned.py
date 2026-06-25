#!/usr/bin/env python3
"""
判断 PDF 是不是扫描件。
策略:抽 3 页(第 3 页、最后一页 / 2、前 3 ~ 后 3 中间页),统计字符数。
      < 阈值 → 扫描件 → 走 mineru
      ≥ 阈值 → 非扫描 → 走 markitdown
"""
import sys
import subprocess
import json
from pathlib import Path

# pdftotext 抽每页的字符数
def page_char_counts(pdf_path: Path, pages: list[int]) -> list[int]:
    """用 pdftotext -f -l 抽指定页"""
    counts = []
    for p in pages:
        try:
            result = subprocess.run(
                ["pdftotext", "-f", str(p), "-l", str(p), "-layout", str(pdf_path), "-"],
                capture_output=True, text=True, timeout=30
            )
            text = result.stdout.strip()
            counts.append(len(text))
        except Exception as e:
            counts.append(-1)
    return counts


def total_pages(pdf_path: Path) -> int:
    """pdfinfo 查总页数"""
    try:
        result = subprocess.run(
            ["pdfinfo", str(pdf_path)],
            capture_output=True, text=True, timeout=10
        )
        for line in result.stdout.splitlines():
            if line.startswith("Pages:"):
                return int(line.split()[1])
    except Exception:
        pass
    return 0


def is_scanned(pdf_path: Path, threshold: int = 50) -> dict:
    """
    判断 PDF 是不是扫描件。
    抽中间几页(第 3 / 总/2 / 倒数第 3)文本字符数,
    平均字符数 < threshold → 扫描件。
    """
    n = total_pages(pdf_path)
    if n == 0:
        return {"scanned": True, "reason": "pdfinfo failed", "pages": 0, "avg_chars": 0}

    if n <= 4:
        # 文档太短,逐页抽
        sample_pages = list(range(1, n + 1))
    else:
        # 第 3 / 中间 / 倒数第 3
        mid = n // 2
        sample_pages = sorted(set([3, mid, n - 2]))

    counts = page_char_counts(pdf_path, sample_pages)
    valid = [c for c in counts if c >= 0]
    avg = sum(valid) / len(valid) if valid else 0

    return {
        "scanned": avg < threshold,
        "pages": n,
        "sample_pages": sample_pages,
        "sample_char_counts": counts,
        "avg_chars": avg,
        "threshold": threshold,
    }


if __name__ == "__main__":
    pdf = Path(sys.argv[1])
    threshold = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    result = is_scanned(pdf, threshold)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(1 if result["scanned"] else 0)