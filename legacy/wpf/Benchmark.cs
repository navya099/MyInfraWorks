using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
namespace KRoadPrototype;
public partial class MainWindow {
 void RunBenchmark(){
  p=new Project{Terrain=new Terrain{Nx=161,Ny=161,Dx=30,Dy=30,Name="Performance fixture",Heights=Enumerable.Range(0,161*161).Select(i=>(double?)(170+70*Math.Sin(i%161*.04)*Math.Cos(i/161*.04))).ToArray()},Route=[new(200,200,170),new(2200,2400,180),new(4400,4400,175)]};
  var clock=Stopwatch.StartNew();Render();double render=clock.Elapsed.TotalMilliseconds;
  clock.Restart();for(int i=0;i<3;i++){yaw+=1;DrawScene();}double scene=clock.Elapsed.TotalMilliseconds/3;
  var sceneModel=Scene.Children[0];var map=terrainBitmap;
  clock.Restart();for(int i=0;i<100;i++){yaw+=1;UpdateCamera();}double camera=clock.Elapsed.TotalMilliseconds/100;
  if(!ReferenceEquals(sceneModel,Scene.Children[0]))throw new Exception("Camera rebuilt geometry");
  DrawPlan();if(!ReferenceEquals(map,terrainBitmap))throw new Exception("Plan cache missed");
  File.WriteAllText(Environment.GetCommandLineArgs()[2],$"161x161, 3 route points: Render={render:F2}ms, DrawScene={scene:F2}ms, Camera={camera:F4}ms; PASS scene reuse / bitmap cache");Application.Current.Shutdown();
 }
}
