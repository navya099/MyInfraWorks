#pragma once
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <string>
#include <vector>

namespace kroad {
constexpr double PI=3.14159265358979323846;
struct Point { double x=0,y=0,z=0; }; // x/y: horizontal east/south; z: elevation
struct Pose { double x=0,y=0,heading=0; };
struct Element {
 Pose start;
 double s=0,length=0,k0=0,k1=0;
 std::string type;
 int pi=-1;
};
inline Pose advance(Pose p,double length,double k0,double k1) {
 if(length<=1e-12)return p;
 if(std::abs(k1-k0)<1e-14) {
  if(std::abs(k0)<1e-14){p.x+=length*std::cos(p.heading);p.y+=length*std::sin(p.heading);}
  else {p.x+=(std::sin(p.heading+k0*length)-std::sin(p.heading))/k0;p.y+=(-std::cos(p.heading+k0*length)+std::cos(p.heading))/k0;}
  p.heading+=k0*length;return p;
 }
 // Composite 8-point Gauss-Legendre integration of the clothoid heading law.
 static constexpr double nodes[]={.1834346424956498,.5255324099163290,.7966664774136267,.9602898564975363};
 static constexpr double weights[]={.3626837833783620,.3137066458778873,.2223810344533745,.1012285362903763};
 double rate=(k1-k0)/length,dx=0,dy=0;
 int parts=std::max(1,int(std::ceil(length*std::max(std::abs(k0),std::abs(k1))/.15)));
 for(int part=0;part<parts;part++) {
  double mid=length*(part+.5)/parts,half=length/(2*parts);
  for(int j=0;j<4;j++)for(int sign:{-1,1}){
   double t=mid+sign*half*nodes[j],h=p.heading+k0*t+.5*rate*t*t;
   dx+=half*weights[j]*std::cos(h);dy+=half*weights[j]*std::sin(h);
  }
 }
 p.x+=dx;p.y+=dy;p.heading+=(k0+k1)*length/2;return p;
}
inline Pose at(const Element &e,double ds) {
 ds=std::clamp(ds,0.0,e.length);
 double k=e.k0+(e.k1-e.k0)*ds/e.length;
 return advance(e.start,ds,e.k0,k);
}
struct Sample { Pose pose;double elevation=0,grade=0,curvature=0,s=0;int element=0; };
struct Pvi {double station=0,elevation=0,length=0;};
class Alignment {
 std::vector<Point> pi_;
 std::vector<double> vertical_;
 void add(Pose p,double length,double k0,double k1,const std::string &type,int pi) {
  if(length<1e-8)return;
  elements.push_back({p,total,length,k0,k1,type,pi});total+=length;
 }
public:
 std::vector<Pvi> profile;
 std::vector<Element> elements;
 std::vector<double> stations;
 double total=0;
 void build(const std::vector<Point> &points,const std::vector<double> &radii,const std::vector<double> &spirals,const std::vector<double> &vertical) {
  Alignment next;next.pi_=points;next.vertical_=vertical;size_t n=points.size();
  if(radii.size()!=n||spirals.size()!=n||vertical.size()!=n)throw std::runtime_error("Parameter array size mismatch");
  next.stations.resize(n);
  for(size_t i=0;i<n;i++) {
   const auto &p=points[i];if(!std::isfinite(p.x)||!std::isfinite(p.y)||!std::isfinite(p.z)||!std::isfinite(radii[i])||!std::isfinite(spirals[i])||!std::isfinite(vertical[i])||radii[i]<0||spirals[i]<0||vertical[i]<0)throw std::runtime_error("Non-finite or negative alignment parameter");
   if(std::abs(p.x)>1e9||std::abs(p.y)>1e9||std::abs(p.z)>1e6||radii[i]>1e8||spirals[i]>1e8||vertical[i]>1e8)throw std::runtime_error("Alignment parameter exceeds supported numeric range");
   if((radii[i]>0&&radii[i]<.01)||(spirals[i]>0&&spirals[i]<.01)||(vertical[i]>0&&vertical[i]<.01))throw std::runtime_error("Positive radius and curve lengths must be at least 0.01 m");
   if((i==0||i==n-1)&&(radii[i]>0||spirals[i]>0||vertical[i]>0))throw std::runtime_error("Endpoints cannot have horizontal/vertical curves");
   if(radii[i]==0&&spirals[i]>0)throw std::runtime_error("Spiral length requires a positive radius");
  }
  if(n<2){*this=std::move(next);return;}
  std::vector<double> trim(n,0),turn(n,0),heading(n-1),legs(n-1);
  for(size_t i=0;i<n-1;i++) {
   double dx=points[i+1].x-points[i].x,dy=points[i+1].y-points[i].y;
   legs[i]=std::hypot(dx,dy);heading[i]=std::atan2(dy,dx);
   if(legs[i]<1)throw std::runtime_error("Adjacent PI points must be at least 1 m apart");
  }
  for(size_t i=1;i<n-1;i++) {
   if(radii[i]<=0)continue;
   double delta=std::remainder(heading[i]-heading[i-1],2*PI),angle=std::abs(delta);
   if(angle<1e-7||angle>=170*PI/180)throw std::runtime_error("Curve PI deflection must be between 0 and 170 degrees: PI "+std::to_string(i+1));
   if(spirals[i]>radii[i]*angle+1e-8)throw std::runtime_error("Spiral too long for radius/deflection: PI "+std::to_string(i+1));
   double k=std::copysign(1/radii[i],delta),ls=spirals[i],lc=std::max(0.0,radii[i]*angle-ls);
   Pose local;local=advance(local,ls,0,k);local=advance(local,lc,k,k);local=advance(local,ls,k,0);
   double ux=1+std::cos(delta),uy=std::sin(delta);
   trim[i]=(local.x*ux+local.y*uy)/(ux*ux+uy*uy);turn[i]=delta;
   if(trim[i]<=0||std::hypot(local.x-trim[i]*ux,local.y-trim[i]*uy)>1e-5)throw std::runtime_error("Curve construction residual exceeds tolerance");
  }
  for(size_t i=0;i<n-1;i++)if(trim[i]+trim[i+1]>=legs[i]-1e-5)throw std::runtime_error("Horizontal curves overlap or exceed tangent length: segment "+std::to_string(i+1));
  next.stations[0]=0;
  for(size_t i=0;i<n-1;i++) {
   Pose p{points[i].x+trim[i]*std::cos(heading[i]),points[i].y+trim[i]*std::sin(heading[i]),heading[i]};
   next.add(p,legs[i]-trim[i]-trim[i+1],0,0,"line",int(i));
   size_t j=i+1;
   if(j==n-1){next.stations[j]=next.total;break;}
   if(trim[j]<=0){next.stations[j]=next.total;continue;}
   p={points[j].x-trim[j]*std::cos(heading[i]),points[j].y-trim[j]*std::sin(heading[i]),heading[i]};
   double k=std::copysign(1/radii[j],turn[j]),ls=spirals[j],lc=std::max(0.0,radii[j]*std::abs(turn[j])-ls);
   next.stations[j]=next.total+(2*ls+lc)/2; // linked PVI station at curve midpoint
   next.add(p,ls,0,k,"spiral_in",int(j));p=advance(p,ls,0,k);
   next.add(p,lc,k,k,"arc",int(j));p=advance(p,lc,k,k);
   next.add(p,ls,k,0,"spiral_out",int(j));p=advance(p,ls,k,0);
   double ex=points[j].x+trim[j]*std::cos(heading[j]),ey=points[j].y+trim[j]*std::sin(heading[j]);
   if(std::hypot(p.x-ex,p.y-ey)>1e-5)throw std::runtime_error("Curve end does not match outgoing tangent");
  }
  for(size_t i=1;i<n-1;i++) {
   double half=vertical[i]/2;
   if(next.stations[i]-half<0||next.stations[i]+half>next.total)throw std::runtime_error("Vertical curve exceeds alignment endpoints");
   if(i>1&&next.stations[i-1]+vertical[i-1]/2>next.stations[i]-half+1e-8)throw std::runtime_error("Vertical curves overlap");
  }
  for(size_t i=0;i<n;i++)next.profile.push_back({next.stations[i],points[i].z,vertical[i]});
  *this=std::move(next);
 }
 void set_profile(std::vector<Pvi> values) {
  if(total<=0){if(!values.empty())throw std::runtime_error("Profile requires a nonzero horizontal alignment");profile.clear();return;}
  if(values.size()<2)throw std::runtime_error("Profile requires two endpoints");
  for(size_t i=0;i<values.size();i++){
   auto &v=values[i];
   if(!std::isfinite(v.station)||!std::isfinite(v.elevation)||!std::isfinite(v.length)||std::abs(v.elevation)>1e6||v.length<0||v.length>1e8||(v.length>0&&v.length<.01))throw std::runtime_error("Invalid PVI station, elevation or length");
   if(i&&v.station-values[i-1].station<1)throw std::runtime_error("PVI stations must increase with at least 1 m spacing");
   if(v.station<0||v.station>total||v.station-v.length/2<0||v.station+v.length/2>total)throw std::runtime_error("PVI or vertical curve is outside alignment; move/delete the PVI before shortening the route");
   if(i&&values[i-1].station+values[i-1].length/2>v.station-v.length/2+1e-8)throw std::runtime_error("Vertical curves overlap");
  }
  if(std::abs(values.front().station)>1e-6||std::abs(values.back().station-total)>1e-6||values.front().length!=0||values.back().length!=0)throw std::runtime_error("Profile endpoints must be 0 / route length and have Lv=0");
  values.front().station=0;values.back().station=total;profile=std::move(values);
 }
 Sample sample(double s) const {
  Sample out;if(pi_.empty())return out;
  if(elements.empty()){out.pose={pi_[0].x,pi_[0].y,0};out.elevation=pi_[0].z;return out;}
  s=std::clamp(s,0.0,total);out.s=s;
  auto found=std::upper_bound(elements.begin(),elements.end(),s,[](double value,const Element &e){return value<e.s;});
  size_t index=found==elements.begin()?0:size_t(found-elements.begin()-1);const auto &e=elements[index];double ds=std::clamp(s-e.s,0.0,e.length);
  out.pose=at(e,ds);out.curvature=e.k0+(e.k1-e.k0)*ds/e.length;out.element=int(index);
  for(size_t i=1;i+1<profile.size();i++) {
   const auto &v=profile[i];double l=v.length;if(l<=0||s<v.station-l/2||s>v.station+l/2)continue;
   double g1=(v.elevation-profile[i-1].elevation)/(v.station-profile[i-1].station),g2=(profile[i+1].elevation-v.elevation)/(profile[i+1].station-v.station);
   double x=s-v.station+l/2;
   out.elevation=v.elevation-g1*l/2+g1*x+(g2-g1)*x*x/(2*l);out.grade=g1+(g2-g1)*x/l;return out;
  }
  if(profile.size()<2)return out;
  auto pos=std::upper_bound(profile.begin(),profile.end(),s,[](double s,const Pvi &p){return s<p.station;});size_t j=pos==profile.begin()?0:std::min(profile.size()-2,size_t(pos-profile.begin()-1));
  out.grade=(profile[j+1].elevation-profile[j].elevation)/(profile[j+1].station-profile[j].station);out.elevation=profile[j].elevation+out.grade*(s-profile[j].station);return out;
 }
 std::vector<double> tessellation(double max_step=25,double horizontal_error=.05,double vertical_error=.01) const {
  std::vector<double> out;if(elements.empty()){if(!pi_.empty())out.push_back(0);return out;}
  std::vector<double> breaks{0,total};
  for(const auto &e:elements){breaks.push_back(e.s);breaks.push_back(e.s+e.length);}
  for(const auto &v:profile){breaks.push_back(v.station);if(v.length>0){breaks.push_back(v.station-v.length/2);breaks.push_back(v.station+v.length/2);}}
  std::sort(breaks.begin(),breaks.end());breaks.erase(std::unique(breaks.begin(),breaks.end(),[](double a,double b){return std::abs(a-b)<1e-8;}),breaks.end());
  out.push_back(0);
  for(size_t i=1;i<breaks.size();i++) {
   double a=breaks[i-1],b=breaks[i],km=0,acc=0;
   for(double fraction:{0.0,.25,.5,.75,1.0}){auto q=sample(a+(b-a)*fraction);km=std::max(km,std::abs(q.curvature));}
   auto qa=sample(a+1e-7),qb=sample(b-1e-7);acc=std::abs(qb.grade-qa.grade)/std::max(1e-8,b-a);
   double step=max_step;if(km>1e-12)step=std::min(step,std::sqrt(8*horizontal_error/km));if(acc>1e-12)step=std::min(step,std::sqrt(8*vertical_error/acc));
   double requested=std::ceil((b-a)/step);
   if(!std::isfinite(requested)||requested>500000-out.size())throw std::runtime_error("Alignment tessellation exceeds 500000 points");
   int count=std::max(1,int(requested));
   for(int j=1;j<=count;j++)out.push_back(a+(b-a)*j/count);
  }
  return out;
 }
};
} // namespace kroad
