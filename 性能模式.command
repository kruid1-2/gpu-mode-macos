#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "正在切换到性能模式..."
echo "目标：强制使用 AMD 独立显卡，提升图形性能。"
echo

if ! /usr/bin/osascript <<'APPLESCRIPT'
do shell script "/usr/bin/pmset -a gpuswitch 1 && { /usr/bin/pmset -a lowpowermode 0 || true; }" with administrator privileges
APPLESCRIPT
then
  echo
  echo "切换命令没有全部执行成功。当前设备可能不支持显卡切换。"
fi

echo
echo "已设置为性能模式。"
echo "当前电源与显卡设置："
/usr/bin/pmset -g | /usr/bin/grep -E "lowpowermode|gpuswitch" || echo "未检测到 lowpowermode 或 gpuswitch。"
mode=$(/usr/bin/pmset -g | /usr/bin/awk '/gpuswitch/ { print $2; exit }')
low_power=$(/usr/bin/pmset -g | /usr/bin/awk '/lowpowermode/ { print $2; exit }')
if [[ "$mode" != "1" ]]; then
  echo "提示：当前设备可能不支持显卡切换，或系统拒绝了 gpuswitch 1。"
fi
if [[ "$low_power" != "0" ]]; then
  echo "提示：低电量模式未关闭，当前设备或电源状态可能不支持 lowpowermode。"
fi
echo
echo "提示：性能模式会明显增加功耗和发热。"
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
