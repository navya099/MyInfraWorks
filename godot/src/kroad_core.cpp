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
using namespace godot;
class KRoadCore : public RefCounted {
 GDCLASS(KRoadCore, RefCounted)
 static double missing() { return std::numeric_limits<double>::quiet_NaN(); }
 static bool valid(const Dictionary &t) {
  int nx=t.get("Nx",0),ny=t.get("Ny",0); PackedFloat64Array h=t.get("Heights",PackedFloat64Array());
  return nx>=2 && ny>=2 && int64_t(nx)*ny==h.size() && double(t.get("Dx",0))>0 && double(t.get("Dy",0))>0;
 }
 static double sample(const PackedFloat64Array &h,int nx,int ny,double dx,double dy,double x,double y) {
  if(!std::isfinite(x)||!std::isfinite(y)||x<0||y<0||x>(nx-1)*dx||y>(ny-1)*dy)return missing();
  double gx=x/dx,gy=y/dy;int i=std::min(nx-2,int(gx)),j=std::min(ny-2,int(gy));
  double a=h[j*nx+i],b=h[j*nx+i+1],c=h[(j+1)*nx+i],d=h[(j+1)*nx+i+1];
  if(!std::isfinite(a)||!std::isfinite(b)||!std::isfinite(c)||!std::isfinite(d))return missing();
  double u=gx-i,v=gy-j;return (1-u)*(1-v)*a+u*(1-v)*b+(1-u)*v*c+u*v*d;
 }
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
  ClassDB::bind_method(D_METHOD("build_tile","terrain","route","x0","y0","cells","width","offset","slope"),&KRoadCore::build_tile);
 }
public:
 double interpolate_elevation(double a,double b,double f) const{return a+(b-a)*std::clamp(f,0.0,1.0);}
 String get_build_info() const{return "K-ROAD C++ / MSVC x64 / GDExtension";}
 double sample_height(const Dictionary &t,double x,double y) const {
  if(!valid(t))return missing();PackedFloat64Array h=t["Heights"];return sample(h,t["Nx"],t["Ny"],t["Dx"],t["Dy"],x,y);
 }
 double design_height(const Dictionary &t,const PackedVector3Array &r,double x,double y,double width,double offset,double slope) const {
  return design(sample_height(t,x,y),r,x,y,width,offset,slope);
 }
 Dictionary build_tile(const Dictionary &t,const PackedVector3Array &r,int x0,int y0,int cells,double width,double offset,double slope) const {
  Dictionary out;if(!valid(t)||cells<1||cells>256||x0<0||y0<0)return out;
  int nx=t["Nx"],ny=t["Ny"];if(x0>=nx-1||y0>=ny-1)return out;
  double dx=t["Dx"],dy=t["Dy"],base=t.get("Min",0.0),range=std::max(1.0,double(t.get("Max",1.0))-base);
  PackedFloat64Array h=t["Heights"];int x1=std::min(nx-1,x0+cells),y1=std::min(ny-1,y0+cells),cols=x1-x0+1;
  PackedVector3Array vertices,normals;PackedColorArray colors;PackedInt32Array indices;
  auto height=[&](int x,int y){return design(h[y*nx+x],r,x*dx,y*dy,width,offset,slope);};
  for(int y=y0;y<=y1;y++)for(int x=x0;x<=x1;x++){
   double z=height(x,y),g=h[y*nx+x];bool ok=std::isfinite(z);
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
   if(!std::isfinite(h[y*nx+x])||!std::isfinite(h[y*nx+x+1])||!std::isfinite(h[(y+1)*nx+x])||!std::isfinite(h[(y+1)*nx+x+1]))continue;
   int a=(y-y0)*cols+x-x0,b=a+1,c=a+cols,d=c+1;
   // Godot front faces use clockwise winding; normals explicitly point upward.
   for(int k:{a,b,c,b,d,c})indices.push_back(k);
  }
  out["vertices"]=vertices;out["normals"]=normals;out["colors"]=colors;out["indices"]=indices;return out;
 }
};
void initialize_kroad(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)ClassDB::register_class<KRoadCore>();}
void uninitialize_kroad(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT kroad_library_init(GDExtensionInterfaceGetProcAddress proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *init){
 GDExtensionBinding::InitObject obj(proc,library,init);obj.register_initializer(initialize_kroad);obj.register_terminator(uninitialize_kroad);obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return obj.init();
}
