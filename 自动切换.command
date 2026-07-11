#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "正在恢复自动显卡切换..."
echo "目标：由 macOS 根据负载自动选择集成显卡或独立显卡。"
echo

if ! /usr/bin/osascript <<'APPLESCRIPT'
do shell script "/usr/bin/pmset -a gpuswitch 2 && { /usr/bin/pmset -a lowpowermode 0 || true; }" with administrator privileges
APPLESCRIPT
then
  echo
  echo "切换命令没有全部执行成功。当前设备可能不支持显卡切换。"
fi

echo
echo "已恢复自动切换。"
echo "当前电源与显卡设置："
/usr/bin/pmset -g | /usr/bin/grep -E "lowpowermode|gpuswitch" || echo "未检测到 lowpowermode 或 gpuswitch。"
mode=$(/usr/bin/pmset -g | /usr/bin/awk '/gpuswitch/ { print $2; exit }')
low_power=$(/usr/bin/pmset -g | /usr/bin/awk '/lowpowermode/ { print $2; exit }')
if [[ "$mode" != "2" ]]; then
  echo "提示：当前设备可能不支持显卡切换，或系统拒绝了 gpuswitch 2。"
fi
if [[ "$low_power" != "0" ]]; then
  echo "提示：低电量模式未关闭，当前设备或电源状态可能不支持 lowpowermode。"
fi
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
