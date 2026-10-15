extends RefCounted
## Pure, closed condition language; no expression evaluation.
func evaluate(condition: Dictionary, state: Dictionary) -> Dictionary:
	if condition.is_empty():
		return {"ok": true, "reason": ""}
	if condition.has("all"):
		for child in condition.all:
			var result = evaluate(child, state)
			if not result.ok:
				return result
		return {"ok": true, "reason": ""}
	if condition.has("any"):
		var reasons: Array = []
		for child in condition.any:
			var result = evaluate(child, state)
			if result.ok:
				return result
			reasons.append(result.reason)
		return {"ok": false, "reason": " / ".join(reasons)}
	if condition.has("not"):
		var result = evaluate(condition["not"], state)
		return {"ok": not result.ok, "reason": "NOT 条件未满足" if result.ok else ""}
	var id = condition.get("id", "")
	var actual: Variant
	var expected = condition.get("value", true)
	match condition.get("kind", ""):
		"trait": actual = state.traits.get(id, 0)
		"affinity": actual = state.affinities.get(id, 0)
		"flag": actual = state.flags.get(id, false)
		"clue": actual = id in state.clues
		"phase":
			actual = state.phase_id
			expected = id
		"task": actual = state.task_states.get(id, "active")
		"once_unused": actual = id not in state.consumed_once_keys
		_: return {"ok": false, "reason": "未知条件: " + str(condition)}
	var passed = false
	match condition.get("op", "eq"):
		"eq": passed = actual == expected
		"gte": passed = actual >= expected
		"lte": passed = actual <= expected
	return {"ok": passed, "actual": actual, "expected": expected,
		"reason": "" if passed else "%s: %s %s %s 未满足" % [id, actual, condition.get("op", "eq"), expected]}
