// Copy to story/dialogues/, change IDs, and INCLUDE from story/main.ink.
// Register the character and route before compiling. This template is not shipped in the story.
=== thomas_greeting ===
你是来找人的，还是来躲清静的？ # speaker:brother_thomas
+ [“只是路过。” # id:passing]
    那就随意。别碰窗边那摞书，我刚理好。 # speaker:brother_thomas
    ++ [“知道了。” # id:leave]
        -> DONE
+ [“晚点再聊。” # id:leave]
    -> DONE
