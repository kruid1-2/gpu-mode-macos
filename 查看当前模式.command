#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "当前显卡切换设置："
/usr/bin/pmset -g | /usr/bin/grep -E "lowpowermode|gpuswitch" || echo "未检测到 lowpowermode 或 gpuswitch。"
echo
mode=$(/usr/bin/pmset -g | /usr/bin/awk '/gpuswitch/ { print $2; exit }')
low_power=$(/usr/bin/pmset -g | /usr/bin/awk '/lowpowermode/ { print $2; exit }')
case "$mode" in
  0)
    echo "模式：节能模式，优先使用 Intel 集成显卡。"
    ;;
  1)
    echo "模式：性能模式，强制使用 AMD 独立显卡。"
    ;;
  2)
    echo "模式：自动切换，由 macOS 自动决定。"
    ;;
  *)
    echo "模式：未识别。"
    ;;
esac
case "$low_power" in
  0)
    echo "低电量模式：关闭。"
    ;;
  1)
    echo "低电量模式：开启。"
    ;;
  *)
    echo "低电量模式：未识别或当前设备不支持。"
    ;;
esac
echo
echo "显卡硬件："
/usr/sbin/system_profiler SPDisplaysDataType | /usr/bin/grep -E "Chipset Model|Automatic Graphics Switching|Connection Type" | /usr/bin/sed 's/^/  /'
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
