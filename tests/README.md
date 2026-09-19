# 验证脚本

建议使用 Godot 4.7.2。在仓库根目录打开终端，先完成资源导入：

```sh
godot --headless --path . --editor --import
```

将 `godot` 替换成电脑上的 Godot 可执行文件路径；Windows PowerShell 使用完整路径时，在引号前加 `&`。

## 当前界面回归入口

```sh
godot --headless --path . --script res://tests/verify_ui_ten.gd
godot --headless --path . --script res://tests/verify_speech_ten.gd
```

- `verify_ui_ten.gd`：四个导航入口、营业中购买、弹仓升级、冰箱内部货架、顶柜、气泡布局、音量设置恢复等，共 45 项断言。
- `verify_speech_ten.gd`：欢迎页和读订单页的真实按钮点击、16 步教学文本留白、单气泡显示、助手文字自适应，共 15 项断言。
- `verify_hunt_v10.gd`：三地区猎场、弹药升级及旧存档恢复的回归脚本。入口为 `godot --headless --path . --script res://tests/verify_hunt_v10.gd`，本次仓库整理未运行。

界面测试注入的是游戏画布坐标，`push_input(..., true)` 避免无头窗口尺寸变化造成误点。无头运行会跳过截图；需要截图时去掉 `--headless`，在可显示窗口的环境运行。

## 输出与存档隔离

所有测试结果、截图和临时存档都位于 Godot 的 `user://qa_*` 文件或目录，不再依赖特定盘符或仓库的上级目录。脚本会创建需要的输出目录。

当前两个界面脚本输出：

| 脚本 | 结果文件 | 临时存档 |
| --- | --- | --- |
| 界面与商店 | `user://qa_verify_ui_ten/界面商店验收.json` | `user://qa_verify_ui_ten_save.json` |
| 教学气泡 | `user://qa_verify_speech_ten/教学气泡补充验收.json` | `user://qa_verify_speech_ten_save.json` |

截图也保存在各自的 `qa_*` 目录。`user://` 可通过 Godot 编辑器的“项目 → 打开用户数据文件夹”找到，默认位置随操作系统而变化。测试使用专用临时存档，正常游玩的 `stall_save_v4.json` 不作为测试写入目标。单独运行同一套测试时，会更新该套测试的旧结果。

## 历史回归脚本

`scripts/verify*.gd` 保留开发过程中不同版本的检查，仅完成输出路径可移植化，**本次未逐个复测**；其中部分断言针对旧版玩法，不能视为当前版本全部通过的保证。

- `extends SceneTree` 的脚本可用 `--script res://scripts/脚本名.gd` 运行，例如 `verify_kitchen_v10.gd`、`verify_fixed_stove.gd`、`verify_kitchen_sequence.gd`、`verify_day_gifts_nine.gd`。
- `extends RefCounted` 的脚本需由游戏入口调用，不可直接传给 `--script`。现有命令行入口为：`godot --path . -- --qa`（交互）、`--qa-title`（标题流程）、`--qa-six`、`--qa-eight`、`--qa-nine`、`--qa-ten`。每次只选一个参数。
- `scripts/verify.gd`、`verify_v3.gd`、`verify_v4.gd` 是更早的历史用例，没有独立的当前命令行入口。
- `scripts/demo.gd` 通过 `godot --path . -- --demo` 启动演示，本次未复测演示流程。

旧版截图用例未全部适配无头模式，历史回归建议在可显示窗口的环境单独检查。

## 本次验证记录

2026-09-19，Windows / Godot 4.7.2，仓库副本首次导入成功。当前界面脚本 45/45、教学气泡脚本 15/15 通过，两个进程退出码均为 0；结果文件确认 `passed: true`。教学气泡进程退出时出现了 Godot 的对象/资源清理提示，此次未改动游戏退出流程。

本次仅验证上述界面与教学相关内容，没有重跑狩猎、厨房、完整营业与历史回归，也未进行窗口截图、导出包或跨平台验证。此次本机运行通过进程级 `APPDATA`、`LOCALAPPDATA`、`TEMP`、`TMP` 将运行日志和临时数据放在仓库外的 F 盘暂存目录；源码仍使用可移植的 `user://`。