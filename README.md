# Linux 系统状态自检脚本

一个面向 Debian / Ubuntu 及衍生发行版的一键系统体检脚本，普通用户也能看懂、会跑、能定位问题。

## 功能

运行后会对以下项目做检查，并用彩色 `[正常] / [注意] / [异常]` 标记结果：

- 基础信息（主机名、系统、内核、运行时间、负载）
- 内存与 Swap 使用情况
- CPU 温度（需安装 `lm-sensors`）
- 磁盘使用率与 inode
- **SSD 健康**：通电时间、累计写入、重分配扇区、温度、**剩余寿命**、SMART 总体（需 `smartmontools`）
- 误启的 Live-ISO 服务（`casper` 系列）
- `swappiness` 内核参数
- SSD TRIM 自动整理状态
- 待更新软件包数量
- 登录密钥环状态

## 环境要求

- 系统：Debian / Ubuntu 或其衍生版（Linux Mint 等）
- 工具：`bash`、`systemctl`、`smartctl`（可选，用于硬盘健康）
- 部分检测需要 root 权限

## 安装依赖（可选）

```bash
sudo apt update
sudo apt install -y smartmontools lm-sensors
```

## 使用方法

把脚本下载到本地后，用 sudo 运行：

```bash
sudo bash system-health-check.sh
```

执行时会提示输入密码（输入时屏幕不显示，属正常现象）。脚本会逐项打印检查结果。

## 示例输出

```
==============================================
        系统状态自检  2026-08-19 01:15
==============================================

--- 基础信息 ---
主机名:                         gw-MS-7C31
系统:                           Linux Mint 22.3
内核:                           7.0.0-29-generic
...

--- SSD 健康 (smartctl) ---
设备:                           /dev/sda
通电时间:                       21104 小时 (~2.4 年)
剩余寿命:                       24%
[注意] SSD 剩余寿命偏低，注意备份
SMART 总体健康: PASSED
...
```

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源，可自由使用与修改。
