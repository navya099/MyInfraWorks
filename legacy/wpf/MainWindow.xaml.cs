using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Media3D;
using System.Windows.Shapes;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
namespace KRoadPrototype;
public partial class MainWindow:Window {
 double terrainMin,terrainMax; Terrain? cachedTerrain; BitmapSource? terrainBitmap;
 Project p=new(); double yaw=-45,zoom=1; Point? drag; double chartMin,chartMax;
 public MainWindow(){InitializeComponent();Loaded+=(_,_)=>{if(Environment.GetCommandLineArgs().Contains("--benchmark"))RunBenchmark();else Render();};}
 double MapScale=>Math.Max(.000001,Math.Min((Plan.ActualWidth-30)/p.Terrain.Width,(Plan.ActualHeight-30)/p.Terrain.Height));
 Point Map(double x,double y)=>new(15+x*MapScale,15+y*MapScale);
 void Line(Canvas c,Point a,Point b,Brush color,double width=1){c.Children.Add(new Line{X1=a.X,Y1=a.Y,X2=b.X,Y2=b.Y,Stroke=color,StrokeThickness=width});}
 void Text(Canvas c,string s,double x,double y){var t=new TextBlock{Text=s,Foreground=Brushes.LightGray,FontSize=11};Canvas.SetLeft(t,x);Canvas.SetTop(t,y);c.Children.Add(t);}
 void Render(){if(!IsLoaded)return;terrainMin=p.Terrain.Min;terrainMax=p.Terrain.Max;DrawPlan();DrawScene();DrawCharts();Status.Text=$"{p.Terrain.Name} | 격자 {p.Terrain.Nx}×{p.Terrain.Ny} · {p.Terrain.Dx:F0}m | 노선 {Corridor.Length(p.Route):N0}m / {p.Route.Count}점 | DEM 축소 미리보기 · 토공량 미산출";}
 void DrawPlan(){
  Plan.Children.Clear();var t=p.Terrain;
  if(!ReferenceEquals(cachedTerrain,t)){
   double range=Math.Max(1,terrainMax-terrainMin);var pixels=new byte[t.Nx*t.Ny*4];
   for(int j=0;j<t.Ny;j++)for(int i=0;i<t.Nx;i++){
    var z=t.Heights[j*t.Nx+i];if(z is null)continue;
    byte v=(byte)Math.Clamp(55+145*(z.Value-terrainMin)/range,0,255);int k=(j*t.Nx+i)*4;
    pixels[k]=(byte)(v*.7);pixels[k+1]=v;pixels[k+2]=(byte)(v*.62);pixels[k+3]=255;
   }
   terrainBitmap=BitmapSource.Create(t.Nx,t.Ny,96,96,PixelFormats.Bgra32,null,pixels,t.Nx*4);terrainBitmap.Freeze();cachedTerrain=t;
  }
  var image=new Image{Source=terrainBitmap,Width=t.Width*MapScale,Height=t.Height*MapScale,Stretch=Stretch.Fill,IsHitTestVisible=false};Canvas.SetLeft(image,15);Canvas.SetTop(image,15);Plan.Children.Add(image);
  for(int i=0;i<p.Route.Count;i++){var a=Map(p.Route[i].X,p.Route[i].Y);if(i>0)Line(Plan,Map(p.Route[i-1].X,p.Route[i-1].Y),a,Brushes.Orange,3);Text(Plan,$"● {i+1}",a.X,a.Y);}
  Text(Plan,$"{t.Width/1000:F1} × {t.Height/1000:F1} km",20,20);
 }
 Point3D Pos(double x,double y,double z)=>new((x-p.Terrain.Width/2)/Math.Max(p.Terrain.Width,p.Terrain.Height), (p.Terrain.Height/2-y)/Math.Max(p.Terrain.Width,p.Terrain.Height),(z-terrainMin)/Math.Max(p.Terrain.Width,p.Terrain.Height));
 void DrawScene(){Scene.Children.Clear();var group=new Model3DGroup();group.Children.Add(new AmbientLight(Color.FromRgb(150,150,150)));group.Children.Add(new DirectionalLight(Colors.White,new Vector3D(-1,1,-2)));var mesh=new MeshGeometry3D();var t=p.Terrain;for(int j=0;j<t.Ny;j++)for(int i=0;i<t.Nx;i++){double z=Corridor.Design(p,i*t.Dx,j*t.Dy);mesh.Positions.Add(Pos(i*t.Dx,j*t.Dy,double.IsFinite(z)?z:terrainMin));}for(int j=0;j<t.Ny-1;j++)for(int i=0;i<t.Nx-1;i++){int a=j*t.Nx+i,b=a+1,c=a+t.Nx,d=c+1;if(t.Heights[a] is null||t.Heights[b] is null||t.Heights[c] is null||t.Heights[d] is null)continue;foreach(int k in new[]{a,c,b,b,c,d})mesh.TriangleIndices.Add(k);}var mat=new DiffuseMaterial(new SolidColorBrush(Color.FromRgb(87,139,107)));group.Children.Add(new GeometryModel3D(mesh,mat){BackMaterial=mat});
 if(p.Route.Count>1){var road=new MeshGeometry3D();double len=Corridor.Length(p.Route);int n=Math.Max(2,(int)(len/Math.Max(5,t.Dx/4)));for(int i=0;i<=n;i++){var a=Corridor.Sample(p.Route,len*i/n);foreach(int side in new[]{-1,1})road.Positions.Add(Pos(a.x+side*a.nx*p.RoadWidth/2,a.y+side*a.ny*p.RoadWidth/2,a.z+p.Offset+1));if(i>0){int q=(i-1)*2;foreach(int k in new[]{q,q+1,q+2,q+1,q+3,q+2})road.TriangleIndices.Add(k);}}var rm=new DiffuseMaterial(Brushes.Orange);group.Children.Add(new GeometryModel3D(road,rm){BackMaterial=rm});}
 group.Freeze();Scene.Children.Add(new ModelVisual3D{Content=group});UpdateCamera();}
 void UpdateCamera(){double a1=yaw*Math.PI/180;var eye=new Point3D(1.25*zoom*Math.Cos(a1),1.25*zoom*Math.Sin(a1),.85*zoom);Scene.Camera=new PerspectiveCamera(eye,new Vector3D(-eye.X,-eye.Y,.05-eye.Z),new Vector3D(0,0,1),48);}
 void DrawCharts(){Profile.Children.Clear();Section.Children.Clear();if(p.Route.Count<2){Text(Profile,"평면에서 두 점 이상 지정하세요.",20,25);return;}double len=Corridor.Length(p.Route);chartMin=Math.Min(terrainMin,p.Route.Min(v=>v.Z)+p.Offset)-20;chartMax=Math.Max(terrainMax,p.Route.Max(v=>v.Z)+p.Offset)+20;Point P(double s,double z)=>new(35+s/len*Math.Max(1,Profile.ActualWidth-55),15+(chartMax-z)/(chartMax-chartMin)*Math.Max(1,Profile.ActualHeight-45));for(int i=1;i<=240;i++){var a=Corridor.Sample(p.Route,len*(i-1)/240);var b=Corridor.Sample(p.Route,len*i/240);double ga=p.Terrain.At(a.x,a.y),gb=p.Terrain.At(b.x,b.y);if(double.IsFinite(ga)&&double.IsFinite(gb))Line(Profile,P(len*(i-1)/240,ga),P(len*i/240,gb),Brushes.MediumSeaGreen,2);Line(Profile,P(len*(i-1)/240,a.z+p.Offset),P(len*i/240,b.z+p.Offset),Brushes.Orange,2);}Text(Profile,$"{chartMax:F0}m",2,2);Text(Profile,$"0 → {len:N0}m · 초록: 원지반 / 주황: 계획",35,Profile.ActualHeight-22);
 var at=Corridor.Sample(p.Route,len*Station.Value);double reach=Math.Max(100,p.RoadWidth*3),low=at.z+p.Offset-60,high=at.z+p.Offset+60;Point C(double d,double z)=>new(20+(d+reach)/(2*reach)*Math.Max(1,Section.ActualWidth-40),15+(high-z)/(high-low)*Math.Max(1,Section.ActualHeight-45));double lastG=double.NaN,lastD=double.NaN;for(int i=0;i<=200;i++){double d=-reach+2*reach*i/200,x=at.x+at.nx*d,y=at.y+at.ny*d,g=p.Terrain.At(x,y),z=Corridor.Design(p,x,y);if(i>0&&double.IsFinite(g)&&double.IsFinite(lastG)){Line(Section,C(d-2*reach/200,lastG),C(d,g),Brushes.MediumSeaGreen,2);Line(Section,C(d-2*reach/200,lastD),C(d,z),Brushes.Orange,2);}lastG=g;lastD=z;}Text(Section,$"STA {len*Station.Value:N0}m · 계획고 {at.z+p.Offset:F1}m · ±{reach:F0}m",20,Section.ActualHeight-22);}
 void PlanClick(object s,MouseButtonEventArgs e){var a=e.GetPosition(Plan);double x=(a.X-15)/MapScale,y=(a.Y-15)/MapScale,z=p.Terrain.At(x,y);if(!double.IsFinite(z))return;if(p.Route.Count>0&&Corridor.Dist(p.Route[^1],new(x,y,z))<1)return;p.Route.Add(new(x,y,z));Render();}
 void ProfileClick(object s,MouseButtonEventArgs e){if(p.Route.Count<2)return;var a=e.GetPosition(Profile);double wanted=Math.Clamp((a.X-35)/Math.Max(1,Profile.ActualWidth-55),0,1)*Corridor.Length(p.Route),st=0,best=double.MaxValue;int index=0;for(int i=0;i<p.Route.Count;i++){if(i>0)st+=Corridor.Dist(p.Route[i-1],p.Route[i]);if(Math.Abs(st-wanted)<best){best=Math.Abs(st-wanted);index=i;}}double z=chartMax-(a.Y-15)/Math.Max(1,Profile.ActualHeight-45)*(chartMax-chartMin);p.Route[index]=p.Route[index] with{Z=z-p.Offset};Render();}
 void Apply(object s,RoutedEventArgs e){if(!double.TryParse(WidthInput.Text,out double w)||!double.TryParse(OffsetInput.Text,out double o)||!double.TryParse(SlopeInput.Text,out double sl)||!double.IsFinite(w)||!double.IsFinite(o)||!double.IsFinite(sl)||w<=0||sl<=0){MessageBox.Show("폭과 사면비는 양수, 높이 보정은 유한한 숫자로 입력하세요.");return;}p.RoadWidth=w;p.Offset=o;p.Slope=sl;Render();}
 void Demo(object s,RoutedEventArgs e){p=new();Sync();Render();}void Clear(object s,RoutedEventArgs e){p.Route.Clear();Render();}void Resize(object s,SizeChangedEventArgs e){if(IsLoaded){DrawPlan();DrawCharts();}}void StationChanged(object s,RoutedPropertyChangedEventArgs<double> e){if(IsLoaded)DrawCharts();}
 void Sync(){WidthInput.Text=p.RoadWidth.ToString();OffsetInput.Text=p.Offset.ToString();SlopeInput.Text=p.Slope.ToString();}
 async void OpenDem(object s,RoutedEventArgs e){var d=new OpenFileDialog{Filter="GeoTIFF|*.tif;*.tiff"};if(d.ShowDialog()!=true)return;string temp=System.IO.Path.GetTempFileName();try{IsEnabled=false;Status.Text="DEM 변환 중 · EPSG:5179 / 최대 161 격자";var info=new ProcessStartInfo("python"){UseShellExecute=false,CreateNoWindow=true,RedirectStandardError=true};info.ArgumentList.Add(System.IO.Path.Combine(AppContext.BaseDirectory,"dem_import.py"));info.ArgumentList.Add(d.FileName);info.ArgumentList.Add(temp);using var proc=Process.Start(info)!;string err=await proc.StandardError.ReadToEndAsync();await proc.WaitForExitAsync();if(proc.ExitCode!=0)throw new Exception(err);var t=JsonSerializer.Deserialize<Terrain>(await File.ReadAllTextAsync(temp))!;p=new Project{Terrain=t};Sync();Render();}catch(Exception ex){MessageBox.Show(ex.Message,"DEM 로드 실패");}finally{IsEnabled=true;File.Delete(temp);}}
 void Save(object s,RoutedEventArgs e){var d=new SaveFileDialog{Filter="K-ROAD project|*.kroad"};if(d.ShowDialog()==true)try{File.WriteAllText(d.FileName,JsonSerializer.Serialize(p));}catch(Exception ex){MessageBox.Show(ex.Message);}}
 void Load(object s,RoutedEventArgs e){var d=new OpenFileDialog{Filter="K-ROAD project|*.kroad"};if(d.ShowDialog()!=true)return;try{var q=JsonSerializer.Deserialize<Project>(File.ReadAllText(d.FileName))!;if(q.Terrain.Nx<2||q.Terrain.Ny<2||q.Terrain.Heights.Length!=q.Terrain.Nx*q.Terrain.Ny||q.Terrain.Dx<=0||q.Terrain.Dy<=0||q.RoadWidth<=0||q.Slope<=0)throw new Exception("유효하지 않은 프로젝트");p=q;Sync();Render();}catch(Exception ex){MessageBox.Show(ex.Message);}}
 void SceneDown(object s,MouseButtonEventArgs e){drag=e.GetPosition(Scene);Scene.CaptureMouse();}void SceneUp(object s,MouseButtonEventArgs e){drag=null;Scene.ReleaseMouseCapture();}void SceneMove(object s,MouseEventArgs e){if(drag is Point a){var b=e.GetPosition(Scene);yaw+=(b.X-a.X)*.4;drag=b;UpdateCamera();}}void SceneWheel(object s,MouseWheelEventArgs e){zoom=Math.Clamp(zoom*(e.Delta>0?.9:1.1),.15,5);UpdateCamera();}
}
