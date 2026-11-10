#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_map>
#include <vector>
#include <godot_cpp/variant/packed_float32_array.hpp>
using namespace godot;
class KRoadCore : public RefCounted {
 GDCLASS(KRoadCore, RefCounted)
 static double missing() { return std::numeric_limits<double>::quiet_NaN(); }
 struct Grid {
  int nx=0,ny=0;
  double dx=0,dy=0;
  PackedFloat64Array h64;
  PackedFloat32Array h32;
  explicit Grid(const Dictionary &t) {
   nx=t.get("Nx",0);ny=t.get("Ny",0);dx=t.get("Dx",0.0);dy=t.get("Dy",0.0);
   Variant h=t.get("Heights",Variant());
   if(h.get_type()==Variant::PACKED_FLOAT64_ARRAY)h64=h;
   else if(h.get_type()==Variant::PACKED_FLOAT32_ARRAY)h32=h;
  }
  bool valid() const {return nx>=2 && ny>=2 && int64_t(nx)*ny<=64000000 && int64_t(nx)*ny==h64.size()+h32.size() && std::isfinite(dx) && std::isfinite(dy) && dx>0 && dy>0;}
  double at(int64_t index) const {return h64.is_empty()?double(h32[index]):h64[index];}
  double sample(double x,double y) const {
   double ex=(nx-1)*dx,ey=(ny-1)*dy,tolerance=1e-9*std::max(ex,ey);
   if(!valid()||!std::isfinite(x)||!std::isfinite(y)||x< -tolerance||y< -tolerance||x>ex+tolerance||y>ey+tolerance)return missing();
   x=std::clamp(x,0.0,ex);y=std::clamp(y,0.0,ey);
   double gx=x/dx,gy=y/dy;int i=std::min(nx-2,int(gx)),j=std::min(ny-2,int(gy));
   double a=at(j*nx+i),b=at(j*nx+i+1),c=at((j+1)*nx+i),d=at((j+1)*nx+i+1);
   if(!std::isfinite(a)||!std::isfinite(b)||!std::isfinite(c)||!std::isfinite(d))return missing();
   double u=gx-i,v=gy-j;return (1-u)*(1-v)*a+u*(1-v)*b+(1-u)*v*c+u*v*d;
  }
 };
 static bool valid(const Dictionary &t) {return Grid(t).valid();}
 static double design(double g,const PackedVector3Array &r,double x,double y,double width,double offset,double slope) {
  if(!std::isfinite(g)||width<=0||slope<=0)return g;
  double best=std::numeric_limits<double>::infinity(),z=g;
  for(int i=1;i<r.size();++i){Vector3 a=r[i-1],b=r[i];double vx=b.x-a.x,vy=b.z-a.z,ll=vx*vx+vy*vy;if(ll<1e-12)continue;
   double f=((x-a.x)*vx+(y-a.z)*vy)/ll;if(f<0||f>1)continue;
   double ex=x-a.x-f*vx,ey=y-a.z-f*vy,dist2=ex*ex+ey*ey;if(dist2>=best)continue;best=dist2;
   double road=a.y+(b.y-a.y)*f+offset,edge=std::max(0.0,std::sqrt(dist2)-width/2)/slope;
   z=g<road?std::max(g,road-edge):std::min(g,road+edge);
  }return z;
 }
protected:
 static void _bind_methods() {
  ClassDB::bind_method(D_METHOD("interpolate_elevation","a","b","fraction"),&KRoadCore::interpolate_elevation);
  ClassDB::bind_method(D_METHOD("get_build_info"),&KRoadCore::get_build_info);
  ClassDB::bind_method(D_METHOD("sample_height","terrain","x","y"),&KRoadCore::sample_height);
  ClassDB::bind_method(D_METHOD("design_height","terrain","route","x","y","width","offset","slope"),&KRoadCore::design_height);
  ClassDB::bind_method(D_METHOD("grid_stats","terrain"),&KRoadCore::grid_stats);
  ClassDB::bind_method(D_METHOD("build_render_tile","terrain","source","route","x0","y0","cells","width","offset","slope","refinement"),&KRoadCore::build_render_tile);
  ClassDB::bind_method(D_METHOD("build_tile","terrain","route","x0","y0","cells","width","offset","slope"),&KRoadCore::build_tile);
 }
public:
 double interpolate_elevation(double a,double b,double f) const{return a+(b-a)*std::clamp(f,0.0,1.0);}
 String get_build_info() const{return "K-ROAD C++ / MSVC x64 / GDExtension";}
 double sample_height(const Dictionary &t,double x,double y) const {
  return Grid(t).sample(x,y);
 }
 double design_height(const Dictionary &t,const PackedVector3Array &r,double x,double y,double width,double offset,double slope) const {
  return design(sample_height(t,x,y),r,x,y,width,offset,slope);
 }
 Dictionary build_tile(const Dictionary &t,const PackedVector3Array &r,int x0,int y0,int cells,double width,double offset,double slope) const {
  Dictionary out;if(!valid(t)||cells<1||cells>256||x0<0||y0<0)return out;
  int nx=t["Nx"],ny=t["Ny"];if(x0>=nx-1||y0>=ny-1)return out;
  double dx=t["Dx"],dy=t["Dy"],base=t.get("Min",0.0),range=std::max(1.0,double(t.get("Max",1.0))-base);
  Grid grid(t);int x1=std::min(nx-1,x0+cells),y1=std::min(ny-1,y0+cells),cols=x1-x0+1;
  PackedVector3Array vertices,normals;PackedColorArray colors;PackedInt32Array indices;
  auto height=[&](int x,int y){return design(grid.at(y*nx+x),r,x*dx,y*dy,width,offset,slope);};
  for(int y=y0;y<=y1;y++)for(int x=x0;x<=x1;x++){
   double z=height(x,y),g=grid.at(y*nx+x);bool ok=std::isfinite(z);
   vertices.push_back(Vector3(x*dx-(nx-1)*dx/2,ok?z-base:0,y*dy-(ny-1)*dy/2));
   int l=std::max(0,x-1),rr=std::min(nx-1,x+1),u=std::max(0,y-1),d=std::min(ny-1,y+1);
   double hl=height(l,y),hr=height(rr,y),hu=height(x,u),hd=height(x,d);
   double sx=std::isfinite(hl)&&std::isfinite(hr)?(hr-hl)/((rr-l)*dx):0;
   double sy=std::isfinite(hu)&&std::isfinite(hd)?(hd-hu)/((d-u)*dy):0;
   normals.push_back(Vector3(-sx,1,-sy).normalized());
   double f=std::isfinite(g)?std::clamp((g-base)/range,0.0,1.0):0.0;Color color(0.18+f*.23,0.34+f*.25,0.27+f*.15);
   if(ok&&z-g>0.05)color=Color(.60,.43,.24);else if(ok&&z-g<-.05)color=Color(.42,.56,.68);
   colors.push_back(color);
  }
  for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){
   if(!std::isfinite(grid.at(y*nx+x))||!std::isfinite(grid.at(y*nx+x+1))||!std::isfinite(grid.at((y+1)*nx+x))||!std::isfinite(grid.at((y+1)*nx+x+1)))continue;
   int a=(y-y0)*cols+x-x0,b=a+1,c=a+cols,d=c+1;
   // Godot front faces use clockwise winding; normals explicitly point upward.
   for(int k:{a,b,c,b,d,c})indices.push_back(k);
  }
  out["vertices"]=vertices;out["normals"]=normals;out["colors"]=colors;out["indices"]=indices;return out;
 }
 Dictionary grid_stats(const Dictionary &t) const {
  Grid grid(t);Dictionary out;if(!grid.valid())return out;
  double low=std::numeric_limits<double>::infinity(),high=-low;int64_t count=0;
  for(int64_t i=0;i<int64_t(grid.nx)*grid.ny;i++){double h=grid.at(i);if(std::isfinite(h)){low=std::min(low,h);high=std::max(high,h);count++;}}
  if(count){out["Min"]=low;out["Max"]=high;out["ValidCount"]=count;}return out;
 }
 Dictionary build_render_tile(const Dictionary &t,const Dictionary &source,const PackedVector3Array &r,int x0,int y0,int cells,double width,double offset,double slope,int refinement) const {
  Dictionary out;Grid view(t),grid(source);
  if(!view.valid()||!grid.valid()||cells<1||cells>64||x0<0||y0<0||x0>=view.nx-1||y0>=view.ny-1||!std::isfinite(width)||!std::isfinite(offset)||!std::isfinite(slope)||width<=0||slope<=0)return out;
  const int factor=std::clamp(refinement,1,16),denom=factor*2;
  const int x1=std::min(view.nx-1,x0+cells),y1=std::min(view.ny-1,y0+cells);
  const double base=t.get("Min",0.0),range=std::max(1.0,double(t.get("Max",1.0))-base);
  const double extent_x=(view.nx-1)*view.dx,extent_y=(view.ny-1)*view.dy;
  const double epsilon=std::max(0.1,std::min(grid.dx,grid.dy)/2);
  auto planned=[&](double x,double y){return design(grid.sample(x,y),r,x,y,width,offset,slope);};
  auto refine=[&](int cx,int cy){
   if(factor==1||cx<0||cy<0||cx>=view.nx-1||cy>=view.ny-1)return false;
   double px=(cx+0.5)*view.dx,py=(cy+0.5)*view.dy;
   for(int i=1;i<r.size();i++){
    Vector3 a=r[i-1],b=r[i];double vx=b.x-a.x,vy=b.z-a.z,ll=vx*vx+vy*vy;if(ll<1e-12)continue;
    double u=std::clamp(((px-a.x)*vx+(py-a.z)*vy)/ll,0.0,1.0);
    double ex=px-a.x-u*vx,ey=py-a.z-u*vy;
    double low=std::min(a.y,b.y)+offset,high=std::max(a.y,b.y)+offset;
    double margin=width/2+std::max(std::abs(low-double(t.get("Max",1))),std::abs(high-base))*slope+std::hypot(view.dx,view.dy);
    if(ex*ex+ey*ey<=margin*margin)return true;
   }return false;
  };
  PackedVector3Array vertices,normals;PackedColorArray colors;PackedInt32Array indices;
  std::unordered_map<uint64_t,int> cache;
  std::vector<bool> finite;
  auto vertex=[&](int kx,int ky){
   uint64_t key=(uint64_t(uint32_t(kx))<<32)|uint32_t(ky);
   auto found=cache.find(key);if(found!=cache.end())return found->second;
   double x=double(kx)/denom*view.dx,y=double(ky)/denom*view.dy;
   double g=grid.sample(x,y),z=design(g,r,x,y,width,offset,slope);bool ok=std::isfinite(z);
   int index=vertices.size();cache[key]=index;finite.push_back(ok);
   vertices.push_back(Vector3(x-extent_x/2,ok?z-base:0,y-extent_y/2));
   double xl=std::max(0.0,x-epsilon),xr=std::min(extent_x,x+epsilon),yu=std::max(0.0,y-epsilon),yd=std::min(extent_y,y+epsilon);
   double hl=planned(xl,y),hr=planned(xr,y),hu=planned(x,yu),hd=planned(x,yd);
   double sx=std::isfinite(hl)&&std::isfinite(hr)?(hr-hl)/(xr-xl):0,sy=std::isfinite(hu)&&std::isfinite(hd)?(hd-hu)/(yd-yu):0;
   normals.push_back(Vector3(-sx,1,-sy).normalized());
   double f=std::isfinite(g)?std::clamp((g-base)/range,0.0,1.0):0;Color color(.18+f*.23,.34+f*.25,.27+f*.15);
   if(ok&&z-g>.05)color=Color(.60,.43,.24);else if(ok&&z-g<-.05)color=Color(.42,.56,.68);
   colors.push_back(color);return index;
  };
  auto triangle=[&](int a,int b,int c){if(finite[a]&&finite[b]&&finite[c]){indices.push_back(a);indices.push_back(b);indices.push_back(c);}};
  int refined_count=0;
  for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){
   int gx=x*denom,gy=y*denom;
   if(refine(x,y)){
    refined_count++;
    for(int j=0;j<factor;j++)for(int i=0;i<factor;i++){
     int a=vertex(gx+i*2,gy+j*2),b=vertex(gx+(i+1)*2,gy+j*2),c=vertex(gx+i*2,gy+(j+1)*2),d=vertex(gx+(i+1)*2,gy+(j+1)*2);
     triangle(a,b,c);triangle(b,d,c);
    }
   }else{
    int top=refine(x,y-1)?factor:1,right=refine(x+1,y)?factor:1,bottom=refine(x,y+1)?factor:1,left=refine(x-1,y)?factor:1;
    if(top+right+bottom+left==4){
     int a=vertex(gx,gy),b=vertex(gx+denom,gy),c=vertex(gx,gy+denom),d=vertex(gx+denom,gy+denom);triangle(a,b,c);triangle(b,d,c);
    }else{
     // Stitch low-resolution cells to refined neighbors with a boundary fan.
     // Global lattice keys make positions and normals identical across tiles.
     int center=vertex(gx+factor,gy+factor);std::vector<int> boundary;
     for(int i=0;i<top;i++)boundary.push_back(vertex(gx+i*denom/top,gy));
     for(int i=0;i<right;i++)boundary.push_back(vertex(gx+denom,gy+i*denom/right));
     for(int i=0;i<bottom;i++)boundary.push_back(vertex(gx+denom-i*denom/bottom,gy+denom));
     for(int i=0;i<left;i++)boundary.push_back(vertex(gx,gy+denom-i*denom/left));
     for(size_t i=0;i<boundary.size();i++)triangle(center,boundary[i],boundary[(i+1)%boundary.size()]);
    }
   }
  }
  out["vertices"]=vertices;out["normals"]=normals;out["colors"]=colors;out["indices"]=indices;out["refined_cells"]=refined_count;return out;
 }

};
void initialize_kroad(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)ClassDB::register_class<KRoadCore>();}
void uninitialize_kroad(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT kroad_library_init(GDExtensionInterfaceGetProcAddress proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *init){
 GDExtensionBinding::InitObject obj(proc,library,init);obj.register_initializer(initialize_kroad);obj.register_terminator(uninitialize_kroad);obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return obj.init();
}
