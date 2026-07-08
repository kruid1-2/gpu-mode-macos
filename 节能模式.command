#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "正在切换到节能模式..."
echo "目标：尽量只使用 Intel 集成显卡，降低功耗。"
echo

if ! /usr/bin/osascript <<'APPLESCRIPT'
do shell script "/usr/bin/pmset -a lowpowermode 1; /usr/bin/pmset -a gpuswitch 0" with administrator privileges
APPLESCRIPT
then
  echo
  echo "切换命令没有全部执行成功。当前设备可能不支持显卡切换。"
fi

echo
echo "已设置为节能模式。"
echo "当前电源与显卡设置："
/usr/bin/pmset -g | /usr/bin/grep -E "lowpowermode|gpuswitch" || echo "未检测到 lowpowermode 或 gpuswitch。"
echo
echo "提示：如果连接外接显示器，macOS 可能仍需要使用独立显卡。"
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
