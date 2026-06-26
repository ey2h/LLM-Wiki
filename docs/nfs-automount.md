# NFS Automount — z720 NAS systemd 配置

> **最后更新**: 2026-06-26
> **适用**: Ubuntu 24.04+ / systemd 254+

把 z720 NAS(192.168.1.101)NFS share `/fs/1000/nfs` 通过 systemd automount 挂到
`/mnt/nfs`,**按需挂载**(访问才挂,5 分钟不用自动 umount),**断网自动重连**,**重启自动恢复**。

## 为什么用 systemd automount 而不是 fstab

| 方案 | 优点 | 缺点 |
|------|------|------|
| `/etc/fstab` 静态 | 简单 | 重启时网络未就绪会卡死 / 断网后不会自动重连 |
| **systemd automount** ✅ | 按需挂 / 断网自动重连 / 网络未好不卡开机 | 配置稍复杂(2 个 unit) |
| autofs daemon | 老牌方案 | 多一个 daemon,systemd 已经接管了 |

## 1. NAS 信息

```text
服务器:    192.168.1.101
NFS 路径:  /fs/1000/nfs        (showmount -e 192.168.1.101 可查)
本地挂载:  /mnt/nfs
NFS 版本:  v3 + v4 都开(默认先 v4)
mountd:    9024
```

## 2. 落盘两个 unit

**文件 1: `/etc/systemd/system/mnt-nfs.mount`**

```ini
[Unit]
Description=NFS mount of z720 NAS (192.168.1.101:/fs/1000/nfs)
After=network-online.target
Wants=network-online.target

[Mount]
What=192.168.1.101:/fs/1000/nfs
Where=/mnt/nfs
Type=nfs
Options=defaults,_netdev,timeo=900,retrans=5,hard,intr,x-systemd.automount

[Install]
WantedBy=multi-user.target
```

**文件 2: `/etc/systemd/system/mnt-nfs.automount`**

```ini
[Unit]
Description=Automount /mnt/nfs on access
After=network-online.target

[Automount]
Where=/mnt/nfs
TimeoutIdleSec=300

[Install]
WantedBy=multi-user.target
```

## 3. 一键启用命令

```bash
sudo cp /tmp/mnt-nfs.mount /etc/systemd/system/mnt-nfs.mount
sudo cp /tmp/mnt-nfs.automount /etc/systemd/system/mnt-nfs.automount
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-nfs.automount

# 验证
ls /mnt/nfs/                         # 触发挂载
mount | grep nfs                      # 应该看到 systemd-1 type autofs 占位
systemctl status mnt-nfs.automount    # 检查 unit 状态
```

## 4. 行为验证

| 操作 | 预期结果 |
|------|----------|
| `ls /mnt/nfs/`(第一次) | systemd 自动 mount,NFS 内容可见 |
| `ls /mnt/nfs/`(5 分钟内) | 已挂载,直接显示 |
| 闲置 5 分钟 | systemd 自动 umount |
| `ls /mnt/nfs/`(再次) | 重新挂载 |
| 断网 | 客户端 `timeo=900` 超时后挂载失效,但不崩进程 |
| 网络恢复 + 访问 | 自动重连 |
| 重启系统 | automount unit 自动 enable,无需手动 |

## 5. 故障排查

### 5.1 挂不上

```bash
# 看 automount unit 状态
systemctl status mnt-nfs.automount
journalctl -u mnt-nfs.automount -n 50

# 手动触发 mount
sudo systemctl start mnt-nfs.mount
mount | grep nfs

# 测试 NFS server 可达
showmount -e 192.168.1.101
rpcinfo -p 192.168.1.101 | grep nfs
```

### 5.2 挂上了但读不出文件

```bash
# 看权限
ls -la /mnt/nfs/

# 试试 v3(默认可能走 v4 失败)
sudo mount -t nfs -o vers=3 192.168.1.101:/fs/1000/nfs /mnt/nfs
```

### 5.3 卡在 "device or resource busy"

```bash
# 谁在用
fuser -mv /mnt/nfs

# 强 umount
sudo umount -l /mnt/nfs
sudo systemctl restart mnt-nfs.automount
```

### 5.4 开机没自动 enable

```bash
# 检查是否 enable
systemctl is-enabled mnt-nfs.automount
sudo systemctl enable mnt-nfs.automount
```

## 6. 卸载配置

```bash
sudo systemctl disable --now mnt-nfs.automount
sudo systemctl disable --now mnt-nfs.mount
sudo umount /mnt/nfs 2>/dev/null
sudo rm /etc/systemd/system/mnt-nfs.{mount,automount}
sudo systemctl daemon-reload
```

## 7. 在 ai-rd-system 项目中的使用

转换脚本默认读 `$NFS = /mnt/nfs` 下的源文档:

```bash
# scripts/convert_year_2012.sh
NFS="/mnt/nfs"
SRC="$NFS/项目存档/2012"     # 原始文档(PDF/Word/Excel)
DST="$NFS/LLM-WIKI/raw/2012" # 转换后的 md
```

NAS 路径约定:
- `/mnt/nfs/项目存档/<year>/` — 项目原始文档
- `/mnt/nfs/LLM-WIKI/raw/<year>/` — 已转换的 md(给 SKILL 1 消费)
- `/mnt/nfs/LLM-WIKI/kb/` — 知识库产物(部分同步到 git)

## 8. 相关变更

| 日期 | 变更 | 作者 |
|------|------|------|
| 2026-06-26 | 初始 systemd automount 配置(NFSv3+v4, 5 分钟 idle umount) | jack (via Hermes) |

---

**maintainer**: jack
**status**: active