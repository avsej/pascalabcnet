// Copyright (�) Ivan Bondarev, Stanislav Mihalkovich (for details please see \doc\copyright.txt)
// This code is distributed under the GNU LGPL (for details please see \doc\license.txt)
unit Graph3D;

{$reference 'PresentationFramework.dll'}
{$reference 'WindowsBase.dll'}
{$reference 'PresentationCore.dll'}
{$reference System.Xml.dll}

{$reference HelixToolkit.Wpf.dll}
{reference Petzold.Media3D.dll}

{$apptype windows}

uses System.Windows;
uses System.Windows.Controls;
uses System.Windows.Shapes;
uses System.Windows.Media;
uses System.Windows.Media.Animation;
uses System.Windows.Media.Media3D;

uses System.Windows.Markup; 
uses System.XML; 
uses System.IO; 
uses System.Threading;
uses System.Windows.Input;

uses HelixToolkit.Wpf;
//uses Petzold.Media3D;

type
  Key = System.Windows.Input.Key;
  Colors = System.Windows.Media.Colors;
  GColor = System.Windows.Media.Color;
  GMaterial = System.Windows.Media.Media3D.Material;
  GCamera = System.Windows.Media.Media3D.ProjectionCamera;
  GRect = System.Windows.Rect;
  GWindow = System.Windows.Window;
  CameraMode = HelixToolkit.Wpf.CameraMode;
  TupleInt3 = (integer,integer,integer);  
  TupleReal3 = (real,real,real);

var
  MainFormThread: Thread; 
  app: Application;
  MainWindow: Window;
  hvp: HelixViewport3D;
  gvl: GridLinesVisual3D;
  /// ������� ������� �� ������ ����. (x,y) - ���������� ������� ���� � ������ ����������� �������, mousebutton = 1, ���� ������ ����� ������ ����, � 2, ���� ������ ������ ������ ����
  OnMouseDown: procedure(x, y: real; mousebutton: integer);
  /// ������� ������� ������ ����. (x,y) - ���������� ������� ���� � ������ ����������� �������, mousebutton = 1, ���� ������ ����� ������ ����, � 2, ���� ������ ������ ������ ����
  OnMouseUp: procedure(x, y: real; mousebutton: integer);
  /// ������� ����������� ����. (x,y) - ���������� ������� ���� � ������ ����������� �������, mousebutton = 0, ���� ������ ���� �� ������, 1, ���� ������ ����� ������ ����, � 2, ���� ������ ������ ������ ����
  OnMouseMove: procedure(x, y: real; mousebutton: integer);
  /// ������� ������� �������
  OnKeyDown: procedure(k: Key);
  /// ������� ������� �������
  OnKeyUp: procedure(k: Key);

function RGB(r,g,b: byte) := Color.Fromrgb(r, g, b);
function ARGB(a,r,g,b: byte) := Color.FromArgb(a, r, g, b);
function P3D(x,y,z: real) := new Point3D(x,y,z);
function V3D(x,y,z: real) := new Vector3D(x,y,z);
function Sz3D(x,y,z: real) := new Size3D(x,y,z);
function Pnt(x,y: real) := new Point(x,y);
function Rect(x,y,w,h: real) := new System.Windows.Rect(x,y,w,h);

function ChangeAlpha(Self: GColor; value: integer); extensionmethod := ARGB(value,Self.R, Self.G, Self.B);

function MoveX(Self: Point3D; dx: real); extensionmethod := P3D(Self.x + dx, Self.y, Self.z);
function MoveY(Self: Point3D; dy: real); extensionmethod := P3D(Self.x, Self.y + dy, Self.z);
function MoveZ(Self: Point3D; dz: real); extensionmethod := P3D(Self.x, Self.y, Self.z + dz);
function Move(Self: Point3D; dx,dy,dz: real); extensionmethod := P3D(Self.x + dx, Self.y + dy, Self.z + dz);

function operator implicit(t: TupleInt3): Point3D; extensionmethod := new Point3D(t[0],t[1],t[2]);
function operator implicit(t: TupleReal3): Point3D; extensionmethod := new Point3D(t[0],t[1],t[2]);

function operator implicit(ar: array of TupleInt3): Point3DCollection; extensionmethod := new Point3DCollection(ar.Select(t->new Point3D(t[0],t[1],t[2])));

function RandomColor := Color.Fromrgb(Random(256), Random(256), Random(256));

function RandomSolidBrush := new SolidColorBrush(RandomColor);

procedure Invoke(d: System.Delegate; params args: array of object) := app.Dispatcher.Invoke(d,args);
procedure Invoke(d: ()->()) := app.Dispatcher.Invoke(d);
function Invoke<T>(d: Func0<T>) := app.Dispatcher.Invoke&<T>(d);

function wplus := SystemParameters.WindowResizeBorderThickness.Left + SystemParameters.WindowResizeBorderThickness.Right;
function hplus := SystemParameters.WindowCaptionHeight + SystemParameters.WindowResizeBorderThickness.Top + SystemParameters.WindowResizeBorderThickness.Bottom;

type MHelper = auto class
  fname: string;
  opacity: real;
  function ImageMaterial := MaterialHelper.CreateImageMaterial(fname,opacity);
end;

function ImageMaterial(fname: string): GMaterial 
  := Invoke&<GMaterial>(MHelper.Create(fname,1).ImageMaterial);

/// --- SystemKeyEvents
procedure SystemOnKeyDown(sender: Object; e: System.Windows.Input.KeyEventArgs) := 
begin
  if OnKeyDown<>nil then
    OnKeyDown(e.Key);
end;    

procedure SystemOnKeyUp(sender: Object; e: System.Windows.Input.KeyEventArgs) := 
  if OnKeyUp<>nil then
    OnKeyUp(e.Key);

/// --- SystemMouseEvents
procedure SystemOnMouseDown(sender: Object; e: System.Windows.Input.MouseButtonEventArgs);
begin
  var mb := 0;
  var p := e.GetPosition(hvp);
  if e.LeftButton = MouseButtonState.Pressed then
    mb := 1
  else if e.RightButton = MouseButtonState.Pressed then
    mb := 2;
  if OnMouseDown <> nil then  
    OnMouseDown(p.x, p.y, mb);
end;

procedure SystemOnMouseUp(sender: Object; e: MouseButtonEventArgs);
begin
  var mb := 0;
  var p := e.GetPosition(hvp);
  if e.LeftButton = MouseButtonState.Pressed then
    mb := 1
  else if e.RightButton = MouseButtonState.Pressed then
    mb := 2;
  if OnMouseUp <> nil then  
    OnMouseUp(p.x, p.y, mb);
end;

procedure SystemOnMouseMove(sender: Object; e: MouseEventArgs);
begin
  var mb := 0;
  var p := e.GetPosition(hvp);
  if e.LeftButton = MouseButtonState.Pressed then
    mb := 1
  else if e.RightButton = MouseButtonState.Pressed then
    mb := 2;
  if OnMouseMove <> nil then  
    OnMouseMove(p.x, p.y, mb);
end;

type
///!#
  View3DT = class
  private
    procedure SetSCSP(v: boolean) := hvp.ShowCoordinateSystem := v;
    procedure SetSCS(v: boolean) := Invoke(SetSCSP,v);
    function GetSCS: boolean := Invoke&<boolean>(()->hvp.ShowCoordinateSystem);

    procedure SetSGLP(v: boolean) := gvl.Visible := v;
    procedure SetSGL(v: boolean) := Invoke(SetSGLP,v);
    function GetSGL: boolean := Invoke&<boolean>(()->gvl.Visible);

    procedure SetSCIP(v: boolean) := hvp.ShowCameraInfo := v;
    procedure SetSCI(v: boolean) := Invoke(SetSCIP,v);
    function GetSCI: boolean := Invoke&<boolean>(()->hvp.ShowCameraInfo);

    procedure SetSVCP(v: boolean) := hvp.ShowViewCube := v;
    procedure SetSVC(v: boolean) := Invoke(SetSVCP,v);
    function GetSVC: boolean := Invoke&<boolean>(()->hvp.ShowViewCube);

    procedure SetTP(v: string) := hvp.Title := v;
    procedure SetT(v: string) := Invoke(SetTP,v);
    function GetT: string := Invoke&<string>(()->hvp.Title);

    procedure SetSTP(v: string) := hvp.SubTitle := v;
    procedure SetST(v: string) := Invoke(SetSTP,v);
    function GetST: string := Invoke&<string>(()->hvp.SubTitle);

    procedure SetCMP(v: HelixToolkit.Wpf.CameraMode) := hvp.CameraMode := v;
    procedure SetCM(v: HelixToolkit.Wpf.CameraMode) := Invoke(SetCMP,v);
    function GetCM: HelixToolkit.Wpf.CameraMode := Invoke&<HelixToolkit.Wpf.CameraMode>(()->hvp.CameraMode);

    procedure SetBCP(v: GColor) := hvp.Background := new SolidColorBrush(v);
    procedure SetBC(v: GColor) := Invoke(SetBCP,v);
    function GetBC: GColor := Invoke&<GColor>(()->(hvp.Background as SolidColorBrush).Color);
    procedure ExportP(fname: string) := hvp.Viewport.Export(fname,hvp.Background);
  public
    property ShowCoordinateSystem: boolean read GetSCS write SetSCS;
    property ShowGridLines: boolean read GetSGL write SetSGL;
    property ShowCameraInfo: boolean read GetSCI write SetSCI;
    property ShowViewCube: boolean read GetSVC write SetSVC;
    property Title: string read GetT write SetT;
    property SubTitle: string read GetST write SetST;
    property CameraMode: HelixToolkit.Wpf.CameraMode read GetCM write SetCM;
    property BackgroundColor: GColor read GetBC write SetBC;
    
    procedure Save(fname: string) := Invoke(ExportP,fname);
  end;

 ///!#
  CameraType = class
  private 
    function Cam: GCamera := hvp.Camera;
    procedure SetPP(p: Point3D) := begin Cam.Position := p; Cam.LookDirection := Cam.Position.Multiply(-1).ToVector3D; end;
    procedure SetP(p: Point3D) := Invoke(SetPP,p);
    function GetP: Point3D := Invoke&<Point3D>(()->Cam.Position);
    procedure SetLDP(v: Vector3D) := Cam.LookDirection := v;
    procedure SetLD(v: Vector3D) := Invoke(SetLDP,v);
    function GetLD: Vector3D := Invoke&<Vector3D>(()->Cam.LookDirection);
    procedure SetUDP(v: Vector3D) := Cam.UpDirection := v;
    procedure SetUD(v: Vector3D) := Invoke(SetUDP,v);
    function GetUD: Vector3D := Invoke&<Vector3D>(()->Cam.UpDirection);
    procedure SetDP(d: real);
    begin
      var dist := Position.DistanceTo(P3D(0,0,0));
      Position := Position.Multiply(d/dist);
    end;
    procedure SetD(d: real) := Invoke(SetDP,d);
    function GetD: real := Invoke&<real>(()->Cam.Position.DistanceTo(P3D(0,0,0)));
  public 
    property Position: Point3D read GetP write SetP;
    property LookDirection: Vector3D read GetLD write SetLD;
    property UpDirection: Vector3D read GetUD write SetUD;
    property Distanse: real read GetD write SetD;
  end;

 ///!#
  WindowType = class
  private 
    procedure SetLeft(l: real);
    function GetLeft: real;
    procedure SetTop(t: real);
    function GetTop: real;
    procedure SetWidth(w: real);
    function GetWidth: real;
    procedure SetHeight(h: real);
    function GetHeight: real;
    procedure SetCaption(c: string);
    function GetCaption: string;
  public 
    /// ������ ������������ ���� �� ������ ���� ������ � ��������
    property Left: real read GetLeft write SetLeft;
    /// ������ ������������ ���� �� �������� ���� ������ � ��������
    property Top: real read GetTop write SetTop;
    /// ������ ���������� ����� ������������ ���� � ��������
    property Width: real read GetWidth write SetWidth;
    /// ������ ���������� ����� ������������ ���� � ��������
    property Height: real read GetHeight write SetHeight;
    /// ��������� ������������ ����
    property Caption: string read GetCaption write SetCaption;
    /// ��������� ������������ ����
    property Title: string read GetCaption write SetCaption;
    /// ������������� ������� ���������� ����� ������������ ���� � ��������
    procedure SetSize(w, h: real);
    /// ������������� ������ ������������ ���� �� ������ �������� ���� ������ � ��������
    procedure SetPos(l, t: real);
    /// ��������� ����������� ���� � ��������� ����������
    procedure Close;
    /// ����������� ����������� ����
    procedure Minimize;
    /// ������������� ����������� ����
    procedure Maximize;
    /// ���������� ����������� ���� � ����������� �������
    procedure Normalize;
    /// ���������� ����������� ���� �� ������ ������
    procedure CenterOnScreen;
    /// ���������� ����� ������������ ����
    function Center: Point;
    /// ���������� ������������� ���������� ������� ����
    function ClientRect: GRect;
  end;  

var 
  View3D: View3DT;
  Window: WindowType;
  Camera: CameraType;

type
///!#
  Base0T = class
  private
    model: Visual3D;
    transfgroup := new Transform3DGroup; 
    rotatetransform_anim := new MatrixTransform3D;
    scaletransform := new ScaleTransform3D;
    translatetransform: TranslateTransform3D;
    
    procedure CreateBase0(m: Visual3D; x,y,z: real);
    begin
      model := m;
      translatetransform := new TranslateTransform3D(x,y,z);
      transfgroup.Children.Add(new MatrixTransform3D); // ������������ �� �������. �� ������ � ��������� ���������� �.�. ��� �������� �������� ��� ������, � �� ���� �������!!!
      transfgroup.Children.Add(rotatetransform_anim);
      transfgroup.Children.Add(scaletransform); 
      transfgroup.Children.Add(translatetransform);
      model.Transform := transfgroup;
      hvp.Children.Add(model);
    end;
    procedure SetX(xx: real) := Invoke(()->begin translatetransform.OffsetX := xx; end); 
    function GetX: real := Invoke&<real>(()->translatetransform.OffsetX);
    procedure SetY(yy: real) := Invoke(()->begin translatetransform.OffsetY := yy; end);
    function GetY: real := Invoke&<real>(()->translatetransform.OffsetY);
    procedure SetZ(zz: real) := Invoke(()->begin translatetransform.OffsetZ := zz; end);
    function GetZ: real := Invoke&<real>(()->translatetransform.OffsetZ);
    function GetPos: Point3D := Invoke&<Point3D>(()->P3D(translatetransform.OffsetX,translatetransform.OffsetY,translatetransform.OffsetZ));
  public  
    property X: real read GetX write SetX;
    property Y: real read GetY write SetY;
    property Z: real read GetZ write SetZ;

    procedure MoveTo(xx,yy,zz: real) := 
      Invoke(()->begin 
        translatetransform.OffsetX := xx;
        translatetransform.OffsetY := yy;
        translatetransform.OffsetZ := zz;
      end);
    procedure MoveTo(p: Point3D) := MoveTo(p.X,p.y,p.z);
    procedure MoveOn(dx,dy,dz: real) := MoveTo(x+dx,y+dy,z+dz);
    procedure MoveOn(v: Vector3D) := MoveOn(v.X,v.Y,v.Z);

    property Position: Point3D read GetPos write MoveTo;
    
    procedure Scale(f: real) := 
      Invoke(()->begin
        scaletransform.ScaleX *= f;
        scaletransform.ScaleY *= f;
        scaletransform.ScaleZ *= f;
      end);
    /// ������� �� ���� angle ������ ��� axis
    procedure Rotate(axis: Vector3D; angle: real) := 
      Invoke(()->begin
        var m := transfgroup.Children[0].Value; 
        m.Rotate(new Quaternion(axis,angle));
        transfgroup.Children[0] := new MatrixTransform3D(m);
      end);
    /// ������� �� ���� angle ������ ��� axis ������������ ����� center
    procedure RotateAt(axis: Vector3D; angle: real; center: Point3D);
    begin
      Invoke(()->begin
        var m := transfgroup.Children[0].Value;    
        m.RotateAt(new Quaternion(axis,angle),center);
        transfgroup.Children[0] := new MatrixTransform3D(m);
      end);
    end;
  end;  
  
  BaseT = class(Base0T)
  private
    procedure CreateBase(m: MeshElement3D; x,y,z: real; c: Color);
    begin
      CreateBase0(m,x,y,z);
      var ColorMaterial := MaterialHelper.CreateMaterial(c);
      m.Material := ColorMaterial;
    end;
    procedure CreateBase(m: MeshElement3D; x,y,z: real; mat: GMaterial);
    begin
      CreateBase0(m,x,y,z);
      m.Material := mat;
    end;
    procedure SetColorP(c: GColor) := (model as MeshElement3D).Material := MaterialHelper.CreateMaterial(c);
    procedure SetColor(c: GColor) := Invoke(SetColorP,c); 
    procedure SetVP(v: boolean) := (model as MeshElement3D).Visible := v;
    procedure SetV(v: boolean) := Invoke(SetVP,v);
    function GetV: boolean := Invoke&<boolean>(()->(model as MeshElement3D).Visible);

    procedure SetMP(mat: GMaterial) := (model as MeshElement3D).Material := mat;
    procedure SetM(mat: GMaterial) := Invoke(SetMP,mat);
    function GetM: GMaterial := Invoke&<GMaterial>(()->(model as MeshElement3D).Material);
  public  
    property Color: GColor write SetColor;
    property Material: GMaterial read GetM write SetM;
    property Visible: boolean read GetV write SetV;
  end;  
  
  SphereT = class(BaseT)
  private
    procedure SetR(r: real); 
    begin 
      var m := model as SphereVisual3D;
      Invoke(()->begin m.Radius := r end);
    end;  
    function GetR: real := Invoke&<real>(()->(model as SphereVisual3D).Radius);
  public
    constructor(x,y,z,r: real; c: GColor);
    begin
      var sph := new SphereVisual3D;
      sph.Center := P3D(0, 0, 0);
      sph.Radius := r;
      CreateBase(sph,x,y,z,c);
    end;
    property Radius: real read GetR write SetR;
    (*procedure AnimProbaP;
    begin
      var sb := new StoryBoard;
      var da := new DoubleAnimation(1,3,new Duration(System.TimeSpan.FromSeconds(3)));
      da.FillBehavior := FillBehavior.HoldEnd;
      //da.RepeatBehavior := RepeatBehavior.Forever;
      //translatetransform.BeginAnimation(TranslateTransform3D.OffsetXProperty,da);
      //translatetransform.BeginAnimation(TranslateTransform3D.OffsetYProperty,da);
      //translatetransform.BeginAnimation(TranslateTransform3D.OffsetZProperty,da);
      sb.Children.Add(da);
      {StoryBoard.SetTarget(da,translatetransform);
      var pi: System.Reflection.PropertyInfo := translatetransform.Gettype.GetProperty('OffsetX');
      StoryBoard.SetTargetProperty(da,new PropertyPath(SphereVisual3D.RadiusProperty));}
      StoryBoard.SetTarget(da,translatetransform);
      StoryBoard.SetTargetProperty(da,new PropertyPath(TranslateTransform3D.OffsetXProperty));

      //StoryBoard.SetTarget(da,scaletransform);
      //StoryBoard.SetTargetProperty(da,new PropertyPath(ScaleTransform3D.ScaleXProperty));
      
      //StoryBoard.SetTarget(da,model);
      //StoryBoard.SetTargetProperty(da,new PropertyPath(SphereVisual3D.RadiusProperty));
      sb.Completed += (o,e) -> Print('end!');
      sb.CurrentTimeInvalidated += (o,e) -> Print(1);
      
      var ex := new HelixToolkit.Wpf.XamlExporter('sph.xaml');
      ex.Export(model);

      sb.Begin;
    end;*)
    //procedure AnimProba := Invoke(AnimProbaP);
  end;
  
  EllipsoidT = class(BaseT)
  private
    procedure SetRXP(r: real) := (model as EllipsoidVisual3D).RadiusX := r;
    procedure SetRX(r: real) := Invoke(SetRXP,x);
    function GetRX: real := Invoke&<real>(()->(model as EllipsoidVisual3D).RadiusX);
    procedure SetRYP(r: real) := (model as EllipsoidVisual3D).RadiusY := r;
    procedure SetRY(r: real) := Invoke(SetRYP,x);
    function GetRY: real := Invoke&<real>(()->(model as EllipsoidVisual3D).RadiusY);
    procedure SetRZP(r: real) := (model as EllipsoidVisual3D).RadiusZ := r;
    procedure SetRZ(r: real) := Invoke(SetRZP,x);
    function GetRZ: real := Invoke&<real>(()->(model as EllipsoidVisual3D).RadiusZ);
  public
    constructor(x,y,z,rx,ry,rz: real; c: GColor);
    begin
      var ell := new EllipsoidVisual3D;
      ell.Center := P3D(0, 0, 0);
      ell.RadiusX := rx;
      ell.RadiusY := ry;
      ell.RadiusZ := rz;
      CreateBase(ell,x,y,z,c);
    end;
    property RadiusX: real read GetRX write SetRX;
    property RadiusY: real read GetRY write SetRY;
    property RadiusZ: real read GetRZ write SetRZ;
  end;  
  
  BoxT = class(BaseT)
  private
    procedure SetWP(r: real) := (model as BoxVisual3D).Width := r;
    procedure SetW(r: real) := Invoke(SetWP,r);
    function GetW: real := Invoke&<real>(()->(model as BoxVisual3D).Width);
    
    procedure SetHP(r: real) := (model as BoxVisual3D).Height := r;
    procedure SetH(r: real) := Invoke(SetHP,r); 
    function GetH: real := Invoke&<real>(()->(model as BoxVisual3D).Height);

    procedure SetLP(r: real) := (model as BoxVisual3D).Length := r;
    procedure SetL(r: real) := Invoke(SetLP,r);
    function GetL: real := Invoke&<real>(()->(model as BoxVisual3D).Length);

    procedure SetSzP(r: Size3D);
    begin
      var mmm := model as BoxVisual3D;
      (mmm.Length,mmm.Width,mmm.Height) := (r.X,r.Y,r.Z);
    end;
    procedure SetSz(r: Size3D) := Invoke(SetSzP,r);
    function GetSz: Size3D := Invoke&<Size3D>(()->begin var mmm := model as BoxVisual3D; Result := Sz3D(mmm.Length,mmm.Width,mmm.Height) end);
  public
    constructor(x,y,z,l,w,h: real; c: GColor);
    begin
      var bx := new BoxVisual3D;
      bx.Center := P3D(0,0,0);
      (bx.Width,bx.Height,bx.Length) := (w,h,l);
      CreateBase(bx,x,y,z,c);
    end;
    property Length: real read GetL write SetL;
    property Width: real read GetW write SetW;
    property Height: real read GetH write SetH;
    property Size: Size3D read GetSz write SetSz;
  end;
  
  ArrowT = class(BaseT)
  private
    procedure SetDP(r: real) := (model as ArrowVisual3D).Diameter := r;
    procedure SetD(r: real) := Invoke(SetDP,r);
    function GetD: real := Invoke&<real>(()->(model as ArrowVisual3D).Diameter);

    procedure SetLP(r: real) := (model as ArrowVisual3D).HeadLength := r;
    procedure SetL(r: real) := Invoke(SetLP,r);
    function GetL: real := Invoke&<real>(()->(model as ArrowVisual3D).HeadLength);

    procedure SetDirP(r: Vector3D) := (model as ArrowVisual3D).Direction := r;
    procedure SetDir(r: Vector3D) := Invoke(SetDirP,r);
    function GetDir: Vector3D := Invoke&<Vector3D>(()->(model as ArrowVisual3D).Direction);
  public
    constructor(x,y,z,dx,dy,dz,d,hl: real; c: GColor);
    begin
      var a := new ArrowVisual3D;
      a.HeadLength := hl;
      a.Diameter := d;
      a.Origin := P3D(0,0,0);
      CreateBase(a,x,y,z,c);
      a.Direction := V3D(dx,dy,dz);
    end;
    property HeadLength: real read GetL write SetL;
    property Diameter: real read GetD write SetD;
    property Direction: Vector3D read GetDir write SetDir;
  end;
  
  TruncatedConeT = class(BaseT)
  private
    procedure SetHP(r: real) := (model as TruncatedConeVisual3D).Height := r;
    procedure SetH(r: real) := Invoke(SetHP,r); 
    function GetH: real := Invoke&<real>(()->(model as TruncatedConeVisual3D).Height);

    procedure SetBRP(r: real) := (model as TruncatedConeVisual3D).BaseRadius := r;
    procedure SetBR(r: real) := Invoke(SetBRP,r); 
    function GetBR: real := Invoke&<real>(()->(model as TruncatedConeVisual3D).BaseRadius);

    procedure SetTRP(r: real) := (model as TruncatedConeVisual3D).TopRadius := r;
    procedure SetTR(r: real) := Invoke(SetTRP,r); 
    function GetTR: real := Invoke&<real>(()->(model as TruncatedConeVisual3D).TopRadius);

    procedure SetTCP(r: boolean) := (model as TruncatedConeVisual3D).TopCap := r;
    procedure SetTC(r: boolean) := Invoke(SetTCP,r); 
    function GetTC: boolean := Invoke&<boolean>(()->(model as TruncatedConeVisual3D).TopCap);

  public
    constructor(x,y,z,h,baser,topr: real; sides: integer; topcap: boolean; c: GColor);
    begin
      var a := new TruncatedConeVisual3D;
      a.Origin := p3D(0,0,0);
      a.BaseRadius := baser;
      a.TopRadius := topr;
      a.Height := h;
      a.TopCap := topcap;
      a.ThetaDiv := sides + 1;
      CreateBase(a,x,y,z,c);
    end;
    property Height: real read GetH write SetH;
    property BaseRadius: real read GetBR write SetBR;
    property TopRadius: real read GetTR write SetTR;
    property Topcap: boolean read GetTC write SetTC;
  end;
  
  TeapotT = class(BaseT)
  private
    procedure SetVP(v: boolean) := (model as MeshElement3D).Visible := v;
    procedure SetV(v: boolean) := Invoke(SetVP,v);
    function GetV: boolean := Invoke&<boolean>(()->(model as MeshElement3D).Visible);
  public
    constructor(x,y,z: real; c: GColor);
    begin
      var a := new Teapot;
      CreateBase(a,x,y,z,c);
      Rotate(V3D(1,0,0),90);
      //a.Position := P3D(x,y,z);
    end;
    property Visible: boolean read GetV write SetV;
  end;

  CoordinateSystemT = class(Base0T)
  private
    procedure SetALP(r: real) := (model as CoordinateSystemVisual3D).ArrowLengths := r;
    procedure SetAL(r: real) := Invoke(SetALP,r); 
    function GetAL: real := Invoke&<real>(()->(model as CoordinateSystemVisual3D).ArrowLengths);
  public
    constructor(x,y,z,arrlength,diameter: real);
    begin
      var a := new CoordinateSystemVisual3D;
      CreateBase0(a,x,y,z);
      a.ArrowLengths := arrlength;
      (a.Children[0] as ArrowVisual3D).Diameter := diameter;
      (a.Children[1] as ArrowVisual3D).Diameter := diameter;
      (a.Children[2] as ArrowVisual3D).Diameter := diameter;
      (a.Children[3] as CubeVisual3D).SideLength := diameter;
    end;
    property ArrowLengths: real read GetAL write SetAL;
  end;

  BillboardTextT = class(Base0T)
  private
    procedure SetTP(r: string) := (model as BillboardTextVisual3D).Text := r;
    procedure SetT(r: string) := Invoke(SetTP,r); 
    function GetT: string := Invoke&<string>(()->(model as BillboardTextVisual3D).Text);

    procedure SetFSP(r: real) := (model as BillboardTextVisual3D).FontSize := r;
    procedure SetFS(r: real) := Invoke(SetFS,r); 
    function GetFS: real := Invoke&<real>(()->(model as BillboardTextVisual3D).FontSize);
  public
    constructor(x,y,z: real; text: string; fontsize: real);
    begin
      var a := new BillboardTextVisual3D;
      CreateBase0(a,x,y,z);
      a.Position := p3D(0,0,0);
      a.Text := text;
      a.FontSize := fontsize;
    end;
    property Text: string read GetT write SetT;
    property FontSize: real read GetFS write SetFS;
  end;

  TextT = class(Base0T)
  private
    procedure SetTP(r: string) := (model as TextVisual3D).Text := r;
    procedure SetT(r: string) := Invoke(SetTP,r); 
    function GetT: string := Invoke&<string>(()->(model as TextVisual3D).Text);

    procedure SetFSP(r: real) := (model as TextVisual3D).Height := r;
    procedure SetFS(r: real) := Invoke(SetFS,r); 
    function GetFS: real := Invoke&<real>(()->(model as TextVisual3D).Height);

    procedure SetNP(r: string) := (model as TextVisual3D).Text := r;
    procedure SetN(r: string) := Invoke(SetTP,r); 
    function GetN: string := Invoke&<string>(()->(model as TextVisual3D).Text);

    procedure SetColorP(c: GColor) := (model as TextVisual3D).Foreground := new SolidColorBrush(c);
    procedure SetColor(c: GColor) := Invoke(SetColorP,c); 
  public
    constructor(x,y,z: real; text: string; height: real; fontname: string; c: Color);
    begin
      var a := new TextVisual3D;
      CreateBase0(a,x,y,z);
      a.Position := p3D(0,0,0);
      a.Text := text;
      a.Height := height;
      a.FontFamily := new FontFamily(fontname);
      a.Foreground := new SolidColorBrush(c);
    end;
    property Text: string read GetT write SetT;
    property Height: real read GetFS write SetFS;
    property Name: string read GetN write SetN;
    property Color: GColor write SetColor;
  end;

  RectangleT = class(BaseT)
  private
    procedure SetWP(r: real) := (model as RectangleVisual3D).Width := r;
    procedure SetW(r: real) := Invoke(SetWP,r);
    function GetW: real := Invoke&<real>(()->(model as RectangleVisual3D).Width);
    
    procedure SetLP(r: real) := (model as RectangleVisual3D).Length := r;
    procedure SetL(r: real) := Invoke(SetLP,r);
    function GetL: real := Invoke&<real>(()->(model as RectangleVisual3D).Length);

    procedure SetLDP(r: Vector3D) := (model as RectangleVisual3D).LengthDirection := r;
    procedure SetLD(r: Vector3D) := Invoke(SetLDP,r);
    function GetLD: Vector3D := Invoke&<Vector3D>(()->(model as RectangleVisual3D).LengthDirection);
   
    procedure SetNP(r: Vector3D) := (model as RectangleVisual3D).Normal := r;
    procedure SetN(r: Vector3D) := Invoke(SetNP,r);
    function GetN: Vector3D := Invoke&<Vector3D>(()->(model as RectangleVisual3D).Normal);
  public
    constructor(x,y,z,l,w: real; normal,lendirection: Vector3D; c: GColor);
    begin
      var a := new RectangleVisual3D;
      CreateBase(a,x,y,z,c);
      a.Origin := P3D(0,0,0);
      a.Width := w;
      a.Length := l;
      a.LengthDirection := lendirection;
      a.Normal := normal;
    end;
    property Width: real read GetW write SetW;
    property Length: real read GetL write SetL;
    property LengthDirection: Vector3D read GetLD write SetLD;
    property Normal: Vector3D read GetN write SetN;
  end;

  FileModelT = class(Base0T)
  private
    procedure SetVP(v: boolean) := (model as MeshElement3D).Visible := v;
    procedure SetV(v: boolean) := Invoke(SetVP,v);
    function GetV: boolean := Invoke&<boolean>(()->(model as MeshElement3D).Visible);
  public
    constructor(x,y,z: real; fname: string);
    begin
      var a := new FileModelVisual3D;
      a.Source := fname;
      CreateBase0(a,x,y,z);
    end;
    property Visible: boolean read GetV write SetV;
  end;
  
  PipeT = class(BaseT)
  private
    procedure SetDP(r: real) := (model as PipeVisual3D).Diameter := r*2;
    procedure SetD(r: real) := Invoke(SetDP,r); 
    function GetD: real := Invoke&<real>(()->(model as PipeVisual3D).Diameter/2);

    procedure SetIDP(r: real) := (model as PipeVisual3D).InnerDiameter := r*2;
    procedure SetID(r: real) := Invoke(SetIDP,r); 
    function GetID: real := Invoke&<real>(()->(model as PipeVisual3D).InnerDiameter/2);

    procedure SetHP(r: real) := (model as PipeVisual3D).Point2 := P3D(0,0,r);
    procedure SetH(r: real) := Invoke(SetHP,r); 
    function GetH: real := Invoke&<real>(()->(model as PipeVisual3D).Point2.Z);
  public
    constructor(x,y,z,h,r,ir: real; c: GColor);
    begin
      var a := new PipeVisual3D;
      a.Diameter := r*2;
      a.InnerDiameter := ir*2;
      a.Point1 := P3D(0,0,0);
      a.Point2 := P3D(0,0,h);
      CreateBase(a,x,y,z,c);
    end;
    property Radius: real read GetD write SetD;
    property InnerRadius: real read GetID write SetID;
    property Height: real read GetH write SetH;
  end;
  

  AnyT = class(BaseT)
    constructor(x,y,z: real; c: GColor);
    begin
      //HelixToolkit.Wpf.LinesVisual3D
      
      var a := new HelixToolkit.Wpf.LinesVisual3D;
      
      var aa := 1;
      var b := 80;
      
      var q := Partition(0,2*Pi*20,360*20*10).Select(t->P3D(5*cos(1*t),5*sin(1*t),t/5));
      var q1 := q.Interleave(q.Skip(1));
      
      //a.Points := Lst(P3D(0,0,0),P3D(4,4,2),p3D(4,4,2),p3D(2,8,-1));
      a.Points := Lst(q1);
      a.Color := Colors.Blue;
      
      a.Thickness := 1.5;

      {var a := new HelixToolkit.Wpf.PieSliceVisual3D;
      a.StartAngle := 0;
      a.EndAngle := 360;
      a.ThetaDiv := 60;}
      
      {var a := new HelixToolkit.Wpf.TubeVisual3D;
      var p := new Point3DCollection(Arr(P3D(1,2,0),P3D(2,1,0),P3D(3,1,0)));
      a.Diameter := 0.05;
      a.Path := p;}
      
      
      
      CreateBase0(a,x,y,z);
      //a.Fill := Brushes.Aqua;
    end;
  end;
  
{procedure ProbaP;
begin
  //var ms := new TorusMesh();
  //ms.Radius := 4;
  //var ms := new IcosahedronMesh();
  //ms.Geometry.
  //var mg3d := ms.Geometry;
  
  var blueMaterial := MaterialHelper.CreateMaterial(Colors.Bisque);
  

  var g3d := new GeometryModel3D(mg3d, blueMaterial);
  var modelGroup := new Model3DGroup();
  modelGroup.Children.Add(g3d);
  
  var model := new ModelVisual3D();
  model.Content := modelGroup;|
  hvp.Children.Add(model);
end;

procedure Proba := Invoke(ProbaP);}

function Sphere(x,y,z,r: real; c: Color): SphereT := Invoke&<SphereT>(()->SphereT.Create(x,y,z,r,c));
function Sphere(center: Point3D; r: real; c: Color) := Sphere(center.x,center.y,center.z,r,c);

function Ellipsoid(x,y,z,rx,ry,rz: real; c: Color): EllipsoidT := Invoke&<EllipsoidT>(()->EllipsoidT.Create(x,y,z,rx,ry,rz,c));
function Ellipsoid(center: Point3D; rx,ry,rz: real; c: Color): EllipsoidT := Ellipsoid(center.x,center.y,center.z,rx,ry,rz,c);

function Box(x,y,z,l,w,h: real; c: Color): BoxT := Invoke&<BoxT>(()->BoxT.Create(x,y,z,l,w,h,c));
function Box(center: Point3D; sz: Size3D; c: Color): BoxT := Invoke&<BoxT>(()->BoxT.Create(center.x,center.y,center.z,sz.X,sz.Y,sz.z,c));
function Cube(x,y,z,w: real; c: Color) := Box(x,y,z,w,w,w,c);
function Cube(center: Point3D; w: real; c: Color) := Box(center.x,center.y,center.z,w,w,w,c);

const 
  arhl = 3;
  ard  = 0.2;

function Arrow(x,y,z,vx,vy,vz,diameter,hl: real; c: Color): ArrowT := Invoke&<ArrowT>(()->ArrowT.Create(x,y,z,vx,vy,vz,diameter,hl,c));
function Arrow(x,y,z,vx,vy,vz,diameter: real; c: Color) := Arrow(x,y,z,vx,vy,vz,diameter,arhl,c);
function Arrow(x,y,z,vx,vy,vz: real; c: Color): ArrowT := Arrow(x,y,z,vx,vy,vz,ard,arhl,c);
function Arrow(p: Point3D; v: Vector3D; diameter,hl: real; c: Color) := Arrow(p.x,p.y,p.z,v.X,v.Y,v.Z,diameter,hl,c);
function Arrow(p: Point3D; v: Vector3D; diameter: real; c: Color) := Arrow(p.x,p.y,p.z,v.X,v.Y,v.Z,diameter,arhl,c);
function Arrow(p: Point3D; v: Vector3D; c: Color) := Arrow(p.x,p.y,p.z,v.X,v.Y,v.Z,ard,arhl,c);

function TruncatedConeAux(x,y,z,height,baseradius,topradius: real; sides: integer; topcap: boolean; c: GColor) := 
  Invoke&<TruncatedConeT>(()->TruncatedConeT.Create(x,y,z,height,baseradius,topradius,sides,topcap,c));
  
{function Pyramid(x,y,z,height,baseradius,topradius: real; sides: integer; topcap: boolean; c: GColor) 
  := TruncatedConeAux(x,y,z,height,baseradius,topradius,sides,topcap,c); 
function Pyramid(x,y,z,height,baseradius,topradius: real; sides: integer; c: GColor) 
  := TruncatedConeAux(x,y,z,height,baseradius,topradius,sides,True,c); 
function Pyramid(p: Point3D; height,baseradius,topradius: real; sides: integer; topcap: boolean; c: GColor) 
  := TruncatedConeAux(p.x,p.y,p.z,height,baseradius,topradius,sides,topcap,c); 
function Pyramid(p: Point3D; height,baseradius,topradius: real; sides: integer; c: GColor) 
  := TruncatedConeAux(p.x,p.y,p.z,height,baseradius,topradius,sides,True,c); }

const maxsides = 37;
  
function TruncatedCone(x,y,z,height,baseradius,topradius: real; topcap: boolean; c: GColor) 
  := TruncatedConeAux(x,y,z,height,baseradius,topradius,maxsides,topcap,c); 
function TruncatedCone(x,y,z,height,baseradius,topradius: real; c: GColor) 
  := TruncatedCone(x,y,z,height,baseradius,topradius,True,c);
function TruncatedCone(p: Point3D; height,baseradius,topradius: real; topcap: boolean; c: GColor) 
  := TruncatedCone(p.x,p.y,p.z,height,baseradius,topradius,topcap,c);
function TruncatedCone(p: Point3D; height,baseradius,topradius: real; c: GColor) 
  := TruncatedCone(p.x,p.y,p.z,height,baseradius,topradius,True,c);

{function Prism(x,y,z,height,radius: real; sides: integer; topcap: boolean; c: GColor) 
  := TruncatedConeAux(x,y,z,height,radius,radius,sides,topcap,c);
function Prism(x,y,z,height,radius: real; sides: integer; c: GColor) 
  := TruncatedConeAux(x,y,z,height,radius,radius,sides,True,c);
function Prism(p: Point3D; height,radius: real; sides: integer; topcap: boolean; c: GColor) 
  := TruncatedConeAux(p.x,p.y,p.z,height,radius,radius,sides,topcap,c);
function Prism(p: Point3D; height,radius: real; sides: integer; c: GColor) 
  := TruncatedConeAux(p.x,p.y,p.z,height,radius,radius,sides,True,c);}

function Cylinder(x,y,z,height,radius: real; topcap: boolean; c: GColor): TruncatedConeT := TruncatedCone(x,y,z,height,radius,radius,topcap,c);
function Cylinder(x,y,z,height,radius: real; c: GColor) := Cylinder(x,y,z,height,radius,True,c);
function Cylinder(p: Point3D; height,radius: real; topcap: boolean; c: GColor) := Cylinder(p.x,p.y,p.z,height,radius,topcap,c);
function Cylinder(p: Point3D; height,radius: real; c: GColor) := Cylinder(p.x,p.y,p.z,height,radius,True,c);

function Tube(x,y,z,height,radius,innerradius: real; c: GColor): PipeT 
  := Invoke&<PipeT>(()->PipeT.Create(x,y,z,height,radius,innerradius,c));
function Tube(p: Point3D; height,radius,innerradius: real; c: GColor) 
  := Tube(p.x,p.y,p.z,height,radius,innerradius,c);

function Cone(x,y,z,height,radius: real; c: GColor): TruncatedConeT := TruncatedCone(x,y,z,height,radius,0,True,c);
function Cone(p: Point3D; height,radius: real; c: GColor) := TruncatedCone(p.x,p.y,p.z,height,radius,0,True,c);

function Teapot(x,y,z: real; c: GColor): TeapotT := Invoke&<TeapotT>(()->TeapotT.Create(x,y,z,c));
function Teapot(p: Point3D; c: GColor) := Teapot(p.x,p.y,p.z,c);

function BillboardText(x,y,z: real; text: string; fontsize: real): BillboardTextT := Invoke&<BillboardTextT>(()->BillboardTextT.Create(x,y,z,text,fontsize));
function BillboardText(p: Point3D; text: string; fontsize: real) := BillboardText(P.x,p.y,p.z,text,fontsize);
function BillboardText(p: Point3D; text: string) := BillboardText(P.x,p.y,p.z,text,12);
function BillboardText(x,y,z: real; text: string) := BillboardText(x,y,z,text,12);

function CoordinateSystem(arrowslength,diameter: real): CoordinateSystemT 
  := Invoke&<CoordinateSystemT>(()->CoordinateSystemT.Create(0,0,0,arrowslength,diameter));
function CoordinateSystem(arrowslength: real) := CoordinateSystem(arrowslength,arrowslength/10);

function Text3D(x,y,z: real; text: string; height: real; fontname: string; c: Color): TextT := Invoke&<TextT>(()->TextT.Create(x,y,z,text,height,fontname,c));
function Text3D(p: Point3D; text: string; height: real; fontname: string; c: Color) := Text3D(P.x,p.y,p.z,text,height,fontname,c);
function Text3D(x,y,z: real; text: string; height: real; c: Color) := Text3D(x,y,z,text,height,'Arial',c);
function Text3D(p: Point3D; text: string; height: real; c: Color) := Text3D(p.x,p.y,p.z,text,height,'Arial',c);
function Text3D(x,y,z: real; text: string; height: real) := Text3D(x,y,z,text,height,'Arial',Colors.Black);
function Text3D(p: Point3D; text: string; height: real) := Text3D(p.x,p.y,p.z,text,height,'Arial',Colors.Black);

function Rectangle3D(x,y,z,l,w: real; normal,lendirection: Vector3D; c: GColor): RectangleT 
  := Invoke&<RectangleT>(()->RectangleT.Create(x,y,z,l,w,normal,lendirection,c));
function Rectangle3D(p: Point3D; l,w: real; normal,lendirection: Vector3D; c: GColor) 
  := Rectangle3D(p.x,p.y,p.z,l,w,normal,lendirection,c);
function Rectangle3D(x,y,z,l,w: real; normal: Vector3D; c: GColor)
  := Rectangle3D(x,y,z,l,w,normal,v3d(1,0,0),c); 
function Rectangle3D(x,y,z,l,w: real; c: GColor)
  := Rectangle3D(x,y,z,l,w,v3d(0,0,1),v3d(1,0,0),c); 
function Rectangle3D(p: Point3D; l,w: real; normal: Vector3D; c: GColor)
  := Rectangle3D(p.x,p.y,p.z,l,w,normal,v3d(1,0,0),c); 
function Rectangle3D(p: Point3D; l,w: real; c: GColor)
  := Rectangle3D(p.x,p.y,p.z,l,w,v3d(0,0,1),v3d(1,0,0),c); 

/// ��������� ������ �� ����� .obj, .3ds, .lwo, .objz, .stl, .off
function FileModel3D(x,y,z: real; fname: string): FileModelT 
  := Invoke&<FileModelT>(()->FileModelT.Create(x,y,z,fname));
function FileModel3D(p: Point3D; fname: string) :=  FileModel3D(p.x,p.y,p.z,fname);


function Any(x,y,z: real; c: Color): AnyT := Invoke&<AnyT>(()->AnyT.Create(x,y,z,c));

procedure WindowTypeSetLeftP(l: real) := MainWindow.Left := l;
procedure WindowType.SetLeft(l: real) := Invoke(WindowTypeSetLeftP,l);

function WindowTypeGetLeftP := MainWindow.Left;
function WindowType.GetLeft := Invoke&<real>(WindowTypeGetLeftP);

procedure WindowTypeSetTopP(t: real) := MainWindow.Top := t;
procedure WindowType.SetTop(t: real) := Invoke(WindowTypeSetTopP,t);

function WindowTypeGetTopP := MainWindow.Top;
function WindowType.GetTop := Invoke&<real>(WindowTypeGetTopP);

procedure WindowTypeSetWidthP(w: real) := MainWindow.Width := w + wplus;
procedure WindowType.SetWidth(w: real) := Invoke(WindowTypeSetWidthP,w);

function WindowTypeGetWidthP := MainWindow.Width - wplus;
function WindowType.GetWidth := Invoke&<real>(WindowTypeGetWidthP);

procedure WindowTypeSetHeightP(h: real) := MainWindow.Height := h + hplus;
procedure WindowType.SetHeight(h: real) := Invoke(WindowTypeSetHeightP,h);

function WindowTypeGetHeightP := MainWindow.Height - hplus;
function WindowType.GetHeight := Invoke&<real>(WindowTypeGetHeightP);

procedure WindowTypeSetCaptionP(c: string) := MainWindow.Title := c;
procedure WindowType.SetCaption(c: string) := Invoke(WindowTypeSetCaptionP,c);

function WindowTypeGetCaptionP := MainWindow.Title;
function WindowType.GetCaption := Invoke&<string>(WindowTypeGetCaptionP);

procedure WindowTypeSetSizeP(w, h: real);
begin
  WindowTypeSetWidthP(w);
  WindowTypeSetHeightP(h);
end;
procedure WindowType.SetSize(w, h: real) := Invoke(WindowTypeSetSizeP,w,h);

procedure WindowTypeSetPosP(l, t: real);
begin
  WindowTypeSetLeftP(l);
  WindowTypeSetTopP(t);
end;
procedure WindowType.SetPos(l, t: real) := Invoke(WindowTypeSetPosP,l,t);

procedure WindowType.Close := Invoke(MainWindow.Close);

procedure WindowTypeMinimizeP := MainWindow.WindowState := WindowState.Minimized;
procedure WindowType.Minimize := Invoke(WindowTypeMinimizeP);

procedure WindowTypeMaximizeP := MainWindow.WindowState := WindowState.Maximized;
procedure WindowType.Maximize := Invoke(WindowTypeMaximizeP);

procedure WindowTypeNormalizeP := MainWindow.WindowState := WindowState.Normal;
procedure WindowType.Normalize := Invoke(WindowTypeNormalizeP);

procedure WindowTypeCenterOnScreenP := MainWindow.WindowStartupLocation := WindowStartupLocation.CenterScreen;
procedure WindowType.CenterOnScreen := Invoke(WindowTypeCenterOnScreenP);

function WindowType.Center := new Point(Width/2,Height/2);

function WindowType.ClientRect := Rect(0,0,Window.Width,Window.Height);

var mre := new ManualResetEvent(false);

procedure InitWPF0;
begin
  app := new Application;
  app.Dispatcher.UnhandledException += (o,e) -> Println(e);
  MainWindow := new GWindow;

  Window := new WindowType;
  Camera := new CameraType;

  var g := new Grid;
  MainWindow.Content := g;
  hvp := new HelixViewport3D();
  g.Children.Add(hvp);
  //hvp.ShowTriangleCountInfo := true;;
  //hvp.ShowCameraInfo := True;
  hvp.ZoomExtentsWhenLoaded := True;
  //hvp.Background := Brushes.Black;
  
  hvp.ShowCoordinateSystem := True;
  
  hvp.Children.Add(new DefaultLights);
  
  gvl := new GridLinesVisual3D();

  //gvl.Fill := Brushes.Aqua;
  //gvl.Visible := False;
  gvl.Width := 12; gvl.Length := 12; 
  gvl.MinorDistance := 1;
  gvl.MajorDistance := 1;
  gvl.Thickness := 0.02;
  hvp.Children.Add(gvl);
  
  MainWindow.Title := '3D �������';
  MainWindow.WindowStartupLocation := WindowStartupLocation.CenterScreen;
  MainWindow.Width := 640;
  MainWindow.Height := 480;
  MainWindow.Closed += procedure(sender,e) -> begin Halt; end;
  MainWindow.KeyDown += SystemOnKeyDown;
  MainWindow.KeyUp += SystemOnKeyUp;
  
  View3D := new View3DT;
  
  //hvp.Camera.Position := P3D(12,16,20);

  mre.Set();
  
  app.Run(MainWindow);
end;

initialization
  MainFormThread := new System.Threading.Thread(InitWPF0);
  MainFormThread.SetApartmentState(ApartmentState.STA);
  MainFormThread.Start;
  
  mre.WaitOne; // �������� ��������� �� �������� ���� �� ����� ���������������� ��� ���������� ����������

finalization  
end.