extends SceneTree
var failures=[]
func check(value,label):
 print(("PASS " if value else "FAIL ")+label)
 if not value:failures.append(label)
func poses(height):
 return PackedFloat64Array([50,100,height,0,1,100,100,height,0,1,150,100,height,0,1])
func _initialize():
 var core=ClassDB.instantiate("KRoadCore")
 var values=PackedFloat64Array()
 values.resize(21*21)
 values.fill(100)
 var terrain={"Nx":21,"Ny":21,"Dx":10.0,"Dy":10.0,"Heights":values}
 var stations=PackedFloat64Array([0,50,100])
 var fill=core.earthwork_sections(terrain,stations,poses(102),20,0,1.5,40,2)
 check(fill.ok and fill.complete,"flat fill complete")
 check(abs(fill.sections[0].fill_area-46)<1e-8,"analytic trapezoid area with non-grid daylight")
 check(abs(fill.fill_volume-4600)<1e-8 and fill.cut_volume==0,"analytic constant fill volume")
 var coarse=core.earthwork_sections(terrain,stations,poses(102),20,0,1.5,40,7)
 check(abs(coarse.fill_volume-4600)<1e-8,"zero crossing integration independent of lateral alignment")
 var cut=core.earthwork_sections(terrain,stations,poses(98),20,0,1.5,40,3)
 check(abs(cut.cut_volume-4600)<1e-8 and cut.fill_volume==0,"analytic constant cut volume")
 var balance=core.earthwork_sections(terrain,stations,poses(100),20,0,1.5,40,2)
 check(balance.complete and balance.cut_volume==0 and balance.fill_volume==0,"valid zero volume distinguished from missing data")
 var slope=values.duplicate()
 for y in range(21):
  for x in range(21):slope[y*21+x]=100+0.2*(y*10-100)
 var plane=terrain.duplicate()
 plane.Heights=slope
 var mixed=core.earthwork_sections(plane,stations,poses(100),20,0,1.5,40,2)
 check(abs(mixed.sections[0].fill_area-100.0/7)<1e-8 and abs(mixed.sections[0].cut_area-100.0/7)<1e-8,"mixed cut/fill section analytic areas")
 var missing=values.duplicate()
 missing[10*21+10]=NAN
 var hole=terrain.duplicate()
 hole.Heights=missing
 var partial=core.earthwork_sections(hole,stations,poses(102),20,0,1.5,40,2)
 check(partial.sections[1].status=="nodata" and partial.sections[1].fill_area==null,"NoData section has null area, not zero")
 check(partial.covered_length==0 and partial.excluded_intervals==2 and not partial.complete,"missing section does not bridge two intervals")
 check(partial.sections[2].fill_volume==null,"excluded interval has null volume")
 var unclosed=core.earthwork_sections(terrain,stations,poses(200),20,0,1.5,40,2)
 check(unclosed.sections[0].status=="unclosed" and unclosed.coverage==0,"unfinished slopes excluded instead of truncated volume")
 check(not core.earthwork_sections(terrain,PackedFloat64Array([0,0,100]),poses(102),20,0,1.5,40,2).ok,"duplicate station rejected")
 check(not core.earthwork_sections(terrain,stations,poses(102),20,0,1.5,5,2).ok,"investigation width narrower than road rejected")
 # Same surface used by rendering: indexed corridor agrees on a straight section.
 core.prepare_corridor(PackedVector3Array([Vector3(50,102,100),Vector3(150,102,100)]),20,0,1.5,100,100,20)
 var indexed=core.earthwork_sections(terrain,stations,poses(102),20,0,1.5,40,2)
 check(abs(indexed.fill_volume-4600)<1e-8,"indexed planned surface quantities agree")
 print("PASS EARTHWORK CORE" if failures.is_empty() else "FAIL EARTHWORK CORE")
 quit(0 if failures.is_empty() else 1)
