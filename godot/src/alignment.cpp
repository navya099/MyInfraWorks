#include "alignment.h"
#include "crossfall.h"
#include <godot_cpp/variant/packed_int32_array.hpp>
using namespace godot;
void KRoadAlignment::_bind_methods(){
 ClassDB::bind_method(D_METHOD("sampling_stations"),&KRoadAlignment::sampling_stations);
 ClassDB::bind_method(D_METHOD("ribbon_crossfall","width","offset","base","center_x","center_y","left_percent","right_percent"),&KRoadAlignment::ribbon_crossfall);
 ClassDB::bind_method(D_METHOD("configure","points","radii","spirals","vertical_lengths"),&KRoadAlignment::configure);
 ClassDB::bind_method(D_METHOD("configure_independent","points","radii","spirals","stations","heights","lengths"),&KRoadAlignment::configure_independent);
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
Dictionary KRoadAlignment::configure_independent(const PackedVector3Array &p,const PackedFloat64Array &r,const PackedFloat64Array &ls,const PackedFloat64Array &stations,const PackedFloat64Array &heights,const PackedFloat64Array &lengths){
 Dictionary out;try{
  std::vector<kroad::Point> points;std::vector<double> radii,spirals,zero(p.size(),0);
  for(int i=0;i<p.size();i++)points.push_back({p[i].x,p[i].z,p[i].y});
  for(int i=0;i<r.size();i++)radii.push_back(r[i]);for(int i=0;i<ls.size();i++)spirals.push_back(ls[i]);
  if(stations.size()!=heights.size()||stations.size()!=lengths.size())throw std::runtime_error("Independent profile array size mismatch");
  kroad::Alignment candidate;candidate.build(points,radii,spirals,zero);
  std::vector<kroad::Pvi> values;for(int i=0;i<stations.size();i++){if(!std::isfinite(stations[i]))throw std::runtime_error("Non-finite PVI station");values.push_back({stations[i],heights[i],lengths[i]});}
  // The terminal PVI is anchored to the horizontal endpoint; interior stations stay absolute.
  if(!values.empty())values.back().station=candidate.total;
  candidate.set_profile(values);candidate.tessellation();alignment=std::move(candidate);out=geometry();out["ok"]=true;
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
 PackedFloat64Array pvi_stations,pvi_heights,pvi_lengths;for(const auto &v:alignment.profile){pvi_stations.push_back(v.station);pvi_heights.push_back(v.elevation);pvi_lengths.push_back(v.length);}
 out["pvi_stations"]=pvi_stations;out["pvi_heights"]=pvi_heights;out["pvi_lengths"]=pvi_lengths;
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

Dictionary KRoadAlignment::ribbon_crossfall(double width,double offset,double base,double center_x,double center_y,double left,double right) const {
 Dictionary out;
 if(!std::isfinite(width)||width<=0||!std::isfinite(left)||!std::isfinite(right)||std::abs(left)>12||std::abs(right)>12)return out;
 PackedVector3Array vertices;PackedInt32Array indices;auto stations=alignment.tessellation();
 if(stations.size()<2)return out;
 for(size_t i=0;i<stations.size();i++){
  auto q=alignment.sample(stations[i]);double nx=-std::sin(q.pose.heading),ny=std::cos(q.pose.heading);
  for(int side:{-1,0,1}){
   double d=side*width/2;
   double drop=crossfall_drop(std::abs(d),d,width,left,right);
   vertices.push_back(Vector3(q.pose.x+nx*d-center_x,q.elevation+offset-drop+.5-base,q.pose.y+ny*d-center_y));
  }
  if(i>0){int a=int(i-1)*3;for(int side:{0,1})for(int k:{a+side,a+side+1,a+side+3,a+side+1,a+side+4,a+side+3})indices.push_back(k);}
 }
 out["vertices"]=vertices;out["indices"]=indices;return out;
}

PackedFloat64Array KRoadAlignment::sampling_stations() const {
 PackedFloat64Array result;for(double s:alignment.tessellation())result.push_back(s);return result;
}
