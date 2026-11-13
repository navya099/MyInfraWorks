extends Window
signal station_selected(station)
const COLUMNS=["station_m","local_east_m","local_south_m","easting_m","northing_m","crs","center_elevation_m","ground_elevation_m","center_minus_ground_m","grade_pct","curvature_per_m","radius_m","left_edge_elevation_m","right_edge_elevation_m","ground_status","station_step_m","width_m","offset_m","left_down_pct","right_down_pct","events"]
var snapshot_provider: Callable
var revision_provider: Callable
var worker: Thread
var generation=0
var requested_generation=-1
var requested_revision=-1
var result_revision=-1
var result={}
var interval: SpinBox
var status: Label
var table: TextEdit
var csv_button: Button
var csv_dialog: FileDialog
var setting_table=false

func _ready():
 title="노선 측점표"
 min_size=Vector2i(1000,500)
 close_requested.connect(hide)
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 add_child(margin)
 var root=VBoxContainer.new()
 margin.add_child(root)
 var row=HBoxContainer.new()
 root.add_child(row)
 var label=Label.new()
 label.text="측점 간격(m)"
 row.add_child(label)
 interval=SpinBox.new()
 interval.min_value=0.1
 interval.max_value=10000
 interval.step=0.1
 interval.value=20
 interval.value_changed.connect(func(_value):invalidate())
 row.add_child(interval)
 var calculate=Button.new()
 calculate.text="산출"
 calculate.pressed.connect(start_calculation)
 row.add_child(calculate)
 csv_button=Button.new()
 csv_button.text="CSV 저장"
 csv_button.disabled=true
 csv_button.pressed.connect(func():csv_dialog.popup_centered_ratio(0.7))
 row.add_child(csv_button)
 status=Label.new()
 status.text="노선 작성 후 산출하세요."
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(status)
 var hint=Label.new()
 hint.text="행 선택: 측점 이동 · 좌표는 로컬 동/남 · CSV에 EPSG:5179 좌표 포함(원점 정보가 있는 DEM) · 지반/차이 NA는 결측"
 hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(hint)
 table=TextEdit.new()
 table.editable=false
 table.wrap_mode=TextEdit.LINE_WRAPPING_NONE
 table.size_flags_vertical=Control.SIZE_EXPAND_FILL
 table.add_theme_color_override("font_readonly_color",Color("dce8f2"))
 table.caret_changed.connect(select_row)
 root.add_child(table)
 csv_dialog=FileDialog.new()
 csv_dialog.access=FileDialog.ACCESS_FILESYSTEM
 csv_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 csv_dialog.filters=PackedStringArray(["*.csv ; Alignment station CSV"])
 csv_dialog.file_selected.connect(export_csv)
 add_child(csv_dialog)

func invalidate():
 generation+=1
 result={}
 result_revision=-1
 if csv_button!=null:csv_button.disabled=true
 if table!=null:table.text=""
 if status!=null:status.text="설계·간격 변경 후 다시 산출하세요."

func start_calculation():
 if worker!=null:
  status.text="이전 산출 종료를 기다려 주세요."
  return
 var state=snapshot_provider.call()
 invalidate()
 requested_revision=state.revision
 requested_generation=generation
 status.text="측점표 산출 중"
 worker=Thread.new()
 if worker.start(calculate_job.bind(state.snapshot,interval.value))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

static func calculate_job(snapshot,step):
 var started=Time.get_ticks_usec()
 if not is_finite(step) or step<0.1 or step>10000:return {"ok":false,"error":"측점 간격은 0.1~10000m입니다."}
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var info=alignment.configure_independent(snapshot.pi_route,snapshot.radii,snapshot.spirals,snapshot.pvi_stations,snapshot.pvi_heights,snapshot.pvi_lengths)
 if not info.ok:return info
 if info.length<=0:return {"ok":false,"error":"두 점 이상의 유효한 노선이 필요합니다."}
 var count=ceili(info.length/step)
 if count+1>20000:return {"ok":false,"error":"측점 수가 20000개를 넘습니다. 간격을 늘리세요."}
 var events=[{"s":0.0,"tag":"start","priority":3},{"s":float(info.length),"tag":"end","priority":3}]
 for i in range(1,count):events.append({"s":i*step,"tag":"regular","priority":1})
 for element in info.elements:
  events.append({"s":float(element.station),"tag":"geometry_boundary","priority":2})
  events.append({"s":float(element.station+element.length),"tag":"geometry_boundary","priority":2})
 for station in info.pi_stations:events.append({"s":float(station),"tag":"PI","priority":2})
 for i in range(info.pvi_stations.size()):
  events.append({"s":float(info.pvi_stations[i]),"tag":"PVI","priority":2})
  if info.pvi_lengths[i]>0:
   events.append({"s":float(info.pvi_stations[i]-info.pvi_lengths[i]/2),"tag":"vertical_curve_start","priority":2})
   events.append({"s":float(info.pvi_stations[i]+info.pvi_lengths[i]/2),"tag":"vertical_curve_end","priority":2})
 events.sort_custom(func(a,b):return a.s<b.s)
 var unique=[]
 for event in events:
  if not unique.is_empty() and abs(unique[-1].s-event.s)<0.000001:
   if event.tag not in unique[-1].tags:unique[-1].tags.append(event.tag)
   if event.priority>unique[-1].priority:
    unique[-1].s=event.s
    unique[-1].priority=event.priority
  else:unique.append({"s":event.s,"tags":[event.tag],"priority":event.priority})
 if unique.size()>20000:return {"ok":false,"error":"경계 측점을 포함해 20000개를 넘습니다. 간격을 늘리세요."}
 var source=snapshot.source
 var geo=typeof(source.get("OriginX")) in [TYPE_INT,TYPE_FLOAT] and typeof(source.get("OriginY")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(source.OriginX)) and is_finite(float(source.OriginY))
 var core=ClassDB.instantiate("KRoadCore")
 var rows=[]
 var missing=0
 var left=snapshot.get("left_fall",0.0)
 var right=snapshot.get("right_fall",0.0)
 for event in unique:
  var at=alignment.sample(event.s)
  var ground=core.sample_height(source,at.x,at.y)
  var planned=at.elevation+snapshot.offset
  if not is_finite(ground):missing+=1
  rows.append({"station":event.s,"x":at.x,"y":at.y,"easting":float(source.OriginX)+at.x if geo else null,"northing":float(source.OriginY)-at.y if geo else null,"planned":planned,"ground":ground if is_finite(ground) else null,"delta":planned-ground if is_finite(ground) else null,"grade":at.grade*100.0,"curvature":at.curvature,"radius":abs(1.0/at.curvature) if abs(at.curvature)>=1e-12 else null,"left_edge":planned-snapshot.width/2.0*left/100.0,"right_edge":planned-snapshot.width/2.0*right/100.0,"events":"|".join(event.tags)})
 return {"ok":true,"rows":rows,"missing":missing,"crs":"EPSG:5179" if geo else "LOCAL","step":step,"width":snapshot.width,"offset":snapshot.offset,"left_fall":left,"right_fall":right,"length":info.length,"ms":(Time.get_ticks_usec()-started)/1000.0}

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation:
  status.text="변경 전의 산출 결과를 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="산출 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="%d개 측점 · 지반 결측 %d개 · %s · %.1fms · 곡률 0의 반경은 CSV 빈 셀" % [result.rows.size(),result.missing,result.crs,result.ms]
 var lines=PackedStringArray(["STA(m) | 로컬 동 X | 남 Y | 중심 계획고 | 지반고 | 계획−지반 | 구배(%) | 반경(m) | 좌 가장자리 | 우 가장자리 | 경계"])
 for row in result.rows:lines.append("%.3f | %.3f | %.3f | %.3f | %s | %s | %.3f | %s | %.3f | %.3f | %s" % [row.station,row.x,row.y,row.planned,display_number(row.ground),display_number(row.delta),row.grade,"직선" if row.radius==null else display_number(row.radius),row.left_edge,row.right_edge,event_text(row.events)])
 setting_table=true
 table.text="\n".join(lines)
 setting_table=false

static func event_text(raw):
 var titles={"start":"시점","end":"종점","regular":"정규","PI":"PI","PVI":"PVI","geometry_boundary":"평면 경계","vertical_curve_start":"종단곡선 시작","vertical_curve_end":"종단곡선 끝"}
 var labels=PackedStringArray()
 for tag in raw.split("|"):labels.append(titles.get(tag,tag))
 return "/".join(labels)

static func display_number(value):
 return "NA" if value==null else "%.3f" % value

func select_row():
 if setting_table or result.is_empty() or result_revision!=revision_provider.call():return
 var index=table.get_caret_line()-1
 if index>=0 and index<result.rows.size():station_selected.emit(result.rows[index].station)

func export_csv(path):
 if result.is_empty() or result_revision!=revision_provider.call():
  invalidate()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(COLUMNS))
 for row in result.rows:
  var values=[row.station,row.x,row.y,row.easting,row.northing,result.crs,row.planned,row.ground,row.delta,row.grade,row.curvature,row.radius,row.left_edge,row.right_edge,"nodata" if row.ground==null else "ok",result.step,result.width,result.offset,result.left_fall,result.right_fall,row.events]
  var cells=PackedStringArray()
  for value in values:cells.append("" if value==null else str(value))
  file.store_csv_line(cells)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="측점표 CSV 저장 완료 · 단위 m / 구배 % / 곡률 1/m"
 return true

func _exit_tree():
 if worker!=null:worker.wait_to_finish()
