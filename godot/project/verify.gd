extends SceneTree
func _initialize():
 if not ClassDB.class_exists("KRoadCore"):
  push_error("KRoadCore extension not loaded")
  quit(1)
  return
 var core = ClassDB.instantiate("KRoadCore")
 if abs(core.interpolate_elevation(100.0, 200.0, 0.25) - 125.0) > 0.000001:
  push_error("Elevation interpolation failed")
  quit(2)
  return
 print("PASS: ", core.get_build_info(), " / elevation = 125m")
 quit(0)
