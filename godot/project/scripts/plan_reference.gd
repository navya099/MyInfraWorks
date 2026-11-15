extends RefCounted

static func build(design):
 var started=Time.get_ticks_usec()
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var info=alignment.configure_independent(design.pi_route,design.radii,design.spirals,design.pvi_stations,design.pvi_heights,design.pvi_lengths)
 if not info.ok:return info
 var points=PackedVector2Array()
 for point in alignment.polyline():points.append(Vector2(point.x,point.z))
 var low=INF
 var high=-INF
 for height in info.pvi_heights:
  low=min(low,height+design.offset)
  high=max(high,height+design.offset)
 var segments=profile_segments(info)
 return {"ok":true,"segments":segments,"points":points,"alignment":alignment,"info":info,"offset":design.offset,"low":low,"high":high,"length":info.length,"ms":(Time.get_ticks_usec()-started)/1000.0}


static func profile_segments(info):
 var segments=[]
 var stations=info.pvi_stations
 var heights=info.pvi_heights
 var lengths=info.pvi_lengths
 for i in range(stations.size()-1):
  var grade=(heights[i+1]-heights[i])/(stations[i+1]-stations[i])
  var start=stations[i]+lengths[i]/2.0
  var end=stations[i+1]-lengths[i+1]/2.0
  if end>start:segments.append({"start":start,"end":end,"height":heights[i]+grade*(start-stations[i]),"grade":grade,"acceleration":0.0})
  if i+1<stations.size()-1 and lengths[i+1]>0:
   var next_grade=(heights[i+2]-heights[i+1])/(stations[i+2]-stations[i+1])
   var length=lengths[i+1]
   segments.append({"start":end,"end":stations[i+1]+length/2.0,"height":heights[i+1]-grade*length/2.0,"grade":grade,"acceleration":(next_grade-grade)/length})
 return segments

static func profile_height(reference,station):
 if not is_finite(station) or station<0 or station>reference.length:return null
 var segments=reference.segments
 var low=0
 var high=segments.size()-1
 while low<high:
  var middle=(low+high)/2
  if segments[middle].end<station:low=middle+1
  else:high=middle
 var segment=segments[low]
 var x=station-segment.start
 return segment.height+segment.grade*x+segment.acceleration*x*x/2.0+reference.offset
