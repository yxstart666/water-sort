extends RefCounted
## Minimum physical window extent for native mobile density-independent targets.
const MINIMUM_LOGICAL:=44.1
static func minimum_window_pixels()->float:
	# Android screen_get_scale uses scaled font density and a window-size cap;
	# it is not dp density. Use reported densityDpi/160. iOS uses native scale.
	# The final canvas transform already accounts for viewport stretch.
	var density:=1.0
	if OS.get_name()=="Android":density=float(DisplayServer.screen_get_dpi())/160.0
	elif OS.get_name()=="iOS":density=DisplayServer.screen_get_scale()
	return MINIMUM_LOGICAL*maxf(.01,density)
