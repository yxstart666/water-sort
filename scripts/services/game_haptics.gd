extends RefCounted
## A request is not proof that hardware vibrated. Desktop never dispatches.
const TAP_MS := 18
const TAP_AMPLITUDE := 0.35
var enabled := true
var platform: Callable
var dispatch: Callable

func _init(platform_provider: Callable = Callable(), dispatcher: Callable = Callable()) -> void:
	platform = platform_provider if platform_provider.is_valid() else OS.get_name
	dispatch = dispatcher if dispatcher.is_valid() else Input.vibrate_handheld

func tap() -> bool:
	if not enabled or platform.call() != "Android": return false
	dispatch.call(TAP_MS, TAP_AMPLITUDE)
	return true
