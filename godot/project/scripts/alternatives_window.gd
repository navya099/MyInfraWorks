extends Window
signal capture_requested(name)
signal apply_requested(index)
signal rename_requested(index,name)
signal delete_requested(index)
signal save_requested
var library
var current_provider: Callable
var name_input: LineEdit
var table: Tree
var status: Label
var apply_button: Button
var selected=-1
var confirmation: ConfirmationDialog
var pending_delete=-1

func _ready():
 title="설계 대안 보관·전환"
 min_size=Vector2i(800,420)
 close_requested.connect(hide)
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 add_child(margin)
 var root=VBoxContainer.new()
 margin.add_child(root)
 var row=HBoxContainer.new()
 root.add_child(row)
 name_input=LineEdit.new()
 name_input.placeholder_text="대안 이름"
 name_input.max_length=60
 name_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_child(name_input)
 var capture=Button.new()
 capture.text="현재 설계 보관"
 capture.pressed.connect(func():capture_requested.emit(name_input.text))
 row.add_child(capture)
 apply_button=Button.new()
 apply_button.text="선택 대안 적용"
 apply_button.pressed.connect(func():apply_requested.emit(selected))
 row.add_child(apply_button)
 var rename=Button.new()
 rename.text="이름 변경"
 rename.pressed.connect(func():rename_requested.emit(selected,name_input.text))
 row.add_child(rename)
 var erase=Button.new()
 erase.text="선택 삭제"
 erase.pressed.connect(request_delete)
 row.add_child(erase)
 var save=Button.new()
 save.text="프로젝트 저장"
 save.pressed.connect(func():save_requested.emit())
 row.add_child(save)
 status=Label.new()
 status.text="대안은 같은 DEM의 설계만 보관합니다. 보관/이름 변경/삭제 후 프로젝트를 저장하세요."
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(status)
 table=Tree.new()
 table.columns=5
 table.hide_root=true
 table.column_titles_visible=true
 table.size_flags_vertical=Control.SIZE_EXPAND_FILL
 for i in range(5):table.set_column_title(i,["이름","길이(m)","PI 수","PVI 수","현재 설계와 비교"][i])
 table.item_selected.connect(func():
  var item=table.get_selected()
  if item==null:return
  selected=int(item.get_metadata(0))
  name_input.text=library.entries[selected].name
  update_apply_button())
 root.add_child(table)
 var hint=Label.new()
 hint.text="보관 후 프로젝트 저장 · 적용은 실행 취소 1단계 · DEM 중복 저장 없음 · 최대 20개"
 hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(hint)
 confirmation=ConfirmationDialog.new()
 confirmation.title="보관 대안 삭제"
 confirmation.confirmed.connect(func():
  if pending_delete>=0:delete_requested.emit(pending_delete)
  pending_delete=-1)
 add_child(confirmation)

func open_library():
 refresh()
 popup_centered(Vector2i(1050,540))

func refresh():
 if table==null:return
 confirmation.hide()
 pending_delete=-1
 table.set_block_signals(true)
 table.clear()
 var root=table.create_item()
 var current=current_provider.call()
 selected=clampi(selected,-1,library.entries.size()-1)
 for i in range(library.entries.size()):
  var entry=library.entries[i]
  var item=table.create_item(root)
  var cells=[entry.name,"%.3f" % entry.length,str(entry.pi),str(entry.pvi),"현재와 같음" if entry.design==current else "보관본"]
  for column in range(5):item.set_text(column,cells[column])
  item.set_metadata(0,i)
  if selected==i:item.select(0)
 table.set_block_signals(false)
 update_apply_button()

func update_apply_button():
 apply_button.disabled=selected<0 or selected>=library.entries.size()
 if not apply_button.disabled:apply_button.disabled=library.entries[selected].design==current_provider.call()

func request_delete():
 if selected<0 or selected>=library.entries.size():return
 pending_delete=selected
 confirmation.dialog_text="'%s' 보관본을 삭제합니다. 현재 설계는 유지합니다." % library.entries[selected].name
 confirmation.popup_centered(Vector2i(560,150))
