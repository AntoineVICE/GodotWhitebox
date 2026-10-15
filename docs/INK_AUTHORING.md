# Ink 写作与角色接入

当前结构适合几十名角色共用一个叙事框架。每个角色登记一次资料；剧情文件按事件、章节或日常话题拆分。一场多人对话可以写在同一个 Ink 文件里，不必拆成若干角色脚本。

## 日常改稿

1. 修改 story/quests/poppy_request.ink 等源文件，用任何 UTF-8 文本编辑器或 Inky 均可。
2. 保存文件，停止旧游戏，在 Godot 按 F5。
3. 已启用的 addons/story_workflow 插件会检查角色、动作、条件、选项 ID 和入口，再调用附带的 inklecate 编译。
4. 编译通过才运行；编译失败在 Godot 输出面板显示文件、行号与原因。可通过“项目 → 工具 → 编译 Ink 剧本”单独编译。

不修改 story/compiled/main.json。它是编译器输出，与原来的手写 JSON 对话格式不同。不要同时启用 InkGD 自带的编辑器插件；本工程已有编译流程，运行时也已经初始化。

## 谁负责什么

| 层 | 内容与职责 |
| --- | --- |
| Ink 源文件 | 台词、选项文字、叙事分支、说话人标签、随机措辞、访问记录 |
| data/characters.json | 角色资料、稳定 ID、独立初始好感、使用哪组对话路由 |
| data/story_rules.json | 条件组合、检定门槛、固定数值效果、一次性动作、优先入口 |
| data/demo_content.json | 房间、阶段、角色站位、任务、线索、世界初始值与 HUD 提示 |
| GameState | 唯一权威世界状态及 Ink 状态的存档副本；唯一 Autoload |
| dialogue_runner / ink_session | 驱动真实 Ink、把外部函数接到条件与效果系统、同步提交或回退 |
| world_controller / UI | 呈现状态、移动、交互和显示文字，不自行判定剧情或发奖励 |

整个游戏共用一个编译后的 Ink 故事。角色数量增加不会创建二十多个 Autoload、独立存档或复制二十套对话控制器。普通运行节点 __InkRuntime 是 InkGD 的服务节点，不保管另一份世界状态，也不是 Autoload。

## 文件组织

- story/main.ink：统一登记所有 INCLUDE；新增剧情文件在这里加一行。
- story/quests/：围绕一件事组织多人剧情。
- story/dialogues/：角色日常或共用话题。
- story/interactions/：物体交互的文本与选项。
- story/api.ink：框架允许调用的五个外部函数声明。
- story/preview/：独立写作预览及模拟状态，不进入正式游戏。
- docs/templates/character_dialogue.ink：最小角色话题模板，不会自动进入游戏。

当前约定把 INCLUDE 集中写在 main.ink，剧情子文件只写 knot / stitch。这样正式编译、来源校验和独立预览使用相同文件列表。knot 名称在整个故事中必须唯一，建议“事件_角色_话题”，例如 abbey_rodrigo_request，而不是每个人都叫 start。

## 多人说话与稳定选项

```ink
=== example_conversation ===
你找我有事？ # speaker:player
来得正好。我正要找你。 # speaker:npc_a
别堵着门，我还要收拾草药。 # speaker:npc_b
修士抱起桌上的木箱。 # speaker:narrator
+ [“你们先说，我听着。” # id:listen]
    先听我说完。 # speaker:npc_a
    ++ [“知道了。” # id:leave]
        -> DONE
+ [“我晚点再来。” # id:leave]
    -> DONE
```

每行可用 speaker 标签换说话人。玩家、旁白、NPC 都查角色表；speaker:self 表示当前发起交互的角色，适合共用招呼语。姓名不是写死在 UI 脚本里。示例仍使用 npc_a、npc_b 保留已有稳定 ID；新角色建议直接使用清晰的英文 ID。

选项标签写在方括号内，例如 `[文字 # id:listen]`，不会把标签混进对白。每个当前菜单中的 ID 必须唯一；在不同菜单里可以重复 leave。嵌套选项用 `++`，再下一层用 `+++`，不能只缩进一个 `+`。

每段通常应保留离开选项。画面也可随时 Esc 关闭交谈。Ink 输出在下一个选项或 DONE/END 处停止；若一段输出后直接结束交谈，文字不会单独停留，需让玩家阅读的段落应加一个“继续/离开”选项。

## 五个外部函数

| 调用 | 用途 | 能否用于选项开放 |
| --- | --- | --- |
| game_flag("poppy_held") | 读取已登记的剧情标记 | 可以 |
| game_condition("private_topic") | 判断规则表里的组合条件 | 可以；不允许属性门槛 |
| game_available("hand_over") | 判断动作的条件和一次性记录 | 可以；不允许属性门槛 |
| game_check("ask_reason") | 用本次选择前的属性做检定 | 只能选中后执行 |
| game_action("hand_over") | 执行已登记动作，成功返回 true | 只能选中后执行 |

传入已登记的固定字符串 ID；不要动态拼接 ID。构建器检查字面量引用，运行时仍会再次检查。Ink 不直接增减权威属性、好感或任务状态；局部叙事变量可以用 VAR，但不要用它代替 GameState 的世界记录。

现有的低属性仍可选、选择后检定：

```ink
+ {game_condition("can_inquire")} [“以前到底发生过什么？” # id:private_check]
    {game_check("ask_reason"):
        ~ game_action("resolve_pass")
        -> node_pass
    - else:
        ~ game_action("resolve_fail")
        -> node_fail
    }
```

can_inquire 只检查好感、线索与是否已经追问。ask_reason 在 checks 表中检查慈悲。不能把 game_check 写进选项开放条件。构建器会拒绝直接写在选项上的检定或动作，运行时也禁止进入对话时触发它们。

同一选择先调用奖励动作、后调用检定，检定仍使用选择前的属性快照。本次奖励不能提升本次检定结果。好感只按动作中配置的整数变化，不乘任何属性系数。

一次性动作写法：

```ink
+ {game_available("hand_over")} [把纸包交给他。 # id:hand_over]
    {game_action("hand_over"):
        -> delivery_reply
    - else:
        -> rodrigo_menu
    }
```

hand_over 的 JSON 动作配置检查“目前携带且尚未交付”，使用 npc_a_delivery 一次性键，移除携带、记录交付并固定加好感。用 Ink 的 `*` 一次性选项只能限制 Ink 的访问显示，不能替代框架里的 once_key。发奖励、领取线索、交付等必须经过框架动作。

## 新增一个角色

例如新增 brother_thomas：

1. 在 characters.json 增加以下条目（插入现有对象内，留意逗号）：

```json
"brother_thomas": {
  "label": "托马斯修士",
  "kind": "npc",
  "portrait": "",
  "initial_affinity": 0,
  "dialogue_id": "thomas_talk",
  "color": "#899a86"
}
```

2. 从模板写 story/dialogues/thomas.ink，使用唯一入口 thomas_greeting 和 speaker:brother_thomas，在 main.ink 添加 `INCLUDE dialogues/thomas.ink`。
3. 在 story_rules.json 的 dialogue_routes 中加入：

```json
"thomas_talk": [
  {"entry": "thomas_greeting", "condition": {}}
]
```

4. 若需角色出现在房间里，在相应阶段的 npcs 中登记 room_id 与 marker_id。marker_id 必须是该房间现有 NPC 位置 Marker2D；要增加站位先在房间场景增加对应 Marker。未配置当前阶段位置的角色仍有资料和好感，关系面板显示“当前未登场”。
5. 有新奖励或条件才增加 actions / conditions / checks / flags。普通改台词无需改它们。
6. F5 编译运行。初始好感、独立存档字段和人物关系列表由角色表自动生成，无需手改 UI 或 GameState。

不要求每个 NPC 一个 Ink 文件。罗德里戈和修士共同参与同一事件时，事件文件可以同时包含两人的发言。没有独立内容的背景人物可以共用 ambient_greeting，并使用 speaker:self。

## 对话入口的优先级

dialogue_routes 每一项按从上到下的顺序匹配，最后必须有无条件兜底。当前罗德里戈优先顺序为已交付、携带中、曾口头拒绝、晚祷阶段、已经交谈、初次请求。

“携带中”必须优先于“曾拒绝”，才能在先拒绝、后取药时得到交付选项。一次实际行为由自己的 flag 表示，不把口头态度拿来替代行为。重新开口时选择当前世界状态合适的入口，不强行回到上次打开的菜单。

NPC 的 room_id / marker_id 属于世界阶段配置，Ink 不直接移动场景节点。扩展新阶段时通过配置动作 set_phase 推进，再由世界控制器刷新角色位置。

## 在 Inky 中预览

先在 Godot 编译一次，然后用 Inky 打开 story/preview/main.ink。预览提供初次请求、高属性、低属性、寻找取药、先拒绝后交付、修士解释六个起点。

- main.ink 与 fallbacks.ink 由构建自动生成，别手改；场景预设在 menu.ink，可自行调整。
- 预览回退函数从当前 JSON 规则生成，模拟好感、属性、标记与一次性效果。新增规则后先重新编译。
- 真正改稿仍改 story/quests、dialogues、interactions 下的文件，它们同时供游戏和预览读取。
- 正式游戏禁用回退函数，所有外部函数都绑定 GameState；预览变量不会写进玩家存档。
- 预览不模拟真实移动、房间碰撞、输入锁、原子提交、检定快照隔离或磁盘存档，最终验证用 Godot。

本机已把预览入口实际编译并在 InkGD 执行高低属性、找药、交药和修士分支；没有安装或操作 Inky 图形编辑器，因此其具体版本的窗口与文件导航体验需自行检查。

## 版本与规则约束

使用固定的 InkGD Godot 4 分支和 inklecate 1.1.1，详见 tools/dependencies.json。compiled/manifest.json 记录所有源文件哈希和编译后故事哈希。缺少编译文件、来源过期或版本不一致会明确报错，不偷偷运行旧对白。

当前采用一个故事包、一个存档槽。已有存档绑定该故事构建；修改台词或结构导致编译内容变化时，应重新开始测试。长期发行版的存档迁移、多语言、配音、角色头像渲染、自动剧情编辑器和多人并行对话调度均未实现。portrait 字段只是资料接口，当前 UI 仍用姓名标识，并不会仅填入路径就自动渲染正式肖像。

所有测试数值和便于检定的选择说明都可后续调整。当前 JSON 与 Ink 分工是这次 Ink 接入后的约定，取代早期“所有对白写在 JSON”的写作方式；原来的世界与条件/效果分层继续沿用。
