#include "alignment.h"
#include <godot_cpp/variant/packed_int32_array.hpp>
using namespace godot;
void KRoadAlignment::_bind_methods(){
 ClassDB::bind_method(D_METHOD("configure","points","radii","spirals","vertical_lengths"),&KRoadAlignment::configure);
 ClassDB::bind_method(D_METHOD("sample","station"),&KRoadAlignment::sample);
 ClassDB::bind_method(D_METHOD("geometry"),&KRoadAlignment::geometry);
 ClassDB::bind_method(D_METHOD("ribbon","width","offset","base","center_x","center_y"),&KRoadAlignment::ribbon);
 ClassDB::bind_method(D_METHOD("polyline"),&KRoadAlignment::polyline);
}
Dictionary KRoadAlignment::configure(const PackedVector3Array &p,const PackedFloat64Array &r,const PackedFloat64Array &ls,const PackedFloat64Array &v){
 Dictionary out;try{
  std::vector<kroad::Point> points;std::vector<double> radii,spirals,vertical;
  for(int i=0;i<p.size();i++)points.push_back({p[i].x,p[i].z,p[i].y});
  for(int i=0;i<r.size();i++)radii.push_back(r[i]);for(int i=0;i<ls.size();i++)spirals.push_back(ls[i]);for(int i=0;i<v.size();i++)vertical.push_back(v[i]);
  kroad::Alignment candidate;candidate.build(points,radii,spirals,vertical);candidate.tessellation();alignment=std::move(candidate);
  out=geometry();out["ok"]=true;
 }catch(const std::exception &e){out["ok"]=false;out["error"]=String(e.what());}return out;
}
Dictionary KRoadAlignment::sample(double s) const {
 auto q=alignment.sample(s);Dictionary out;
 out["point"]=Vector3(q.pose.x,q.elevation,q.pose.y);out["normal"]=Vector2(-std::sin(q.pose.heading),std::cos(q.pose.heading));
 out["x"]=q.pose.x;out["y"]=q.pose.y;out["elevation"]=q.elevation;out["heading"]=q.pose.heading;out["curvature"]=q.curvature;out["grade"]=q.grade;out["station"]=q.s;out["element"]=q.element;return out;
}
Dictionary KRoadAlignment::geometry() const {
 Dictionary out;PackedFloat64Array stations;Array elements;
 for(double s:alignment.stations)stations.push_back(s);
 for(const auto &e:alignment.elements){Dictionary value;value["type"]=String(e.type.c_str());value["station"]=e.s;value["length"]=e.length;value["k0"]=e.k0;value["k1"]=e.k1;value["pi"]=e.pi;elements.push_back(value);}
 out["length"]=alignment.total;out["pi_stations"]=stations;out["elements"]=elements;return out;
}
PackedVector3Array KRoadAlignment::polyline() const {
 PackedVector3Array result;for(double s:alignment.tessellation()){auto q=alignment.sample(s);result.push_back(Vector3(q.pose.x,q.elevation,q.pose.y));}return result;
}

Dictionary KRoadAlignment::ribbon(double width,double offset,double base,double center_x,double center_y) const {
 Dictionary out;PackedVector3Array vertices;PackedInt32Array indices;auto stations=alignment.tessellation();
 if(stations.size()<2)return out;
 for(size_t i=0;i<stations.size();i++){
  auto q=alignment.sample(stations[i]);double nx=-std::sin(q.pose.heading),ny=std::cos(q.pose.heading);
  for(int side:{-1,1})vertices.push_back(Vector3(q.pose.x+side*nx*width/2-center_x,q.elevation+offset+.5-base,q.pose.y+side*ny*width/2-center_y));
  if(i>0){int a=int(i-1)*2;for(int k:{a,a+1,a+2,a+1,a+3,a+2})indices.push_back(k);}
 }
 out["vertices"]=vertices;out["indices"]=indices;return out;
}
