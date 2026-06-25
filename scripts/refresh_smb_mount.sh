#!/bin/bash
# refresh_smb_mount.sh
# 确保 z720 SMB share 通过 gvfs 挂载,如果没挂就提示用户去 file manager 点一下
# 用法: bash scripts/refresh_smb_mount.sh
set -e

G="/run/user/1000/gvfs/smb-share:server=z720.local,share=jack%20共享给我"
PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== 检查 gvfs SMB 挂载 ==="
if [ ! -d "$G" ]; then
    echo "❌ SMB 没挂: $G 不存在"
    echo ""
    echo "挂载方法(任选其一):"
    echo "  A. 图形桌面:打开 Files → 左侧栏 → 点 'z720... 给我' (Nemo/Nautilus 会自动挂载)"
    echo "  B. 命令行:"
    echo "       sudo apt install -y cifs-utils"
    echo "       sudo mkdir -p /mnt/z720"
    echo "       sudo mount -t cifs //192.168.1.101/项目存档 /mnt/z720 \\"
    echo "         -o username=jack,vers=3.0,uid=1000,gid=1000,iocharset=utf8"
    echo ""
    echo "挂好后重跑此脚本。"
    exit 1
fi

echo "✅ SMB 已挂: $G"
echo ""
echo "=== 内容预览 ==="
ls "$G" | head -10
echo ""

# 重建符号链接(防止之前是断链或改了路径)
echo "=== 重建 kb-source 符号链接 ==="
ln -sfn "$G/项目存档" "$PROJ_ROOT/kb-source/z720-archives"
ln -sfn "$G/Projects"   "$PROJ_ROOT/kb-source/z720-projects"

echo "✅ 符号链接:"
ls -la "$PROJ_ROOT/kb-source/z720-archives" "$PROJ_ROOT/kb-source/z720-projects"
echo ""
echo "=== 验证 ==="
echo "--- z720-archives (前 5 项) ---"
ls "$PROJ_ROOT/kb-source/z720-archives" 2>&1 | head -5
echo "--- z720-projects (前 5 项) ---"
ls "$PROJ_ROOT/kb-source/z720-projects" 2>&1 | head -5