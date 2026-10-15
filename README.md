> 网页上传版：此仓库未包含超过网页单文件限制的 inklecate.exe。首次运行前，请从 [Ink v1.1.1 官方发布页](https://github.com/inkle/ink/releases/tag/v1.1.1) 下载 inklecate_windows.zip，将其中的编译器文件解压到 tools/inklecate/，再按下文启动。已包含正式 Ink 源文件及编译结果。

# 一小包罂粟 · Godot + Ink 叙事测试工程

工程入口：C:/Users/Antoine_Noir/Documents/GodotWhitebox/project.godot。Godot 导入窗口里选择这个文件，打开后按 F5。

当前工程使用 Godot 4 标准版、GDScript 和实际的 InkGD 运行时。对白、选项和剧情分支已迁移到 Ink；世界规则、数值和状态仍由框架统一处理。原 M1–M3 的移动、交互、六维、独立好感、线索、任务、阶段、换房间、结果、存读档和重置均保留。所有数值仅用于测试，画面仍是两个单屏灰盒房间。

## 打开与运行

本机验证版本：Godot 4.7.2.stable.official.ed1daf0bf，Windows 标准版，Compatibility 渲染器。无需切换到 .NET 版。InkGD 和 Windows Ink 编译器已随工程提供，无需再次下载插件。

1. 导入本目录的 project.godot，等待首次扫描完成。
2. 按 F5。工程中已启用的“编译 Ink 剧本”插件会先编译、检查剧本；失败时阻止运行，错误显示在 Godot 输出面板。
3. 以后改完 Ink，保存，停止旧运行实例，再按 F5。

也可在工程目录使用 PowerShell 执行：

    .\launch.ps1

启动脚本先编译 Ink 再运行游戏。显式指定引擎时：

    .\launch.ps1 -GodotPath 'C:\Users\Antoine_Noir\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

主场景是 scenes/main.tscn。Documents 根目录的旧工程、旧压缩包没有更新，请以 GodotWhitebox 子目录为准。

## 操作

| 操作 | 输入 |
| --- | --- |
| 左右移动 | A / D 或方向键 |
| 与最近对象交互、进门 | E |
| 选择对白 | 鼠标；或 Tab / Shift+Tab 切换焦点，Enter / Space 确认 |
| 关闭交谈、返回世界 | Esc |
| 人物好感列表和搜索 | 顶部“人物关系” |
| 调试、设定六维与好感 | F3 |
| 保存、读取、完整重置 | 顶部按钮或调试面板 |

默认窗口 1280×720，最小 960×540。对话与人物关系界面打开时暂停移动；对话中禁止存读档和改阶段，完整重置仍可用。Esc 关闭对话时保留已执行的动作。结果出现后可读取或完整重置。

保留深苔绿、暖白、金色的白盒 UI。对话支持同一段里的多个角色发言、长文滚动和选项滚动。顶部好感显示当前对象；所有 NPC 的独立好感放进可搜索的关系面板，不要求二十多人同时挤进 HUD。

## 当前剧情与测试路线

罗德里戈直接让金德日赫去偷罂粟。他以前用它麻醉过自己；马提亚斯修士认为继续这样会伤脑子，因此藏起了药。这是角色之间的矛盾。罗德里戈说话更直接，带不耐烦和自信，不再以腼腆求助的方式开口。修士也会说出自己藏药的原因。

“先拒绝，后行动”路线：

1. 在回廊与罗德里戈交谈，选择不替他偷东西，Esc 离开。
2. 到晚祷钟按 E 推进阶段。罗德里戈移到草药房。推进不要求答应、好感或检定成功。
3. 从右侧门进入草药房。最右侧草药柜按 E，先寻找藏药的位置。
4. 发现柜底暗格中的纸包后，再选择取走。搜索和取走是两个操作。
5. 离开柜子，调查笔记显示随身携带。此时可走动、换房间、保存、读取。
6. 走到罗德里戈身边，选择把纸包交给他。他会回应“你不是说不帮我吗？”。实际交付后好感固定 +5，修士好感不变。
7. 听完回应，再选择告别结束差事，进入交付结果。交付后提前 Esc 离开，重开仍可接着告别，但不能重复交药领奖。

属性检定路线：

- 初次选择“你用它麻醉自己？先把话说清楚……”得到慈悲 +20、罗德里戈好感 +20；选择“行，我替你找……”得到好感 +20，慈悲保持 0。
- 拾取回廊石凳旁的“修士的移药字条”。只有好感至少 20 且拥有字条，才开放私密追问。
- 慈悲 20 和慈悲 0 都能点击同一个追问选项。点击后才检定：前者成功，后者失败。
- 成功和失败都可以继续找药、取药、交药、告别；也可以在晚祷后当面确认不办差事，进入另一结果。
- 取药不等于交付；答应不等于必须交付；初次拒绝不会封锁后续行动。携带药包时最终不交付，结果也会明确纸包仍在身上。

修士有独立好感，一次整理标签固定 +5。随机开场只改变措辞，不发奖励。当前规模仍是两个 NPC、两个房间、一个线索、一项任务、两个阶段和两个结果；26 名 NPC 仅在自动测试中构造，不会挤进实际示例房间。

## 内容放在哪里

| 文件 | 修改内容 |
| --- | --- |
| story/quests/poppy_request.ink | 罗德里戈请求、私密追问、交付、拒绝及两种结果 |
| story/dialogues/herbalist.ink | 修士的对白与解释 |
| story/interactions/herb_cabinet.ink | 找药、取药与柜子的状态反应 |
| story/dialogues/ambient.ink | 可由多个角色共用的环境对话 |
| story/main.ink | 正式剧本入口，统一 INCLUDE 各剧情文件 |
| data/characters.json | 角色 ID、姓名、对话路由、初始好感、占位颜色 |
| data/story_rules.json | 对话入口优先级、开放条件、属性检定、固定数值效果、一次性键 |
| data/demo_content.json | 世界、阶段位置、任务、线索、目标提示和六维 |
| story/compiled/ | 编译产物与版本记录，自动生成，不手改 |
| story/preview/main.ink | 可在 Inky 打开的独立写作预览入口 |

具体写法、新增二十多个角色的方法、外部函数约定、示例和限制见 [Ink 写作与接入说明](docs/INK_AUTHORING.md)。新增剧情不需要为每个角色复制一套控制脚本；多名 NPC 共用同一对话系统和一个编译后的故事。

## 状态与存档

六维固定为革新、守成、虔诚、世俗、残酷、慈悲。属性与各 NPC 好感都是独立整数，可为负；好感增量完全取自配置，不乘属性系数。

GameState 是唯一 Autoload。每次选项先恢复 Ink 进度，在世界状态副本中执行动作，检定读取本次选择前的属性。全部合法后，世界状态、一次性键和 Ink 进度一起提交。错误时一起回退，重开对话、换房间、读取已领取后的存档均不会重复发奖。回读领取前的旧存档是整体回退，不会把旧奖励累加到当前进度。

单槽位置：user://whitebox_save.json，本机通常为：

    C:/Users/Antoine_Noir/AppData/Roaming/NarrativeWhitebox/whitebox_save.json

存档包含房间、出生点、阶段、六维、每个 NPC 好感、flags、线索、任务、一次性记录、结果，以及完整 Ink 状态（访问次数、变量、随机进度和执行游标）。保存按钮仅在交谈外可用；读取后回到房间出生点，重新交谈会按世界状态挑选入口，不恢复旧对话窗口或像素位置。

本次格式为 schema_version 2 / ink-demo-v1。旧 JSON 对话版存档明确拒绝读取，并保留原文件。编译后的 Ink 内容变化，也会拒绝读取旧构建的存档，避免把旧游标加载到错误段落。正式长期存档迁移尚未实现。只改注释且编译内容不变不会改变构建 ID；规则有破坏性变化时应同步更新 content_version。

完整重置清空世界与 Ink 进度、一次性记录和结果，恢复角色初始好感，但保留磁盘存档，方便再次读取。新进度点击保存会按单槽规则覆盖旧存档。自动测试使用独立槽位，不覆盖玩家存档。

## 验证与导出

实际执行结果、日志和未验证项见 [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)。

完整验证命令：

    .\tests\verify.ps1 -GodotPath '你的 Godot 标准版路径' -Graphical

也可分别运行：

    godot --headless --path . --script res://scripts/build_story.gd
    godot --headless --path . --script res://tests/test_runner.gd
    godot --headless --path . --script res://tests/ink_authoring_tests.gd
    godot --path . --script res://tests/gui_runner.gd

核心测试支持 -- --m1、-- --m2、-- --registry 子集。作者测试实际编译修改过的剧本副本、运行预览外部函数回退，并检查同次选择的奖励不倒灌进属性检定。图形测试会自动移动、点击、滚动和调整窗口，运行期间不要操作测试窗口。

Windows Desktop 导出预设已包含实际使用的场景、原始数据 JSON、Ink 源文件、编译 JSON 与运行时依赖。编译器、测试与 Inky 模拟层不进入游戏包。导出前先编译。Godot 导出的原始 JSON 必须保持 Keep File 模式，随工程提供了对应 .import 设置。

随工程提供源工程，没有另外制作独立 exe。其他操作系统编译时可设置 INKLECATE 指向对应平台的 inklecate 1.1.1；其他平台和 Godot 小版本尚未实测。依赖与许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
