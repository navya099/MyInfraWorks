#pragma once
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <unordered_map>
#include <vector>
class CorridorIndex {
 struct Segment {double x,y,z,dx,dy,dz,ll;};
 std::vector<Segment> segments;
 std::unordered_map<uint64_t,std::vector<int>> buckets;
 double cell=250,width=20,offset=0,slope=1.5,radius=0,padding=0;
 static uint64_t key(int x,int y){return (uint64_t(uint32_t(x))<<32)|uint32_t(y);}
 const std::vector<int> *candidates(double x,double y) const {
  auto found=buckets.find(key(int(std::floor(x/cell)),int(std::floor(y/cell))));return found==buckets.end()?nullptr:&found->second;
 }
public:
 bool ready=false;
 void prepare(const godot::PackedVector3Array &route,double w,double o,double sl,double low,double high,double pad){
  segments.clear();buckets.clear();ready=true;width=w;offset=o;slope=sl;padding=pad;
  double zlow=low,zhigh=high;
  if(!route.is_empty()){zlow=route[0].y+offset;zhigh=zlow;for(int i=0;i<route.size();i++){zlow=std::min(zlow,double(route[i].y)+offset);zhigh=std::max(zhigh,double(route[i].y)+offset);}}
  radius=width/2+std::max(std::abs(zlow-high),std::abs(zhigh-low))*slope;
  cell=std::max(100.0,radius+padding);
  for(int i=1;i<route.size();i++){
   auto a=route[i-1],b=route[i];Segment s{a.x,a.z,a.y,b.x-a.x,b.z-a.z,b.y-a.y,0};s.ll=s.dx*s.dx+s.dy*s.dy;if(s.ll<1e-12)continue;
   int index=int(segments.size());segments.push_back(s);
   int x0=int(std::floor((std::min(double(a.x),double(b.x))-radius-padding)/cell)),x1=int(std::floor((std::max(double(a.x),double(b.x))+radius+padding)/cell));
   int y0=int(std::floor((std::min(double(a.z),double(b.z))-radius-padding)/cell)),y1=int(std::floor((std::max(double(a.z),double(b.z))+radius+padding)/cell));
   for(int y=y0;y<=y1;y++)for(int x=x0;x<=x1;x++)buckets[key(x,y)].push_back(index);
  }
 }
 struct Projection {bool found=false;double elevation=0,distance=0;};
 Projection project(double x,double y) const {
  Projection result;auto list=candidates(x,y);if(!list)return result;
  double best=std::numeric_limits<double>::infinity();
  for(int index:*list){const auto &s=segments[index];double f=std::clamp(((x-s.x)*s.dx+(y-s.y)*s.dy)/s.ll,0.0,1.0);
   double dx=x-s.x-s.dx*f,dy=y-s.y-s.dy*f,d2=dx*dx+dy*dy;if(d2>=best)continue;best=d2;
   result={true,s.z+s.dz*f+offset,std::sqrt(d2)};
  }return result;
 }
 double evaluate(double ground,double x,double y) const {
  if(!std::isfinite(ground))return ground;
  auto list=candidates(x,y);if(!list)return ground;
  double best=std::numeric_limits<double>::infinity(),height=ground;
  for(int index:*list){const auto &s=segments[index];double f=std::clamp(((x-s.x)*s.dx+(y-s.y)*s.dy)/s.ll,0.0,1.0);
   double dx=x-s.x-s.dx*f,dy=y-s.y-s.dy*f,d2=dx*dx+dy*dy;if(d2>=best)continue;best=d2;
   double road=s.z+s.dz*f+offset,edge=std::max(0.0,std::sqrt(d2)-width/2)/slope;
   height=ground<road?std::max(ground,road-edge):std::min(ground,road+edge);
  }return height;
 }
 bool near(double x,double y,double extra) const {
  auto list=candidates(x,y);if(!list)return false;
  double threshold=(radius+extra)*(radius+extra);
  for(int index:*list){const auto &s=segments[index];double f=std::clamp(((x-s.x)*s.dx+(y-s.y)*s.dy)/s.ll,0.0,1.0);double dx=x-s.x-f*s.dx,dy=y-s.y-f*s.dy;if(dx*dx+dy*dy<=threshold)return true;}return false;
 }
};
