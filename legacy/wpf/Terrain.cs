using System;
using System.Collections.Generic;
using System.Linq;
namespace KRoadPrototype;
public record RoutePoint(double X,double Y,double Z);
public class Terrain {
 public int Nx{get;set;} public int Ny{get;set;} public double Dx{get;set;} public double Dy{get;set;} public double OriginX{get;set;} public double OriginY{get;set;} public string Name{get;set;}=""; public double?[] Heights{get;set;}=[];
 public double Width=>(Nx-1)*Dx; public double Height=>(Ny-1)*Dy;
 public double Min=>Heights.Where(v=>v.HasValue).Min()??0; public double Max=>Heights.Where(v=>v.HasValue).Max()??1;
 public double At(double x,double y){if(x<0||y<0||x>Width||y>Height)return double.NaN;double gx=x/Dx,gy=y/Dy;int i=Math.Min(Nx-2,(int)gx),j=Math.Min(Ny-2,(int)gy);var a=Heights[j*Nx+i];var b=Heights[j*Nx+i+1];var c=Heights[(j+1)*Nx+i];var d=Heights[(j+1)*Nx+i+1];if(a is null||b is null||c is null||d is null)return double.NaN;double u=gx-i,v=gy-j;return (1-u)*(1-v)*a.Value+u*(1-v)*b.Value+(1-u)*v*c.Value+u*v*d.Value;}
 public static Terrain Demo(){var t=new Terrain{Nx=81,Ny=81,Dx=30,Dy=30,Name="합성 데모 지형 · 실측 아님",Heights=new double?[81*81]};for(int j=0;j<81;j++)for(int i=0;i<81;i++)t.Heights[j*81+i]=170+75*Math.Sin(i*.07)*Math.Cos(j*.055)+.6*j;return t;}
}
public class Project {public Terrain Terrain{get;set;}=Terrain.Demo();public List<RoutePoint> Route{get;set;}=[];public double RoadWidth{get;set;}=20;public double Offset{get;set;}public double Slope{get;set;}=1.5;}
public static class Corridor {
 public static double Dist(RoutePoint a,RoutePoint b)=>Math.Sqrt(Math.Pow(a.X-b.X,2)+Math.Pow(a.Y-b.Y,2));
 public static double Length(List<RoutePoint> r)=>Enumerable.Range(1,Math.Max(0,r.Count-1)).Sum(i=>Dist(r[i-1],r[i]));
 public static (double x,double y,double z,double nx,double ny) Sample(List<RoutePoint> r,double s){for(int i=1;i<r.Count;i++){var a=r[i-1];var b=r[i];double dx=b.X-a.X,dy=b.Y-a.Y,l=Dist(a,b);if(l<1e-8)continue;if(s<=l||i==r.Count-1){double f=Math.Clamp(s/l,0,1);return(a.X+dx*f,a.Y+dy*f,a.Z+(b.Z-a.Z)*f,-dy/l,dx/l);}s-=l;}return(0,0,0,0,1);}
 public static double Design(Project p,double x,double y){double g=p.Terrain.At(x,y),best=double.PositiveInfinity,z=g;for(int i=1;i<p.Route.Count;i++){var a=p.Route[i-1];var b=p.Route[i];double dx=b.X-a.X,dy=b.Y-a.Y,ll=dx*dx+dy*dy;if(ll<1e-8)continue;double f=((x-a.X)*dx+(y-a.Y)*dy)/ll;if(f<0||f>1)continue;double d=Math.Sqrt(Math.Pow(x-a.X-f*dx,2)+Math.Pow(y-a.Y-f*dy,2));if(d>=best)continue;best=d;double road=a.Z+(b.Z-a.Z)*f+p.Offset,edge=Math.Max(0,d-p.RoadWidth/2)/p.Slope;z=g<road?Math.Max(g,road-edge):Math.Min(g,road+edge);}return z;}
}
