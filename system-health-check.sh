#!/bin/bash
# system-health-check.sh
# Linux 系统状态自检脚本（适用于 Debian / Ubuntu 及衍生发行版）
#
# 功能：一键检查 CPU 温度、内存/Swap、磁盘使用率与 inode、
#       SSD 健康(SMART)、误启服务、swappiness、TRIM、待更新包、登录密钥环。
#       结果以彩色 [正常]/[注意]/[异常] 标记输出。
#
# 用法：
#   sudo bash system-health-check.sh
# （部分检测需要 root 权限，请用 sudo 运行）

G="\033[32m"; Y="\033[33m"; R="\033[31m"; N="\033[0m"
ok(){ printf "${G}[正常]${N} %s\n" "$1"; }
warn(){ printf "${Y}[注意]${N} %s\n" "$1"; }
bad(){ printf "${R}[异常]${N} %s\n" "$1"; }
line(){ printf "%-34s %s\n" "$1" "$2"; }

echo "=============================================="
echo "        系统状态自检  $(date '+%Y-%m-%d %H:%M')"
echo "=============================================="

# 1. 基础信息
echo -e "\n--- 基础信息 ---"
line "主机名:" "$(uname -n)"
line "系统:" "$(. /etc/os-release 2>/dev/null; echo "$PRETTY_NAME")"
line "内核:" "$(uname -r)"
line "运行时间:" "$(uptime -p 2>/dev/null || uptime)"
line "负载(1/5/15):" "$(cut -d' ' -f1-3 /proc/loadavg | tr '\n' ' ')"

# 2. 内存 & swap
echo -e "\n--- 内存 / Swap ---"
mem=$(free -h | awk '/^Mem:/{print "总 "$2" 已用 "$3" 可用 "$7}')
sw=$(free -h | awk '/^Swap:/{print "总 "$2" 已用 "$3}')
line "内存:" "$mem"
line "Swap:" "$sw"
[ "$(free | awk '/^Swap:/{print $3}')" = "0" ] && ok "Swap 未使用" || warn "Swap 有占用"

# 3. CPU 温度
echo -e "\n--- CPU 温度 ---"
if command -v sensors >/dev/null; then
  t=$(sensors 2>/dev/null | awk -F'[:.+ ]' '/Package id 0/{print $4}')
  [ -n "$t" ] && line "CPU 封装温度:" "${t}°C" || line "CPU 温度:" "$(sensors | grep -m1 Core | tr -s ' ')"
else
  warn "未安装 lm-sensors (sudo apt install lm-sensors)"
fi

# 4. 磁盘使用
echo -e "\n--- 磁盘使用 ---"
df -h | awk 'NR==1 || /^\/dev\//{printf "  %-18s %5s %5s %5s %4s  %s\n",$1,$2,$3,$4,$5,$6}'
for p in / /home; do
  u=$(df --output=pcent "$p" 2>/dev/null | tail -1 | tr -d ' %')
  [ -n "$u" ] && { [ "$u" -gt 90 ] && bad "$p 使用 ${u}%" || ok "$p 使用 ${u}%"; }
done

# 5. inode
echo -e "\n--- Inode ---"
df -i / /home 2>/dev/null | awk 'NR>1{printf "  %-14s 已用 %s%%\n",$1,$5}'

# 6. SSD 健康 (需 sudo)
echo -e "\n--- SSD 健康 (smartctl) ---"
if command -v smartctl >/dev/null; then
  dev="/dev/$(lsblk -d -o name,type | awk '$2=="disk"{print $1; exit}')"
  life=$(sudo smartctl -A "$dev" 2>/dev/null | awk -F' *' '/SSD_Life_Left/{print $10}')
  poh=$(sudo smartctl -A "$dev" 2>/dev/null | awk -F' *' '/Power_On_Hours/{print $10}')
  reall=$(sudo smartctl -A "$dev" 2>/dev/null | awk -F' *' '/Reallocated_Event_Count/{print $10}')
  temp=$(sudo smartctl -A "$dev" 2>/dev/null | awk -F' *' '/Temperature_Celsius/{print $10}')
  wgb=$(sudo smartctl -A "$dev" 2>/dev/null | awk -F' *' '/Lifetime_Writes_GiB/{print $10}')
  line "设备:" "$dev"
  [ -n "$poh" ] && line "通电时间:" "${poh} 小时 (~$(awk "BEGIN{printf \"%.1f\",$poh/24/365}") 年)"
  [ -n "$wgb" ] && line "主机累计写入:" "${wgb} GiB"
  line "重分配扇区:" "${reall:-0}"
  [ -n "$temp" ] && line "温度:" "${temp}°C"
  if [ -n "$life" ]; then
    line "剩余寿命:" "${life}%"
    [ "$life" -le 10 ] && bad "SSD 剩余寿命过低，请备份并准备换盘" \
      || { [ "$life" -le 25 ] && warn "SSD 剩余寿命偏低，注意备份" || ok "SSD 剩余寿命正常"; }
  fi
  sudo smartctl -H "$dev" 2>/dev/null | grep -q PASSED && ok "SMART 总体健康: PASSED" || bad "SMART 总体健康: 未通过"
else
  warn "未安装 smartmontools (sudo apt install smartmontools)"
fi

# 7. 误启服务检查
echo -e "\n--- 误启服务检查 ---"
for s in casper.service casper-md5check.service; do
  st=$(systemctl is-enabled "$s" 2>/dev/null)
  if [ "$st" = "disabled" ] || [ "$st" = "masked" ]; then ok "$s: $st"; else bad "$s: $st (建议禁用)"; fi
done

# 8. swappiness
echo -e "\n--- 内核参数 ---"
sw=$(cat /proc/sys/vm/swappiness)
line "swappiness:" "$sw"
[ "$sw" -le 20 ] && ok "swappiness 偏低(优先用内存)" || warn "swappiness=$sw 可考虑调低"

# 9. TRIM
echo -e "\n--- SSD TRIM ---"
if systemctl is-enabled fstrim.timer >/dev/null 2>&1; then ok "fstrim.timer 已启用(自动Trim)"; else warn "fstrim.timer 未启用"; fi

# 10. 待更新
echo -e "\n--- 系统更新 ---"
up=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo 0)
if [ "$up" = "0" ]; then ok "无待更新包"; else warn "有 $up 个待更新包 (sudo apt upgrade)"; fi

# 11. 密钥环
echo -e "\n--- 登录密钥环 ---"
if [ -f "$HOME/.local/share/keyrings/login.keyring" ] || [ -f "$HOME/.local/share/keyrings/Default_Keyring.keyring" ]; then
  ok "密钥环文件存在 (若已设为空密码则不会弹窗)"
else
  warn "未发现标准密钥环文件"
fi

echo -e "\n=============================================="
echo "自检完成。"
echo "=============================================="
