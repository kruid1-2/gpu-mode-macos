#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "正在切换到节能模式..."
echo "目标：尽量只使用 Intel 集成显卡，降低功耗。"
echo

/usr/bin/osascript <<'APPLESCRIPT'
do shell script "/usr/bin/pmset -a gpuswitch 0" with administrator privileges
APPLESCRIPT

echo
echo "已设置为节能模式。"
echo "当前显卡切换设置："
/usr/bin/pmset -g | /usr/bin/grep gpuswitch
echo
echo "提示：如果连接外接显示器，macOS 可能仍需要使用独立显卡。"
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
