extends Window
signal station_selected(station)
var snapshot_provider: Callable
var revision_provider: Callable
var worker: Thread
var requested_revision=-1
var result_revision=-1
var generation=0
var requested_generation=-1
var result={}
var interval: SpinBox
var reach: SpinBox
var lateral: SpinBox
var status: Label
var summary: Label
var table: TextEdit
var csv_button: Button
var csv_dialog: FileDialog
var setting_table=false

func _ready():
 title="절토·성토량 / 평균단면법"
 min_size=Vector2i(900,520)
 close_requested.connect(hide)
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:
  margin.add_theme_constant_override("margin_"+side,12)
 add_child(margin)
 var root=VBoxContainer.new()
 margin.add_child(root)
 var settings=HBoxContainer.new()
 root.add_child(settings)
 interval=number(settings,"측점 간격(m)",20,1,1000,1)
 reach=number(settings,"조사 반폭(m)",300,5,10000,5)
 lateral=number(settings,"횡단 간격(m)",2,0.1,50,0.1)
 var calculate=Button.new()
 calculate.text="계산"
 calculate.pressed.connect(start_calculation)
 settings.add_child(calculate)
 csv_button=Button.new()
 csv_button.text="CSV 저장"
 csv_button.disabled=true
 csv_button.pressed.connect(func():csv_dialog.popup_centered_ratio(0.7))
 settings.add_child(csv_button)
 status=Label.new()
 status.text="계산은 별도 스레드에서 수행합니다."
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(status)
 summary=Label.new()
 summary.text="노선을 작성한 뒤 계산하세요."
 summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(summary)
 var note=Label.new()
 note.text="개략 추정 · 곡선 면적중심/중첩/토량변화율 보정 없음 · 행 클릭: 횡단 측점 이동"
 root.add_child(note)
 table=TextEdit.new()
 table.editable=false
 table.size_flags_vertical=Control.SIZE_EXPAND_FILL
 table.add_theme_color_override("font_readonly_color",Color("dce8f2"))
 table.caret_changed.connect(func():
  if setting_table or result.is_empty():return
  var index=table.get_caret_line()-1
  if index>=0 and index<result.sections.size():station_selected.emit(result.sections[index].station))
 root.add_child(table)
 csv_dialog=FileDialog.new()
 csv_dialog.access=FileDialog.ACCESS_FILESYSTEM
 csv_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 csv_dialog.filters=PackedStringArray(["*.csv ; Earthwork CSV"])
 csv_dialog.file_selected.connect(export_csv)
 add_child(csv_dialog)

func number(parent,label_text,value,minimum,maximum,step):
 var label=Label.new()
 label.text=label_text
 parent.add_child(label)
 var input=SpinBox.new()
 input.min_value=minimum
 input.max_value=maximum
 input.step=step
 input.value=value
 input.value_changed.connect(func(_value):invalidate())
 parent.add_child(input)
 return input

func invalidate():
 generation+=1
 result={}
 result_revision=-1
 if csv_button!=null:csv_button.disabled=true
 if status!=null:status.text="설계 또는 계산 조건 변경 · 다시 계산하세요."
 if summary!=null:summary.text="이전 수량은 현재 설계에 사용할 수 없습니다."
 if table!=null:table.text=""

func start_calculation():
 if worker!=null:
  status.text="기존 계산 종료를 기다리는 중입니다. 카메라는 계속 사용할 수 있습니다."
  return
 var state=snapshot_provider.call()
 if state.length<=0:
  status.text="두 점 이상의 유효한 노선이 필요합니다."
  return
 invalidate()
 requested_revision=state.revision
 requested_generation=generation
 status.text="토공량 계산 중 · DEM 결측 및 사면 미접속 구간 검사"
 worker=Thread.new()
 var error=worker.start(calculate_job.bind(state.snapshot,interval.value,reach.value,lateral.value))
 if error!=OK:
  worker=null
  status.text="계산 스레드를 시작하지 못했습니다."

static func calculate_job(snapshot,station_step,half_width,lateral_step):
 var started=Time.get_ticks_usec()
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var info=alignment.configure_independent(snapshot.pi_route,snapshot.radii,snapshot.spirals,snapshot.pvi_stations,snapshot.pvi_heights,snapshot.pvi_lengths)
 if not info.ok:return info
 var stations=[0.0,float(info.length)]
 var count=ceili(info.length/station_step)
 if count>20000:return {"ok":false,"error":"측점 수가 너무 많습니다. 간격을 늘리세요."}
 for i in range(1,count):stations.append(min(info.length,i*station_step))
 for element in info.elements:
  stations.append(element.station)
  stations.append(element.station+element.length)
 for i in range(info.pvi_stations.size()):
  stations.append(info.pvi_stations[i])
  if info.pvi_lengths[i]>0:
   stations.append(info.pvi_stations[i]-info.pvi_lengths[i]/2)
   stations.append(info.pvi_stations[i]+info.pvi_lengths[i]/2)
 stations.sort()
 var unique=PackedFloat64Array()
 var poses=PackedFloat64Array()
 for station in stations:
  if unique.size()>0 and abs(station-unique[-1])<0.00001:continue
  unique.append(station)
  var at=alignment.sample(station)
  poses.append_array(PackedFloat64Array([at.x,at.y,at.elevation,-sin(at.heading),cos(at.heading)]))
 var core=ClassDB.instantiate("KRoadCore")
 core.set_crossfall(snapshot.get("left_fall",0.0),snapshot.get("right_fall",0.0))
 core.prepare_corridor(snapshot.route,snapshot.width,snapshot.offset,snapshot.slope,snapshot.terrain.Min,snapshot.terrain.Max,max(max(snapshot.terrain.Dx,snapshot.terrain.Dy)*2,lateral_step*2))
 var report=core.earthwork_sections(snapshot.source,unique,poses,snapshot.width,snapshot.offset,snapshot.slope,half_width,lateral_step)
 report.station_step=station_step
 report.half_width=half_width
 report.lateral_step=lateral_step
 report.ms=(Time.get_ticks_usec()-started)/1000.0
 return report

func _process(_delta):
 if worker!=null and not worker.is_alive():
  var completed=worker.wait_to_finish()
  worker=null
  if requested_generation!=generation or requested_revision!=revision_provider.call():
   status.text="계산 중 설계가 바뀌어 결과를 버렸습니다. 다시 계산하세요."
   return
  if not completed.ok:
   status.text="계산 실패: "+str(completed.get("error","unknown"))
   return
  result=completed
  result_revision=requested_revision
  show_result()

func show_result():
 csv_button.disabled=false
 var label="전 구간 추정량" if result.complete else "유효 구간 부분합"
 summary.text="%s | 절토 %.1f m³ / 성토 %.1f m³ / 절토−성토 %.1f m³\n산출 길이 %.1f / %.1f m (%.2f%%) · 제외 구간 %d · 무효 단면 %d" % [label,result.cut_volume,result.fill_volume,result.net_cut_minus_fill,result.covered_length,result.total_length,result.coverage*100,result.excluded_intervals,result.invalid_sections]
 status.text="%.1f ms / %d개 단면 · nodata: 결측·경계 / unclosed: 조사폭 끝 절성토 잔존" % [result.ms,result.sections.size()]
 var lines=PackedStringArray(["STA(m) | 계획고(m) | 절토면적(m²) | 성토면적(m²) | 단면 상태 | 구간 절토/성토(m³)"])
 for row in result.sections:
  lines.append("%.3f | %.3f | %s | %s | %s | %s / %s" % [row.station,row.elevation,number_text(row.cut_area),number_text(row.fill_area),row.status,number_text(row.cut_volume),number_text(row.fill_volume)])
 setting_table=true
 table.text="\n".join(lines)
 setting_table=false

static func number_text(value):
 return "NA" if value==null else "%.3f" % value

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
 file.store_csv_line(PackedStringArray(["method","station_step_m","half_width_m","lateral_step_m","complete","coverage_ratio","station_m","elevation_m","cut_area_m2","fill_area_m2","section_status","interval_length_m","cut_volume_m3","fill_volume_m3","interval_status","cumulative_cut_m3","cumulative_fill_m3","left_down_pct","right_down_pct"]))
 for row in result.sections:
  file.store_csv_line(PackedStringArray(["average_end_area",str(result.station_step),str(result.half_width),str(result.lateral_step),str(result.complete),str(result.coverage),str(row.station),str(row.elevation),"" if row.cut_area==null else str(row.cut_area),"" if row.fill_area==null else str(row.fill_area),row.status,str(row.interval_length),"" if row.cut_volume==null else str(row.cut_volume),"" if row.fill_volume==null else str(row.fill_volume),row.interval_status,str(row.cumulative_cut),str(row.cumulative_fill),str(result.left_fall),str(result.right_fall)]))
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="CSV 저장 완료 · 결측 수량은 빈 셀로 기록했습니다."
 return true

func _exit_tree():
 if worker!=null:worker.wait_to_finish()
