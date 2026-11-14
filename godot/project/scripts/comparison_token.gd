extends RefCounted
var mutex=Mutex.new()
var cancelled=false
var index=0
var total=0
var name=""
func cancel():
 mutex.lock()
 cancelled=true
 mutex.unlock()
func is_cancelled():
 mutex.lock()
 var value=cancelled
 mutex.unlock()
 return value
func progress(done,count,label):
 mutex.lock()
 index=done
 total=count
 name=label
 mutex.unlock()
func read():
 mutex.lock()
 var value={"index":index,"total":total,"name":name,"cancelled":cancelled}
 mutex.unlock()
 return value
