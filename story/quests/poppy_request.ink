// Spoken stance, inquiry, taking and delivery are separate game actions.
=== rodrigo_request ===
{~金德日赫，来得正好。我有件事要你办。|金德日赫，过来。别摆出那副等着听坏消息的脸。|我正找你呢，金德日赫。帮我从修士眼皮底下拿样东西。} # speaker:npc_a
我要一点罂粟。以前用过，能让我把自己麻醉一阵。马提亚斯偏说那东西会把脑子弄坏，把药全藏了。 # speaker:npc_a
你想让我去偷？ # speaker:player
对。跟他说借，他只会给你讲一下午道理。你去找出来，拿一小包给我。 # speaker:npc_a
-> rodrigo_menu

=== rodrigo_followup ===
{game_condition("private_topic"):
    我看见你手里的字条了。“勿再交给罗德里戈”——他写我的名字倒挺认真。想问什么就问。 # speaker:npc_a
- else:
    药已经不在原来的架子上。右边石凳有张修士落下的字条，你要查他的安排就去看。 # speaker:npc_a
}
-> rodrigo_menu

=== rodrigo_refused ===
不愿意就直说，我听见了。我还没到要跪下来求你的地步。 # speaker:npc_a
罗德里戈让开路，又朝草药房看了一眼。他没有替你决定下一步。 # speaker:narrator
-> rodrigo_menu

=== rodrigo_evening ===
晚祷都开始了。修士还守着他的柜子——藏得再好，总不会凭空消失。 # speaker:npc_a
找到了就来找我。真不打算办，也过来把话说清楚，别让我空等。 # speaker:npc_a
-> rodrigo_menu

=== rodrigo_carrying ===
{game_flag("refused_help"):
    你不是说不帮吗？怎么，又折回来了？ # speaker:npc_a
- else:
    回来了？别光站着，找到没有？ # speaker:npc_a
}
纸包在你衣袋里。罗德里戈还没有拿到它。 # speaker:narrator
-> rodrigo_menu

=== rodrigo_delivered ===
药我已经收好了。你还有话要说？ # speaker:npc_a
-> rodrigo_menu

=== rodrigo_menu ===
+ {game_available("hand_over")} [把身上的罂粟纸包交给罗德里戈。 # id:hand_over]
    {game_action("hand_over"):
        -> delivery_reply
    - else:
        你摸了摸衣袋，已经没有能再交给他的药包。 # speaker:narrator
        -> rodrigo_menu
    }
+ {game_flag("poppy_delivered")} [“药已经给你了。还有什么要说的吗？” # id:resume_delivery]
    -> delivery_afterwards
+ {game_available("prepare_pass")} [“你用它麻醉自己？先把话说清楚，我替你看看。”（慈悲 +20） # id:prepare_pass]
    ~ game_action("prepare_pass")
    -> rodrigo_followup
+ {game_available("prepare_fail")} [“行，我替你找。惹出事来，你自己担着。”（慈悲不变） # id:prepare_fail]
    ~ game_action("prepare_fail")
    -> rodrigo_followup
+ {game_condition("can_inquire")} [“字条说不准再给你。以前到底发生过什么？”（选择后检定慈悲） # id:private_check]
    {game_check("ask_reason"):
        ~ game_action("resolve_pass")
        -> node_pass
    - else:
        ~ game_action("resolve_fail")
        -> node_fail
    }
+ {game_available("refuse_help")} [“不，我不替你偷东西。你自己去跟修士说。” # id:refuse_help]
    ~ game_action("refuse_help")
    -> rodrigo_refused
+ {game_condition("can_end_request")} [“这件事我不办了，你自己去跟修士说。”（准备结束差事） # id:end_request]
    -> decline_reply
+ [“先这样，我走了。” # id:leave]
    -> DONE

=== node_pass ===
你问的是我，不是替修士来审我。行，那我告诉你。 # speaker:npc_a
我以前用它把自己麻过去。马提亚斯见过那副样子，就咬定再这样下去会坏了脑子。如今连罂粟都不肯让我看见。 # speaker:npc_a
他有他的道理，我有我的难受。药放在哪儿，他没告诉我。你要不要帮，听完再决定。 # speaker:npc_a
【慈悲检定成功】你问出了藏药的缘由。是否取药、是否交付，仍由你决定。 # speaker:narrator
+ [“知道了，回头再说。” # id:leave]
    -> DONE

=== node_fail ===
你拿着张字条，就打算跟修士一个腔调？我说了，以前用过。他嫌我用得不对，就把东西藏了。 # speaker:npc_a
更多的事，我现在不想讲。帮就去找，不帮就算。 # speaker:npc_a
【慈悲检定失败】你没能问出更多。流程仍可继续：仍能寻找、取走药包，再自行决定交不交付。 # speaker:narrator
+ [“知道了，回头再说。” # id:leave]
    -> DONE

=== delivery_reply ===
你把纸包递给罗德里戈。他接得很快，掂了掂，收进袖口。 # speaker:narrator
{game_flag("refused_help"):
    你不是说不帮我吗？ # speaker:npc_a
    嘴上怎么说，和后来怎么做，是两回事。 # speaker:player
    哈，这话我喜欢。东西我收了，这个人情也记着。 # speaker:npc_a
- else:
    我就知道你有办法。修士把柜子翻过来，也猜不到是你拿的。 # speaker:npc_a
    少得意。我帮你拿来，可没答应替你收拾往后的麻烦。 # speaker:player
    行，算我的。多谢。 # speaker:npc_a
}
【已交付】药包不再由你携带。 # speaker:narrator
-> delivery_choices

=== delivery_afterwards ===
东西已经在我这儿了，放心。还有别的事？ # speaker:npc_a
-> delivery_choices

=== delivery_choices ===
+ [“收好吧。我走了。”（结束差事） # id:finish_delivery]
    {game_action("finish_delivery"):
        -> ending_delivery
    - else:
        -> rodrigo_delivered
    }
+ [“还有事，待会儿再说。” # id:leave]
    -> DONE

=== decline_reply ===
{game_flag("poppy_held"):
    药包仍在你衣袋里，你没有递出去。 # speaker:narrator
}
我不替你办这件事了。你自己去跟修士说。 # speaker:player
那就这样。你不肯，我另想办法。 # speaker:npc_a
罗德里戈的脸色沉了下来，却没有再拦你。现在告别会结束这桩差事；你也可以暂不作最后决定。 # speaker:narrator
+ [“嗯，你们自己谈。我走了。”（确认结束差事） # id:finish_refusal]
    {game_action("finish_refusal"):
        -> ending_refusal
    - else:
        -> rodrigo_menu
    }
+ [“等一等，我再想想。” # id:back]
    -> rodrigo_evening

=== ending_delivery ===
你已经亲手把罂粟交给罗德里戈。他拍了拍藏着纸包的袖口，先一步走向门外。 # speaker:narrator
修士仍在收拾柜子。他把药藏起来，是不愿罗德里戈再靠它麻醉自己；现在那包东西还是到了罗德里戈手里。
这桩差事办成了。至于两人接下来怎么争，那是之后的事。
-> END

=== ending_refusal ===
你没有把罂粟交给罗德里戈，而是当面结束了这桩差事。 # speaker:narrator
“我自己想办法。”他丢下这句话，朝修士的方向走去。
{game_flag("poppy_held"):
    你衣袋里的纸包还在原处。这次告别没有把它自动交出去。
- else:
    藏起的药仍留在柜子里。你转身离开，没有替任何一方作出更多承诺。
}
-> END
