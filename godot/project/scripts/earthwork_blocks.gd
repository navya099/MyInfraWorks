extends RefCounted
const RangeCalculation=preload("res://scripts/earthwork_range.gd")

static func calculate(report,begin,finish,block_length):
 var started=Time.get_ticks_usec()
 if not is_finite(block_length) or block_length<1 or block_length>1000000:
  return RangeCalculation.fail("분할 길이는 1~1,000,000m의 유한한 값이어야 합니다.")
 if not is_finite(begin) or not is_finite(finish) or finish<=begin:
  return RangeCalculation.fail("시작보다 큰 끝 측점을 입력하세요.")
 begin=float(begin)
 finish=float(finish)
 block_length=float(block_length)
 var count_value=(finish-begin)/block_length
 if count_value>1001:return RangeCalculation.fail("분할 구간은 최대 1,000개입니다. 분할 길이를 늘리세요.")
 var count=max(1,ceili(count_value))
 if count>1 and abs(begin+(count-1)*block_length-finish)<=max(1e-9,abs(finish)*1e-14):count-=1
 if count>1000:return RangeCalculation.fail("분할 구간은 최대 1,000개입니다. 분할 길이를 늘리세요.")
 var total=RangeCalculation.calculate(report,begin,finish)
 if not total.ok:return total
 total.rows=[] # Keep only the total; detailed intervals are released before partitioning.
 var sections=report.sections
 var first=0
 var last=1
 var groups=[]
 var counts={"complete":0,"partial":0,"missing":0}
 for index in range(count):
  var a=begin+index*block_length
  var b=finish if index==count-1 else begin+(index+1)*block_length
  while first+1<sections.size() and sections[first+1].station<=a:first+=1
  last=max(last,first+1)
  while last<sections.size()-1 and sections[last].station<b:last+=1
  var group=RangeCalculation.calculate({"ok":true,"sections":sections.slice(first,last+1)},a,b)
  if not group.ok:return group
  group.erase("rows")
  group.index=index+1
  counts[group.status]+=1
  groups.append(group)
 total.rows=groups
 total.block_length=block_length
 total.counts=counts
 total.ms=(Time.get_ticks_usec()-started)/1000.0
 return total
