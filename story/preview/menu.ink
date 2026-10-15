// Editable whitebox preview scenarios. No real game state is changed.
=== preview_menu ===
这是写作预览。世界操作由测试变量模拟；正式游戏仍由 GameState 执行。
+ [从初次请求开始 # id:preview_intro]
    -> rodrigo_request
+ [预览高属性追问 # id:preview_high]
    ~ mock_trait_mercy = 20
    ~ mock_affinity_npc_a = 20
    ~ mock_clue_clue_a = true
    ~ mock_flag_intro_done = true
    ~ mock_once_npc_a_intro = true
    -> rodrigo_followup
+ [预览低属性追问 # id:preview_low]
    ~ mock_trait_mercy = 0
    ~ mock_affinity_npc_a = 20
    ~ mock_clue_clue_a = true
    ~ mock_flag_intro_done = true
    ~ mock_once_npc_a_intro = true
    -> rodrigo_followup
+ [预览寻找并取药 # id:preview_cabinet]
    ~ mock_phase = "phase_b"
    -> cabinet_entry
+ [预览先拒绝后交药 # id:preview_delivery]
    ~ mock_flag_intro_done = true
    ~ mock_once_npc_a_intro = true
    ~ mock_flag_refused_help = true
    ~ mock_flag_poppy_taken = true
    ~ mock_flag_poppy_held = true
    -> rodrigo_carrying
+ [预览修士的解释 # id:preview_monk]
    -> herbalist_greeting
