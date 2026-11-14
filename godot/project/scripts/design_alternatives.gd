extends RefCounted
const Model=preload("res://scripts/road_model.gd")
const MAX_ENTRIES=20
var entries=[]

static func valid_name(value):
 return value is String and not value.strip_edges().is_empty() and value.length()<=60 and "\n" not in value and "\r" not in value and "\t" not in value

static func validate_design(state,terrain,source):
 if not state is Dictionary:return {"ok":false,"error":"대안 설계 형식 오류"}
 if not state.get("pi_route") is PackedVector3Array:return {"ok":false,"error":"대안 PI 형식 오류"}
 var count=state.pi_route.size()
 if count<2:return {"ok":false,"error":"대안은 두 점 이상의 노선이 필요합니다."}
 for key in ["radii","spirals","vertical_lengths","pvi_stations","pvi_heights","pvi_lengths"]:
  if not state.get(key) is PackedFloat64Array:return {"ok":false,"error":"대안 배열 형식 오류: "+key}
 for key in ["radii","spirals","vertical_lengths"]:
  if state[key].size()!=count:return {"ok":false,"error":"대안 PI 배열 수 오류"}
 if state.pvi_stations.size()<2 or state.pvi_stations.size()!=state.pvi_heights.size() or state.pvi_stations.size()!=state.pvi_lengths.size():return {"ok":false,"error":"대안 PVI 배열 수 오류"}
 for key in ["radii","spirals","vertical_lengths","pvi_stations","pvi_heights","pvi_lengths"]:
  for value in state[key]:
   if not is_finite(value):return {"ok":false,"error":"대안 배열의 비유한 값"}
 var bounds={"width":[1,200],"offset":[-1000,1000],"slope":[0.1,10],"cut_slope":[0.1,10],"left_fall":[-12,12],"right_fall":[-12,12]}
 for key in bounds:
  var value=state.get(key)
  if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value<bounds[key][0] or value>bounds[key][1]:return {"ok":false,"error":"대안 설정 범위 오류: "+key}
 var ex=(int(terrain.Nx)-1)*float(terrain.Dx)
 var ey=(int(terrain.Ny)-1)*float(terrain.Dy)
 for point in state.pi_route:
  if not point.is_finite() or point.x<0 or point.z<0 or point.x>ex or point.z>ey:return {"ok":false,"error":"대안 좌표가 지형 범위를 벗어났습니다."}
 var model=Model.new()
 model.terrain=terrain
 model.source=source
 var error=model.restore(state)
 if error!="":return {"ok":false,"error":"대안 선형 오류: "+error}
 return {"ok":true,"design":model.edit_state(),"length":model.length(),"pi":count,"pvi":model.pvi_stations.size()}

static func decode(raw,terrain,source):
 if not raw is Array or raw.size()>MAX_ENTRIES:return {"ok":false,"error":"대안 목록 형식 또는 개수 오류"}
 var decoded=[]
 var names=[]
 for entry in raw:
  if not entry is Dictionary or not valid_name(entry.get("name")):return {"ok":false,"error":"대안 이름 오류"}
  var name=entry.name.strip_edges()
  if name in names:return {"ok":false,"error":"중복 대안 이름"}
  var checked=validate_design(entry.get("design"),terrain,source)
  if not checked.ok:return checked
  checked.name=name
  decoded.append(checked)
  names.append(name)
 return {"ok":true,"entries":decoded}

func capture(name,model):
 if not valid_name(name):return "이름은 1~60자이며 줄바꿈을 넣을 수 없습니다."
 name=name.strip_edges()
 for entry in entries:
  if entry.name==name:return "같은 이름의 대안이 있습니다."
 if entries.size()>=MAX_ENTRIES:return "최대 20개까지 보관합니다."
 if model.length()<=0:return "두 점 이상의 노선을 작성하세요."
 entries.append({"name":name,"design":model.edit_state(),"length":model.length(),"pi":model.route.size(),"pvi":model.pvi_stations.size()})
 return ""

func rename(index,name):
 if index<0 or index>=entries.size():return "대안을 선택하세요."
 if not valid_name(name):return "이름은 1~60자이며 줄바꿈을 넣을 수 없습니다."
 name=name.strip_edges()
 for i in range(entries.size()):
  if i!=index and entries[i].name==name:return "같은 이름의 대안이 있습니다."
 entries[index].name=name
 return ""

func serialize():
 var result=[]
 for entry in entries:result.append({"name":entry.name,"design":entry.design.duplicate(true)})
 return result
