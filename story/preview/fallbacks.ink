// GENERATED from data/*.json. Change the source configuration, then rebuild.
// Inky-only game simulation. Production binds every EXTERNAL to real state.
VAR mock_trait_innovation = 0
VAR mock_trait_tradition = 0
VAR mock_trait_piety = 0
VAR mock_trait_secularity = 0
VAR mock_trait_cruelty = 0
VAR mock_trait_mercy = 0
VAR mock_affinity_npc_a = 0
VAR mock_affinity_npc_b = 0
VAR mock_flag_intro_done = false
VAR mock_flag_check_resolved = false
VAR mock_flag_check_passed = false
VAR mock_flag_promised_help = false
VAR mock_flag_refused_help = false
VAR mock_flag_poppy_taken = false
VAR mock_flag_poppy_held = false
VAR mock_flag_poppy_delivered = false
VAR mock_flag_request_closed = false
VAR mock_flag_cabinet_searched = false
VAR mock_flag_monk_warning_heard = false
VAR mock_clue_clue_a = false
VAR mock_phase = "phase_a"
VAR mock_outcome = ""
VAR mock_once_npc_a_intro = false
VAR mock_once_npc_a_delivery = false
VAR mock_once_npc_a_private_check = false
VAR mock_once_npc_b_greeting = false
VAR mock_once_cabinet_searched = false
VAR mock_once_cabinet_poppy = false
VAR mock_once_monk_warning = false
VAR mock_once_request_settlement = false

=== function game_flag(id) ===
{ id == "intro_done":
    ~ return mock_flag_intro_done
}
{ id == "check_resolved":
    ~ return mock_flag_check_resolved
}
{ id == "check_passed":
    ~ return mock_flag_check_passed
}
{ id == "promised_help":
    ~ return mock_flag_promised_help
}
{ id == "refused_help":
    ~ return mock_flag_refused_help
}
{ id == "poppy_taken":
    ~ return mock_flag_poppy_taken
}
{ id == "poppy_held":
    ~ return mock_flag_poppy_held
}
{ id == "poppy_delivered":
    ~ return mock_flag_poppy_delivered
}
{ id == "request_closed":
    ~ return mock_flag_request_closed
}
{ id == "cabinet_searched":
    ~ return mock_flag_cabinet_searched
}
{ id == "monk_warning_heard":
    ~ return mock_flag_monk_warning_heard
}
~ return false

=== function game_condition(id) ===
{ id == "private_topic":
    ~ return ((mock_affinity_npc_a >= 20.0) && (mock_clue_clue_a == true))
}
{ id == "intro_open":
    ~ return ((mock_flag_intro_done == false) && (mock_flag_poppy_delivered == false))
}
{ id == "can_inquire":
    ~ return (((mock_affinity_npc_a >= 20.0) && (mock_clue_clue_a == true)) && (mock_flag_check_resolved == false))
}
{ id == "can_end_request":
    ~ return (mock_phase == "phase_b" && (mock_flag_intro_done == true) && (mock_flag_poppy_delivered == false))
}
{ id == "evening":
    ~ return mock_phase == "phase_b"
}
{ id == "has_note":
    ~ return (mock_clue_clue_a == true)
}
~ return false

=== function game_check(id) ===
{ id == "ask_reason":
    ~ return (mock_trait_mercy >= 20.0)
}
~ return false

=== function game_available(id) ===
{ id == "prepare_pass":
    ~ return ((mock_flag_intro_done == false) && (mock_flag_poppy_delivered == false)) && !mock_once_npc_a_intro
}
{ id == "prepare_fail":
    ~ return ((mock_flag_intro_done == false) && (mock_flag_poppy_delivered == false)) && !mock_once_npc_a_intro
}
{ id == "refuse_help":
    ~ return ((mock_flag_intro_done == false) && (mock_flag_poppy_delivered == false)) && !mock_once_npc_a_intro
}
{ id == "hand_over":
    ~ return ((mock_flag_poppy_held == true) && (mock_flag_poppy_delivered == false)) && !mock_once_npc_a_delivery
}
{ id == "resolve_pass":
    ~ return ((mock_affinity_npc_a >= 20.0) && (mock_clue_clue_a == true)) && !mock_once_npc_a_private_check
}
{ id == "resolve_fail":
    ~ return ((mock_affinity_npc_a >= 20.0) && (mock_clue_clue_a == true)) && !mock_once_npc_a_private_check
}
{ id == "greet_b":
    ~ return !mock_once_npc_b_greeting
}
{ id == "search_cabinet":
    ~ return mock_phase == "phase_b" && !mock_once_cabinet_searched
}
{ id == "take_poppy":
    ~ return (mock_phase == "phase_b" && (mock_flag_cabinet_searched == true)) && !mock_once_cabinet_poppy
}
{ id == "monk_warning":
    ~ return !mock_once_monk_warning
}
{ id == "finish_delivery":
    ~ return (mock_flag_poppy_delivered == true) && !mock_once_request_settlement
}
{ id == "finish_refusal":
    ~ return (mock_flag_poppy_delivered == false) && !mock_once_request_settlement
}
~ return false

=== function game_action(id) ===
{not game_available(id):
    ~ return false
}
{id == "prepare_pass":
    ~ mock_trait_mercy += 20
    ~ mock_affinity_npc_a += 20
    ~ mock_flag_intro_done = true
    ~ mock_flag_promised_help = true
    ~ mock_once_npc_a_intro = true
    ~ return true
}
{id == "prepare_fail":
    ~ mock_trait_mercy += 0
    ~ mock_affinity_npc_a += 20
    ~ mock_flag_intro_done = true
    ~ mock_flag_promised_help = true
    ~ mock_once_npc_a_intro = true
    ~ return true
}
{id == "refuse_help":
    ~ mock_flag_intro_done = true
    ~ mock_flag_refused_help = true
    ~ mock_once_npc_a_intro = true
    ~ return true
}
{id == "hand_over":
    ~ mock_flag_poppy_held = false
    ~ mock_flag_poppy_delivered = true
    ~ mock_affinity_npc_a += 5
    ~ mock_once_npc_a_delivery = true
    ~ return true
}
{id == "resolve_pass":
    ~ mock_flag_check_resolved = true
    ~ mock_flag_check_passed = true
    ~ mock_once_npc_a_private_check = true
    ~ return true
}
{id == "resolve_fail":
    ~ mock_flag_check_resolved = true
    ~ mock_flag_check_passed = false
    ~ mock_once_npc_a_private_check = true
    ~ return true
}
{id == "greet_b":
    ~ mock_affinity_npc_b += 5
    ~ mock_once_npc_b_greeting = true
    ~ return true
}
{id == "search_cabinet":
    ~ mock_flag_cabinet_searched = true
    ~ mock_once_cabinet_searched = true
    ~ return true
}
{id == "take_poppy":
    ~ mock_flag_poppy_taken = true
    ~ mock_flag_poppy_held = true
    ~ mock_once_cabinet_poppy = true
    ~ return true
}
{id == "monk_warning":
    ~ mock_flag_monk_warning_heard = true
    ~ mock_once_monk_warning = true
    ~ return true
}
{id == "finish_delivery":
    ~ mock_flag_request_closed = true
    ~ mock_outcome = "outcome_a"
    ~ mock_once_request_settlement = true
    ~ return true
}
{id == "finish_refusal":
    ~ mock_flag_request_closed = true
    ~ mock_outcome = "outcome_b"
    ~ mock_once_request_settlement = true
    ~ return true
}
~ return false
