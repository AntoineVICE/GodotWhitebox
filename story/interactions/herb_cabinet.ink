=== cabinet_entry ===
{
- game_flag("poppy_taken"):
    你取过药的夹层空了一块。这里没有第二份可以拿。 # speaker:narrator
- game_flag("cabinet_searched"):
    柜底的旧标签册后面，藏着写有“罂粟”的纸包。你已经找到了，尚未拿走。 # speaker:narrator
- game_condition("evening"):
    晚祷钟响过，修士背对你清点桌上的标签。柜子原来放罂粟的位置空着，下层却压着一本不合位置的旧册子。 # speaker:narrator
- else:
    柜子里原来放罂粟的位置已经空了。修士就在旁边，盯着你伸向柜门的手。等晚祷时再来看看。 # speaker:narrator
}
-> cabinet_menu

=== cabinet_menu ===
+ {game_available("search_cabinet")} [检查柜底和旧标签册后面的夹层。 # id:search_cabinet]
    ~ game_action("search_cabinet")
    你拨开旧册子，看见后面藏着的纸包。标签写着“罂粟”，外面另贴了一张“勿再交给罗德里戈”的纸条。 # speaker:narrator
    【已找到藏药处】你还没有取走它。
    -> cabinet_menu
+ {game_available("take_poppy")} [趁修士背过身，取走一小包罂粟。 # id:take_poppy]
    {game_action("take_poppy"):
        你从夹层取下一只纸包，藏进衣服里。 # speaker:narrator
        【已取药】药包现在由你携带，还没有交给任何人。离开柜子后，可以走回罗德里戈身边。
    - else:
        这里已经没有能再取的药包。 # speaker:narrator
    }
    ++ [收好纸包，离开草药柜。 # id:leave]
        -> DONE
+ [离开草药柜。 # id:leave]
    -> DONE
