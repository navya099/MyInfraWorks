extends RefCounted

static func build(reference,design,terrain,source):
 var core=ClassDB.instantiate("KRoadCore")
 if not core.set_cut_slope(design.cut_slope) or not core.set_crossfall(design.left_fall,design.right_fall):
  return {"ok":false,"error":"보관 횡단 설정이 유효하지 않습니다."}
 core.prepare_corridor(reference.route,design.width,design.offset,design.slope,terrain.Min,terrain.Max,max(terrain.Dx,terrain.Dy)*2.0)
 return {"ok":true,"core":core,"route":reference.route,"source":source,"width":design.width,"offset":design.offset,"slope":design.slope}

static func height(reference,x,y):
 return reference.core.design_height(reference.source,reference.route,x,y,reference.width,reference.offset,reference.slope)
