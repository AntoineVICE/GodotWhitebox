=== herbalist_greeting ===
{~金德日赫？找我什么事？|进来吧。柜子里的东西别乱动。|我正清点草药。你是来帮忙，还是来找东西？} # speaker:npc_b
-> herbalist_menu

=== herbalist_menu ===
+ {game_available("greet_b")} [“这些标签我替您理好。”（修士好感 +5） # id:greet_b]
    ~ game_action("greet_b")
    谢谢，放在桌角就好。罗德里戈若托你带话，让他自己来。 # speaker:npc_b
    -> herbalist_menu
+ {game_available("monk_warning")} [“您为什么把罂粟藏起来？” # id:ask_warning]
    ~ game_action("monk_warning")
    他以前拿它来麻醉自己。那副昏沉的样子，我见过。我认为再这么下去，对他的脑子没有好处。 # speaker:npc_b
    所以您藏了药？ # speaker:player
    是。我不再把它放在他伸手就能拿到的地方。真有事，让他来找我说，别让别人替他偷。 # speaker:npc_b
    -> herbalist_menu
+ [“明白了，我先走了。” # id:leave]
    -> DONE
