using KRoadPrototype;
static void Check(bool ok,string label){if(!ok)throw new Exception(label);Console.WriteLine("PASS "+label);}
var t=new Terrain{Nx=3,Ny=3,Dx=10,Dy=10,Heights=Enumerable.Repeat<double?>(100,9).ToArray()};
Check(t.At(5,5)==100,"bilinear flat terrain");Check(double.IsNaN(t.At(-1,0)),"out of bounds");
var p=new Project{Terrain=t,RoadWidth=4,Slope=2,Route=[new(0,10,110),new(20,10,110)]};
Check(Corridor.Length(p.Route)==20,"station length");Check(Corridor.Sample(p.Route,5).x==5,"station interpolation");
Check(Corridor.Design(p,10,10)==110,"fill platform");Check(Corridor.Design(p,10,18)==107,"fill slope H:V");
p.Route=[new(0,10,90),new(20,10,90)];Check(Corridor.Design(p,10,10)==90,"cut platform");Check(Corridor.Design(p,10,18)==93,"cut slope H:V");
t.Heights[0]=null;Check(double.IsNaN(t.At(1,1)),"NoData propagation");
var copy=System.Text.Json.JsonSerializer.Deserialize<Project>(System.Text.Json.JsonSerializer.Serialize(p))!;Check(copy.Route.Count==2&&copy.Terrain.Heights[0]==null,"project roundtrip");
