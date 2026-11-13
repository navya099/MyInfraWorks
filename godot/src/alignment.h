#pragma once
#include "alignment_math.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
class KRoadAlignment : public godot::RefCounted {
 GDCLASS(KRoadAlignment,godot::RefCounted)
 kroad::Alignment alignment;
protected:
 static void _bind_methods();
public:
 godot::Dictionary configure(const godot::PackedVector3Array&,const godot::PackedFloat64Array&,const godot::PackedFloat64Array&,const godot::PackedFloat64Array&);
 godot::Dictionary configure_independent(const godot::PackedVector3Array&,const godot::PackedFloat64Array&,const godot::PackedFloat64Array&,const godot::PackedFloat64Array&,const godot::PackedFloat64Array&,const godot::PackedFloat64Array&);
 godot::Dictionary sample(double s) const;
 godot::Dictionary geometry() const;
 godot::PackedVector3Array polyline() const;
 godot::Dictionary ribbon_crossfall(double width,double offset,double base,double center_x,double center_y,double left,double right) const;
 godot::Dictionary ribbon(double width,double offset,double base,double center_x,double center_y) const;
};
