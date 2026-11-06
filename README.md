# Coffee

极简 macOS 菜单栏防睡眠工具，基于 `caffeinate`。灵感来自 [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)。

- 左键：切换激活 / 停用
- 右键（或 ⌥ 左键）：菜单（允许显示器睡眠、合盖时保持唤醒、开机启动、退出）

## 构建与安装

```bash
mise run install   # 构建并安装到 /Applications
```

## 合盖时保持唤醒

依赖 `sudo pmset -a disablesleep 1`，需要先加一条只放行这两条命令的免密规则：

```bash
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1" | sudo tee /etc/sudoers.d/coffee
sudo chmod 440 /etc/sudoers.d/coffee
```

停用或退出时会自动还原。若 App 被强杀，下次启动时也会还原；也可手动执行 `sudo pmset -a disablesleep 0`。
