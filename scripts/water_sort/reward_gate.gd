extends RefCounted
## Legacy integer request compatibility. String outcomes no longer authorize
## awards; the single owner controller consumes the trusted adapter instead.
var serial := 0
var pending: Dictionary = {}
var claimed: Dictionary = {}

func begin(kind: String) -> int:
	if kind not in ["bottle","slot"] or not pending.is_empty() or claimed.has(kind): return -1
	serial += 1
	pending = {"id":serial,"kind":kind}
	return serial

func resolve(id: int, outcome: String) -> String:
	# Deprecated integer/string trial boundary: no production grant authority.
	# DebugAdController consumes the fixed adapter's String identity exactly once.
	return ""

func cancel() -> void:
	pending = {}
