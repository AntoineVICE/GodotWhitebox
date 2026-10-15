# Godot 占位框架：实现规格与 Codex Prompt

版本：v0.1 · 2026-09-24

目标：交付能在 Godot 中打开并运行的叙事游戏框架。移动、交互、对话、状态变化、条件判断、场景切换、存读档真实运行；人物、场景、美术和文字全部使用占位符。

这是供 Codex 实现的规格，不是已经完成或经过引擎运行验证的工程。

## 1. 第一版边界

| 项目 | 本次实现 |
| --- | --- |
| 引擎 | Godot 4.x 标准版、GDScript；以开发机实际安装的 4.x 小版本为准，并记录版本 |
| 画面 | 2D 平视；默认 1280×720、固定镜头；矩形、色块、标签构成画面 |
| 移动 | 白盒暂用左右移动、固定地面高度；不加跳跃与重力；这是可替换的测试方案，不代表正式游戏只能左右移动 |
| 测试规模 | Room_A、Room_B 两个单屏房间；NPC_A、NPC_B 两个占位人物；一个线索物体；一个阶段控制物体；一个结算物体 |
| 系统 | 交互、分支对话、六维属性、独立好感、条件判断、线索、简单任务、阶段切换、NPC 阶段位置、占位结果、单槽存读档、重置、调试面板 |
| 内容 | TEST_LINE、TEST_CHOICE、CLUE_A 等测试文字；不编写正式剧情、杀鱼流程或人物设定 |
| 不做 | 战斗、背包装备、经济、技能树、地图导航、NPC 寻路、实时日程、正式动画音效、对话编辑器、多语言系统、插件框架 |

第二个房间只用于验证换场景、NPC 位置变化和状态保留，不增加第二段剧情。所有数值与阈值均为 TEST_ONLY 测试数据，不是正式平衡方案。

## 2. 必须保留的玩法规则

1. 六个属性：革新 `innovation`、守成 `tradition`、虔诚 `piety`、世俗 `secularity`、残酷 `cruelty`、慈悲 `mercy`。
2. 六个值第一版独立保存，不自动推导对立关系。初始值全部为 0，不擅自添加上限、下限或此消彼长公式。
3. 属性检定在玩家选择后发生。低属性玩家仍能看见并选择检定选项，随后进入失败分支；不能把属性阈值做成该选项的显示或点击门槛。
4. 私密话题用“NPC 好感达到要求”与“剧情前置成立”的组合条件开放。第一版用获得 CLUE_A 作为剧情前置占位。
5. 每个 NPC 的好感独立保存。好感变化取配置中的固定增减值，不乘属性系数，也不从属性值自动计算。
6. 第一版使用确定性的阈值检定：选择前状态的属性值 >= 配置阈值即成功。正式公式以后可以替换，第一版不加随机骰子。
7. 一次性选择、线索和奖励不可通过重开对话、换房间或读档反复领取。

## 3. 工程结构

以下是建议的具体拆分。可以因现有项目调整文件位置，但保留职责边界，不增加功能范围。

```text
project.godot
GODOT_FRAMEWORK_SPEC.md
README.md
IMPLEMENTATION_STATUS.md
data/demo_content.json
scenes/main.tscn
scenes/player.tscn
scenes/interactable.tscn
scenes/rooms/room_a.tscn
scenes/rooms/room_b.tscn
scenes/ui/dialogue_panel.tscn
scenes/ui/debug_panel.tscn
scripts/main.gd
scripts/game_state.gd
scripts/content_db.gd
scripts/condition_evaluator.gd
scripts/effect_executor.gd
scripts/dialogue_runner.gd
scripts/world_controller.gd
scripts/player.gd
scripts/interactable.gd
scripts/save_service.gd
scripts/ui/dialogue_panel.gd
scripts/ui/debug_panel.gd
tests/test_runner.gd
```

### 场景节点

| 节点路径 | Godot 类型 | 职责 |
| --- | --- | --- |
| `/root/GameState` | Autoload Node | 唯一运行时状态来源；切换房间时保留 |
| `Main` | Node | 初始化依赖、连接信号、控制输入状态 |
| `Main/World` | Node2D | 挂载 WorldController，管理房间装卸与 NPC 放置 |
| `Main/World/RoomRoot` | Node2D | 同一时刻只挂载一个 Room 场景 |
| `Main/World/Player` | CharacterBody2D | 移动、碰撞、交互候选检测 |
| `Main/DialogueRunner` | Node | 对话游标、选项提交、检定和结束流程 |
| `Main/UI` | CanvasLayer | 固定屏幕 UI |
| `Main/UI/DialoguePanel` | Control | 显示说话者、文本与按钮；向 Runner 提交选项 ID |
| `Main/UI/DebugPanel` | Control | 展示状态、测试修改、保存、读取、重置 |
| `Main/UI/InteractionHint` | Label | 当前对象与 E 交互提示 |
| `Main/UI/ResultPanel` | Control | 显示 OUTCOME_A / OUTCOME_B 及重置按钮 |

每个 Room 场景有占位背景、左右边界、`Markers`（Marker2D 出生点和 NPC 位置）、`Actors`（运行时 NPC）、固定交互物体与门。房间节点不负责永久状态。

`player.tscn` 包含矩形外观、CollisionShape2D 和交互 Area2D。`interactable.tscn` 包含 Area2D、CollisionShape2D、矩形外观、Label，导出 `interactable_id`。NPC 和物品复用此场景，不必建立角色动画系统。

只设一个 GameState Autoload，其余对象由 Main 持有。避免把每个模块都注册成全局单例。不要让 Autoload 名与脚本 `class_name` 同名。

### 模块职责与接口

| 模块 | 建议接口 | 边界 |
| --- | --- | --- |
| GameState | `snapshot()`、`replace_state(validated_state)`、`reset(initial_state)`、`state_changed` 信号 | 保存状态、统一发布变化；不保存场景节点引用 |
| ContentDB | `load_content(path)`、`validate_content()`、按 ID 查询 | 读取一次静态数据、校验引用；不存玩家进度 |
| ConditionEvaluator | `evaluate(condition, snapshot)` | 纯判断，无副作用；同时返回失败原因供调试 |
| EffectExecutor | `apply(effects, snapshot)` | 在副本上执行效果，返回新状态或错误；不直接操作 UI |
| DialogueRunner | `start(dialogue_id)`、`choose(choice_id)`、`close()` | 选择后检定、提交效果、推进文本；不硬编码 NPC_A 等内容 ID |
| WorldController | `load_room(room_id, spawn_id)`、`refresh_actors(phase_id)` | 房间、出生点、NPC 阶段位置；清除旧交互目标 |
| SaveService | `save(snapshot)`、`load_validated(content)` | JSON 单槽存档、版本和类型校验；不恢复对话到半句 |
| Player / Interactable | 候选登记、距离排序、`request_interaction(id)` | 处理空间与输入；动作由数据决定 |
| UI | 订阅状态/对话信号，发送用户操作 | 不直接改属性、不判剧情、不自行发奖励 |

任务状态第一版由 Main 在一次有效状态提交后按配置重新计算，不另设庞大的任务管理器。任务完成没有自动奖励；如果以后需要奖励，再加明确的一次性效果。

## 4. 输入与可见反馈

InputMap 至少配置：`move_left`（A/左方向）、`move_right`（D/右方向）、`interact`（E）、`ui_cancel`（Esc）、`toggle_debug`（F3）。

- 靠近物体显示名字与 E 提示；候选重叠时选择最近者，同距离用稳定 ID 排序。
- 门也通过 E 触发，进入目标房间对应出生点，避免落点直接触发反复传送。
- 对话时停止移动和世界交互；用鼠标按钮选择，键盘能聚焦并提交。
- 文本一次显示完整，不做打字机。测试文本允许自动换行，选项多时可滚动。
- Esc 关闭对话；已经提交的选择效果保留。关闭动作本身不发奖励。
- UI 弹窗消费输入，点击按钮不会同时操作背后的世界。
- 对话、换房间和状态提交期间禁用保存、读取和阶段修改。重置始终可用，先关闭 UI 并取消旧回调，再重建初始局面。
- 结算后显示结果并停止世界输入，允许重置或读档。
- 主画面或调试面板标出当前房间、阶段、交互对象。调试信息不能替代可操作的正常界面。

## 5. 状态与数据格式

### 运行时状态

以下为初始快照示例；实际初始化来自配置。

```json
{
  "schema_version": 1,
  "content_version": "demo-v1",
  "room_id": "room_a",
  "spawn_id": "spawn_start",
  "phase_id": "phase_a",
  "traits": {
    "innovation": 0,
    "tradition": 0,
    "piety": 0,
    "secularity": 0,
    "cruelty": 0,
    "mercy": 0
  },
  "affinities": {"npc_a": 0, "npc_b": 0},
  "flags": {},
  "clues": [],
  "task_states": {"task_a": "active"},
  "consumed_once_keys": [],
  "selected_outcome": null
}
```

`clues` 和 `consumed_once_keys` 按集合处理，序列化为去重数组。第一版读档把玩家放回当前房间的已记录出生点，不保存每像素位置。静态配置与运行时状态分离；取快照时深复制，不能让修改污染初始配置。

### 静态配置

第一版集中放在 `data/demo_content.json`，顶层包含：

| 字段 | 内容 |
| --- | --- |
| `content_version`、`test_only` | 配置版本、测试数据标记 |
| `traits`、`initial_state` | 六维显示名、初始状态 |
| `npcs` | ID、占位名、入口对话 ID |
| `rooms` | ID、场景路径、默认出生点 |
| `interactables` | ID、标签、动作类型、目标 ID、可用条件 |
| `dialogues` | 对话 ID、入口节点、文本节点与选项 |
| `clues` | ID、占位标题与说明 |
| `tasks` | ID、占位说明、完成条件 |
| `phases` | ID、每个 NPC 的 room_id 与 marker_id |
| `outcomes` | ID、占位结果文字、开放条件 |

交互动作类型只需 `dialogue`、`collect_clue`、`change_room`、`set_phase`、`open_outcomes`。普通动作处理也复用条件与效果模块。

### 条件

只实现 `all`、`any`、`not` 与明确的叶子条件，不执行配置中的任意代码。支持 `trait`、`affinity`、`flag`、`clue`、`phase`、`task`、`once_unused`；数值比较先支持 `gte`、`lte`、`eq`。

私密话题条件示例：

```json
{
  "all": [
    {"kind": "affinity", "id": "npc_a", "op": "gte", "value": 20},
    {"kind": "clue", "id": "clue_a"}
  ]
}
```

`visible_if` 决定话题是否出现；`check` 决定选择后的结果。普通对话的 `visible_if` 中不允许出现属性门槛，校验器应识别嵌套条件中的此类误用。条件失败原因应在调试面板可见，不必对玩家显示隐藏话题。

### 对话选项

每个节点至少有 `id`、`speaker_id`、`text`、`choices`；每个选项至少有 `id`、`text`，并可带 `visible_if`、`once_key`、`effects`、`next`、`check`、`on_pass`、`on_fail`。没有检定时走 `next`；有检定时只走对应结果分支；`next: null` 表示结束。

可检定的选项示例：

```json
{
  "id": "test_mercy_check",
  "text": "TEST_CHECK_MERCY",
  "visible_if": {
    "all": [
      {"kind": "affinity", "id": "npc_a", "op": "gte", "value": 20},
      {"kind": "clue", "id": "clue_a"}
    ]
  },
  "once_key": "npc_a_private_check",
  "check": {"kind": "trait", "id": "mercy", "op": "gte", "value": 20},
  "effects": [{"type": "set_flag", "id": "check_resolved", "value": true}],
  "on_pass": {
    "effects": [{"type": "set_flag", "id": "check_passed", "value": true}],
    "next": "node_pass"
  },
  "on_fail": {
    "effects": [{"type": "set_flag", "id": "check_passed", "value": false}],
    "next": "node_fail"
  }
}
```

效果类型限于 `add_trait`、`add_affinity`、`set_flag`、`add_clue`、`set_phase`、`select_outcome`。加减数值用 `amount`，设置值用 `value`，目标用 `id`。`add_clue` 自带去重；`select_outcome` 要校验结果条件。换房间由 WorldController 执行，不把节点引用写进效果数据。

处理一次选择的顺序：校验当前节点和选项 → 重新检查开放条件与 once_key → 用提交前的状态做检定 → 在副本中应用通用效果和唯一结果分支效果 → 记录 once_key、更新任务状态 → 一次提交 → 更新 UI 和世界。

若效果或目标 ID 无效，不提交半份状态。按钮提交期间禁用，重复点击与过期回调不得重复结算。同一组选项共享 once_key，防止先选 A、重开后再选 B 来领取双份效果。

## 6. 必须能手动走通的测试内容

### 占位布置

- Room_A：玩家出生点；phase_a 时的 NPC_A；CLUE_A 物体；切换到 phase_b 的 PHASE_SWITCH；通往 Room_B 的门。
- Room_B：NPC_B；phase_b 时 NPC_A 的位置；OUTCOME_TERMINAL；返回 Room_A 的门。
- NPC_A 的两段占位对话分别演示初次选择与私密检定。
- NPC_B 提供一次性 `affinity(npc_b) + 5` 选项，用来确认两个 NPC 的好感互不影响。

### NPC_A 初次选择

| 选项 | 效果 | 一次性控制 |
| --- | --- | --- |
| TEST_PREPARE_PASS | mercy +20，NPC_A 好感 +20 | 共享 `npc_a_intro` |
| TEST_PREPARE_FAIL | mercy +0，NPC_A 好感 +20 | 共享 `npc_a_intro` |

两项都设置 `intro_done = true`。领取其中一项后，另一项也不能再领取。初次选择与私密检定可以位于同一入口菜单的不同节点。被消费的选项隐藏或禁用，并始终提供退出；不能出现无法关闭的空菜单。

### 成功与失败路径

| 步骤 | 成功路径 | 失败路径 |
| --- | --- | --- |
| 1 | 选择 TEST_PREPARE_PASS | 重置后选择 TEST_PREPARE_FAIL |
| 2 | 交互获得 CLUE_A | 同样获得 CLUE_A |
| 3 | 私密检定选项出现并可点击 | 同一个检定选项同样出现且可点击 |
| 4 | mercy 20 >= 20，显示 TEST_PASS | mercy 0 < 20，显示 TEST_FAIL |
| 5 | check_resolved=true、check_passed=true | check_resolved=true、check_passed=false |
| 6 | TASK_A 完成 | TASK_A 同样完成 |
| 7 | 操作 PHASE_SWITCH，NPC_A 从 A 移到 B | 同样能推进，不因检定失败卡住 |
| 8 | 到 B 操作结算物体，OUTCOME_A 可选 | OUTCOME_A 不可选，OUTCOME_B 可选 |

TASK_A 完成条件为：已获得 CLUE_A 且 `check_resolved == true`。阶段控制物体在 TASK_A 完成时可用，只做 phase_a → phase_b；NPC_A 在旧房间不再出现，返回或重复刷新不能复制 NPC。

结算物体要求 phase_b 且 TASK_A 完成。OUTCOME_A 额外要求 `check_passed == true`，OUTCOME_B 为该结算界面中的保底选项。成功玩家可以主动选 B；失败玩家仍能结束测试。

在初次选择之后、获取线索之前，话题不开放；获取线索但好感不足 20 时也不开放。通过正常流程与调试面板验证两个条件缺一不可。

## 7. 调试、存档与重置

F3 面板至少显示：当前房间/阶段、六维、各 NPC 好感、flags、线索、任务、已消费 once_key、最近一次检定的实际值/阈值/结果、最近操作日志。

提供：修改六维与好感、切换阶段、保存、读取、重置。调试修改通过统一提交入口执行，页面上明确标为调试操作。阶段切换按钮也要遵守对话/加载期间的输入锁。

存档使用 `user://whitebox_save.json`，单槽即可：

- 保存 schema_version、content_version 与全部持久状态；写文件前完整序列化，处理打开/写入失败。
- 读档先解析并校验版本、字段类型、数值、已知 ID；失败显示原因并保留当前状态，不自动覆盖坏文件。
- JSON 数字转换为框架使用的整数类型；线索和一次性记录去重；拒绝未知房间、阶段、NPC 等引用。
- 成功读取后统一恢复状态、房间和 NPC 位置；不重放旧对话效果或奖励。
- 存档不含节点对象、UI 焦点、对话游标和调试日志。对话中保存/读取按钮禁用并说明“请先结束对话”。
- 重置关闭对话和结果页、清除临时交互与日志、恢复所有初始数值/集合/任务/房间/阶段/物体和 NPC。重置不删除磁盘存档，可以随后读档恢复。

## 8. 分阶段实施

| 阶段 | 实现内容 | 完成标准 |
| --- | --- | --- |
| M1 可交互核心 | Main、Room_A、Player、占位交互、数据读取、GameState、条件/效果、对话、调试数值、重置 | 能走通高属性成功与低属性失败；低属性选项可选；一次性效果不重复 |
| M2 世界与流程 | Room_B、门、线索、TASK_A、阶段/NPC 位置、结果面板 | 两条测试路径均可结束；换房间不丢状态、不复制 NPC |
| M3 持久化与交付 | 单槽存读档、坏档处理、核心测试、README、实现状态记录 | 保存/修改/读取恢复一致；重置完整；说明实际验证结果 |

按 M1 → M2 → M3 连续推进。完成一个阶段后进行相关验证，修复失败再进入下一阶段；不需要每个阶段等待用户回复。这里只分三段实现顺序，不引入额外审批流程。

## 9. 验收与验证

### 自动验证

不用安装测试插件。`tests/test_runner.gd` 继承 SceneTree，直接创建需要的状态/服务实例并注入依赖；不要假设单独运行测试脚本时 Main 已经实例化。

最少覆盖以下风险：

1. 好感/线索四种组合中，只有两者都满足时开放私密话题；属性低仍能选择并正确失败。
2. 六维修改与 NPC 好感互不隐式联动；NPC_A 好感不影响 NPC_B。
3. 检定读取提交前数值；同一次选择的加属性效果不能倒过来让检定成功。
4. 共享 once_key 的两个选项只能提交一个；连点、重进对话、读档后都不重复发放。
5. 无效效果/引用不造成部分提交；正常提交能同步更新任务与结果开放条件。
6. 快照不污染初始值；重置恢复全部持久状态；存读档往返一致；坏 JSON/错版本不覆盖当前状态。
7. 如能运行场景：实例化 Main，切房间/阶段后 NPC 实例数量和位置正确，交互目标不残留失效引用。

在项目根目录执行以下命令；`godot` 应替换为实际检测到的 Godot 4 编辑器命令或完整路径。不要把下列命令当作已经执行成功。

```bash
godot --version
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --quit-after 120
```

测试失败必须以非零退出码退出。检查退出码与引擎日志，不只看“命令运行结束”。第三条针对规则与状态，第四条只检查主场景短时启动，不能据此声称图形界面和实际操作已经验证。

如果环境没有 Godot，继续完成能完成的工程、数据校验和检查步骤，交付具体启动命令与待验证项；明确说明没有引擎运行验证，不能写“所有测试通过”。

### Godot 编辑器内手动验收

打开 `project.godot`，运行主场景，按第 6 节分别走通两条路径，再确认：

- 玩家不会走出边界，能靠近并交互；对话期间无法移动；鼠标和键盘能完成选项操作。
- 两个房间往返后数值/线索/任务保持；phase_b 的 NPC_A 仅在 B 出现一次。
- 保存 → 改数值/阶段 → 读取，状态与房间恢复；重复读取不增加奖励。
- 重置后恢复到 Room_A、phase_a、全部初始值，可重新走失败路径。
- 修改 JSON 的一条台词、一次好感增量和一个检定阈值，重启后生效，不修改 GDScript。
- 窗口缩放后文字、选项、面板仍可读；新工程无需手工补连信号、建 InputMap 或添加 Autoload。

## 10. 必须交付

1. 可由 Godot 打开的完整工程：不是代码片段集合，也不是空目录脚手架；本次范围内不得留 TODO 占位逻辑。
2. 有效的 `.tscn` 与 `.gd`、完整 `project.godot`、InputMap、Autoload 和默认主场景配置。
3. `demo_content.json`：所有占位流程可实际运行；台词、数值、条件、NPC 阶段位置和结果由数据配置。
4. `README.md`：Godot 实际版本、启动方式、按键、测试路线、存档位置，以及“改台词/数值/条件/新增对话节点”的简短操作说明。
5. `IMPLEMENTATION_STATUS.md`：各阶段完成情况、实际执行的验证命令与结果、未验证项和必要假设。
6. 核心测试脚本；如没有引擎或显示环境，明确区分已检查与待人工验证。

第一版无需打包 exe。以后导出时，使用 FileAccess 读取的 JSON 必须随包包含；在 README 写清该 Godot 小版本对应的原样保留/非资源导出过滤设置，不能只保证编辑器能读到。

## 11. 可直接交给 Codex 的启动 Prompt

将本文件放入目标工程根目录，让 Codex 打开该目录，然后发送下面的内容。

```text
请在当前工作目录直接实现 GODOT_FRAMEWORK_SPEC.md 中的 Godot 占位框架，完成 M1、M2、M3，并交付能够打开运行的工程。

先检查现有工程、适用的 AGENTS.md 和可用的 Godot 版本。新工程使用 Godot 4.x 标准版与 GDScript；已有工程保留无关修改，不做未经要求的版本迁移。先给出简短实现计划，然后开始创建和修改文件，不停留在方案或伪代码。

本次目标是让框架功能真实运行，全部内容采用占位符：两个单屏灰盒房间、两个占位 NPC、分支对话、六维属性、独立好感、条件判断、线索、任务、阶段和 NPC 位置、结果、单槽存读档、调试与重置。2D 平视，左右移动只是本次白盒的默认移动方案。

重点遵守规格中的玩法规则：属性检定发生在选择之后，不能因属性低隐藏或禁用检定选项；私密话题由好感和剧情前置共同开放；好感只按配置固定增减；一次性选择与线索不能重复领取；所有示例数值均为测试值。

按职责分离世界呈现、状态、内容数据、条件判断和效果执行。只设一个 GameState Autoload。台词、选项、数值、条件和分支写在 JSON；不要把 NPC_A 等测试内容硬编码进通用逻辑。保持实现简单，不额外增加剧情、美术、插件、编辑器或复杂管理器。

按三个阶段连续实现，每阶段完成相关验证并修复问题，再继续下一阶段。合理的低风险细节自行决定，记录在 IMPLEMENTATION_STATUS.md，无须每阶段等待我确认。

完成高属性成功、低属性失败两条可操作测试路径，并验证条件组合、一次性效果、NPC 好感独立、换房间/阶段、存读档和完整重置。不要以打印日志代替功能。

如果可调用 Godot，运行导入/解析检查、核心规则测试和主场景启动检查；具备图形环境时再验证实际操作。若缺少引擎或显示环境，继续完成可完成的工作，并准确列出未验证项，不能声称已运行通过。

最终交付完整工程、占位 JSON、README、核心测试与实现状态记录。回复工程入口、启动方式、实际验证结果，以及仍需我手动检查的事项。
```

## 12. 技术依据

架构与范围是本项目的设计提案；以下官方文档用于核对引擎能力、命令和任务交接方式，并不意味着官方规定必须使用上述目录结构。

- Godot Autoload（跨场景保留状态）：https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- Godot CharacterBody2D（脚本控制移动与碰撞）：https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- Godot FileAccess（存读档与导出时的数据文件包含）：https://docs.godotengine.org/en/stable/classes/class_fileaccess.html
- Godot 命令行与 headless 验证：https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- OpenAI：用规格、阶段与验证标准组织 Codex 长任务：https://developers.openai.com/blog/run-long-horizon-tasks-with-codex
