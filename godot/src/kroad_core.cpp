#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <algorithm>
using namespace godot;
class KRoadCore : public RefCounted {
 GDCLASS(KRoadCore, RefCounted)
protected:
 static void _bind_methods() {
  ClassDB::bind_method(D_METHOD("interpolate_elevation", "start_height", "end_height", "fraction"), &KRoadCore::interpolate_elevation);
  ClassDB::bind_method(D_METHOD("get_build_info"), &KRoadCore::get_build_info);
 }
public:
 double interpolate_elevation(double start_height, double end_height, double fraction) const {
  return start_height + (end_height-start_height)*std::clamp(fraction, 0.0, 1.0);
 }
 String get_build_info() const { return "K-ROAD C++ / MSVC x64 / GDExtension"; }
};
void initialize_kroad(ModuleInitializationLevel level) { if(level==MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<KRoadCore>(); }
void uninitialize_kroad(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT kroad_library_init(GDExtensionInterfaceGetProcAddress proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization *init) {
 GDExtensionBinding::InitObject obj(proc,library,init);
 obj.register_initializer(initialize_kroad); obj.register_terminator(uninitialize_kroad);
 obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return obj.init();
}
