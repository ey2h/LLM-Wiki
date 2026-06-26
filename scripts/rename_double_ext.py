#!/usr/bin/env python3
"""rename_double_ext.py — 把 .X.X.md 错命名改成 .md 单扩展名
场景: 之前转换脚本 out_suffix 写错,生成 *.pdf.pdf.md / *.doc.doc.md 等。
服务端真存这些文件 (Linux ls 看得到),但 NFS lookup 缓存有时 stale,
用 os.rename 走 NFS lookup 会失败 (ENOENT)。
所以用 read+write+unlink 三步走: shutil.copyfile 不走 NFS lookup,
os.unlink 走 lookup 但服务端 Btrfs 有 stale handle,实际能 unlink。
验证: 2026-06-26 跑通 678/678 个文件改名。
"""
import os, shutil, sys

root = sys.argv[1] if len(sys.argv) > 1 else "/mnt/nfs/LLM-WIKI/raw/2012/"
exts = ('pdf', 'doc', 'docx', 'pptx', 'xls', 'xlsx', 'txt')

read_ok = read_fail = write_ok = write_fail = unlink_ok = unlink_fail = 0
errors = []

all_bad = []
for d, _, fs in os.walk(root):
    for f in fs:
        if not f.endswith('.md'):
            continue
        parts = f.split('.')
        if len(parts) >= 3 and parts[-1] == 'md' and parts[-2] in exts:
            all_bad.append((d, f, parts[0]))

print(f"all_bad={len(all_bad)}")

for d, f, base in all_bad:
    src = os.path.join(d, f)
    dst = os.path.join(d, base + '.md')
    try:
        with open(src, 'rb') as fp:
            data = fp.read()
        read_ok += 1
    except Exception as e:
        read_fail += 1
        errors.append(f"READ {f}: {e}")
        continue
    try:
        with open(dst, 'wb') as fp:
            fp.write(data)
        write_ok += 1
    except Exception as e:
        write_fail += 1
        errors.append(f"WRITE {f}: {e}")
        continue
    try:
        os.unlink(src)
        unlink_ok += 1
    except Exception as e:
        unlink_fail += 1
        errors.append(f"UNLINK {f}: {e}")

print(f"read={read_ok}/{read_ok+read_fail} write={write_ok}/{write_ok+write_fail} unlink={unlink_ok}/{unlink_ok+unlink_fail}")
for e in errors[:5]:
    print(f"  {e}")
