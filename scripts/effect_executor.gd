extends RefCounted
var content
var conditions

func _init(db = null, evaluator = null) -> void:
	content = db
	conditions = evaluator

func apply(effects: Array, snapshot: Dictionary) -> Dictionary:
	# Validate the whole batch before touching the copy. Never mutate the input.
	var error = content.validate_effects(effects)
	if not error.is_empty(): return {"ok": false, "error": error}
	var next = snapshot.duplicate(true)
	for effect in effects:
		var id = effect.id
		match effect.type:
			"add_trait": next.traits[id] += int(effect.amount)
			"add_affinity": next.affinities[id] += int(effect.amount)
			"set_flag": next.flags[id] = effect.value
			"add_clue":
				if id not in next.clues: next.clues.append(id)
			"set_phase": next.phase_id = id
			"select_outcome":
				if next.selected_outcome != null: return {"ok": false, "error": "已经结算"}
				var result = conditions.evaluate(content.data.outcomes[id].condition, next)
				if not result.ok: return {"ok": false, "error": result.reason}
				next.selected_outcome = id
	return {"ok": true, "state": next}
