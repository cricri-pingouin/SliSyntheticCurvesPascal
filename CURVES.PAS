{ Development of demonstration package }
{ for curve and surface modelling in CAD }
{ Programming : xxx, 19xx }

Program CURVES_DRAWING;

Uses Crt,Graph,Dos;

Type Vector            = array [1..2]  of real;
     Control_points    = array [0..19] of vector;
     Blending_Function = array [0..19] of real;

Var { *** Common *** }
      Loop,n,k,Curve,Choice,q            : byte;
      minX,maxX,minY,maxY,ScaleX,ScaleY,
      Delta,t,xt,yt                      : real;
      Points                             : control_points;
      Key                                : char;
      Scale,Getting                      : boolean;
    { *** Graphics *** }
      Text_Image                         : pointer;
      ErrCode,Driver,Mode                : integer;
    { *** B-splines *** }
      Weight,D1,D2,Blend_F               : Blending_Function;
      Denominator                        : real;
    { *** Hermite curves *** }
      Begin_Vector,End_Vector,v1,v2      : vector;
    { *** Mouse *** }
      Move,MouseX,MouseY                 : integer;
      Mickey                             : boolean;
      Regs                               : registers;

Type  OnOff = (On,Off);

{ *** Colors for drawing *** }
Const Colours : array [0..19] of byte
      = (LightRed,Yellow,LightCyan,LightMagenta,Red,LightGray,Green,Cyan,LightGreen,White,
         LightRed,Yellow,LightCyan,LightMagenta,Red,LightGray,Green,Cyan,LightGreen,White);

{ ******************** MISCELLANEOUS INTERRUPTS ********************** }

{ Enable or disable text mode cursor }

Procedure CURSOR (Com : OnOff);
Begin
  Regs.Ax:=$0100;
  If Com=Off then
    Begin
      Regs.Cx := $F0F0;
      Intr($10,Regs);
    End;
  If Com=On then
    Begin
      Regs.Cx := $0001;
      Intr($10,Regs);
    End;
End;

{ Empty the keyboard buffer }

Procedure EMPTY_KEYBOARD;
Begin
  Regs.Ax:=$0C00;
  MsDos(Regs);
end;

{ **********************  MOUSE *************************** }

{ Set the cross as new mouse graphic cursor }

Procedure SET_POINTER_CROSS;
Type Cursor = Record
                ScreenMask,CursorMask : array [0..15] of word;
              End;
Const Cross : Cursor =
               ( ScreenMask : ($FFFF,$FFFF,$FFFF,$FFFF,
                               $FFFF,$FFFF,$FFFF,$FFFF,
                               $FFFF,$FFFF,$FFFF,$FFFF,
                               $FFFF,$FFFF,$FFFF,$FFFF);
                 CursorMask : ($0000,$0180,$0180,$0180,
                               $0180,$0180,$0180,$FE7F,
                               $FE7F,$0180,$0180,$0180,
                               $0180,$0180,$0180,$0000));
Begin
  Regs.Ax:=9;
  Regs.Bx:=$0007;
  Regs.Cx:=$0007;
  Regs.Dx:=Ofs(Cross);
  Regs.Es:=Seg(Cross);
  Intr($33,Regs);
End;

{ Detect and initialise mouse }

Function INIT_MOUSE : boolean;
Begin
   Regs.Ax:=$00;
   Intr($33,Regs);
   If Regs.Ax=0 then
      Init_Mouse:=false;
   If Regs.Ax=-1 then
      Init_Mouse:=true;
End;

{ Enable or disable mouse cursor }

Procedure MOUSE_CURSOR (Com : OnOff);
Begin
   If Com=off then
     Begin
       Regs.Ax:=$02;
       Intr($33,Regs);
     End;
   If Com=on then
     Begin
       Regs.Ax := $01;
       Intr($33,Regs);
     End;
End;

{ Test if the mouse has been moved }

Function READ_MOVE : integer;
Begin
  Regs.Ax:=$0B;
  Intr($33,Regs);
  Read_Move:=Regs.Cx+Regs.Dx;
End;

{ Get the current mouse X coordinate }

Function GET_MOUSE_X : integer;
Begin
  Regs.Ax:=$03;
  Intr($33,regs);
  Get_Mouse_X:=Regs.Cx;
End;

{ Get the current mouse Y coordinate }

Function GET_MOUSE_Y : integer;
Begin
  Regs.Ax:=$03;
  Intr($33,Regs);
  Get_Mouse_Y:=regs.dx;
End;

{ Set the mouse to X and Y coordinates }

Procedure SET_MOUSE (x,y : integer);
Begin
  Regs.Ax:=$04;
  Regs.Dx:=y;
  Regs.Cx:=x;
  Intr($33,Regs);
End;

{ Test the buttons }

Function BUTTON : integer;
Begin
  Regs.Ax:=$03;
  Intr($33,Regs);
  Button:=Regs.Bx;
End;

{ Return mouse real X coordinate }

Function GRAPH_POINT_X : real;
Begin
  Graph_point_X:=(Get_Mouse_X-20)/ScaleX+minX;
End;

{ Return mouse real Y coordinate }

Function GRAPH_POINT_Y : real;
Begin
  Graph_point_Y:=(460-Get_Mouse_Y)/ScaleY+minY;
End;

{ Return a real X coordinate in graphic X coordinate }

Function REAL_POINT_X (Reel : real) : integer;
Begin
  Real_Point_X:=Round(20+(reel-minX)*ScaleX);
End;

{ Return a real Y coordinate in graphic Y coordinate }

Function REAL_POINT_Y (Reel : real) : integer;
Begin
  Real_Point_Y:=Round(460-(reel-minY)*ScaleY);
End;

{ Display mouse coordinates }

Procedure MOUSE_COORDINATES;
Var Chaine1,Chaine2 : string;
Begin
  SetColor(LightGreen);
  SetTextStyle(DefaultFont,Horizdir,2);
  Str(Graph_Point_X:8:3,Chaine1);
  Str(Graph_Point_Y:8:3,Chaine2);
  Chaine1:=Concat(' X : ',Chaine1,' ; Y : ',Chaine2);
  PutImage(0,0,Text_Image^,CopyPut);
  OutTextXY(0,0,Chaine1);
End;

{ **********************  CALCULATIONS *************************** }

{ Return factorial n }

Function FACTORIAL (n : integer) : real;
Var Temp : real;
    i    : byte;
Begin
  Temp:=1;
  For i:=1 to n do temp:=temp*i;
  Factorial:=Temp;
End;

{ Return a power n }

Function POWER (a : real; b : integer) : real;
Var Temp : real;
    i    : byte;
Begin
  Temp:=1;
  For i:=1 to b do Temp:=Temp*a;
  Power:=Temp;
End;

{ Return Bernstein polynomial for a Bezier curve }

Function BERNSTEIN (a,b : integer) : real;
Begin
  Bernstein:=Power(1-t,b-a)*Power(t,a)*Factorial(b)/(Factorial(a)*Factorial(b-a));
End;

{ Return Bernstein polynomial first derivative for a Bezier curve }

Function BERNSTEIN_DASH (a,b : integer) : real;
Begin
  Bernstein_Dash:=(a-b*t)/(t-Sqr(t))*Bernstein(a,b);
End;

{ Return Bernstein polynomial second derivative for a Bezier curve }

Function BERNSTEIN_DASH_DASH(a,b : integer) : real;
Begin
  Bernstein_Dash_Dash:=(Sqr(a-b*t)-b*Sqr(t)-a*(1-2*t))/(Sqr(t)*Sqr(1-t))*Bernstein(a,b);
End;

{ Return knot vector for a NURBS }

Function KNOT (c : integer) : integer;
Begin
  If c<k then
    Knot:=0
  else
    If c>n then Knot:=n-k+2
           else Knot:=c-k+1;
End;

{ Return blending function for a NURBS }

Function BLEND (a,b : integer) : real;
Var u : integer;
    v : real;
Begin
  If b=1 then
    Begin
      v:=0;
      If (Knot(a)<=t) and (t<Knot(a+1)) then v:=1;
    End
  else
    Begin
      v:=0;
      u:=Knot(a+b-1)-Knot(a);
      If u<>0 then v:=(t-Knot(a))*Blend(a,b-1)/u;
      u:=Knot(a+b)-Knot(a+1);
      If u<>0 then v:=v+(Knot(a+b)-t)*Blend(a+1,b-1)/u;
    End;
    Blend:=v;
End;

{ Calculate the first and second derivatives for NURBS blending functions }
{ HAVE TO BE CHECKED : PROBLEM IN THERE }

Procedure DERIVATIVES;
Var B1,B2                    : real;
    f1,f2,f3,f4,s1,s2,s3,s4  : real;
    Temp,Temp1,Temp2         : array [1..40] of real;
    x                        : array [1..60] of real;
    Loop1,Loop2              : byte;
Begin
{ Calculate the first order basis functions }
  For Loop1:=1 to n+k do
    If (t>=x[Loop1]) and (t<x[Loop1+1]) then
      Temp[Loop1]:=1
    else
      Temp[Loop1]:=0;
  If t=x[n+2] then
    Begin
      Temp[n+1]:=1;
      Temp[n+2]:=0;
    End;
{ Calculate higher order basis functions and their derivatives }
  For Loop2:=2 to k do
    For Loop1:=1 to n+k+1-Loop2 do
      Begin
{ Calculate basis function }
        If Temp[Loop1]<>0 then
          B1:=((t-x[Loop1])*Temp[Loop1])/(x[Loop1+Loop2-1]-x[Loop1])
        Else
          B1:=0;
        If Temp[Loop1+1]<>0 then
          B2:=((x[Loop1+Loop2]-t)*Temp[Loop1+1])/(x[Loop1+Loop2]-x[loop1+1])
        Else
          B2:=0;
{ Calculate first derivative }
        If Temp[Loop1]<>0 then
          f1:=Temp[Loop1]/(x[Loop1+Loop2-1]-x[Loop1])
        Else
          f1:=0;
        If Temp[Loop1+1]<>0 then
          f2:=-Temp[Loop1+1]/(x[Loop1+Loop2]-x[Loop1+1])
        Else
          f2:=0;
        If Temp1[Loop1]<>0 then
          f3:=(t-x[Loop1])*Temp1[Loop1]/(x[Loop1+Loop2-1]-x[Loop1])
        Else
          f3:=0;
        If Temp1[Loop1+1]<>0 then
          f4:=(x[Loop1+Loop2]-t)*Temp1[Loop1+1]/(x[Loop1+Loop2]-x[Loop1+1])
        Else
          f4:=0;
{ Calculate second derivative }
        If Temp1[Loop1]<>0 then
          s1:=2*Temp1[Loop1]/(x[Loop1+Loop2-1]-x[Loop1])
        Else
          s1:=0;
        If Temp1[Loop1+1]<>0 then
          s2:=-2*Temp1[Loop1+1]/(x[Loop1+Loop2]-x[Loop1+1])
        Else
          s2:=0;
        If Temp2[Loop1]<>0 then
          s3:=(t-x[Loop1])*Temp2[Loop1]/(x[Loop1+Loop2-1]-x[Loop1])
        Else
          s3:=0;
        If Temp2[Loop1+1]<>0 then
          s4:=(x[Loop1+Loop2]-t)*Temp2[Loop1+1]/(x[Loop1+Loop2]-x[Loop1+1])
        Else
          s4:=0;
        Temp[Loop1]:=B1+B2;
        Temp1[Loop1]:=f1+f2+f3+f4;
        Temp2[Loop1]:=s1+s2+s3+s4;
      End;
{ Put in arrays }
  For Loop1:=0 to n do
    Begin
      Blend_F[Loop1]:=Temp[Loop1-1];
      D1[Loop1]:=Temp1[Loop1-1];
      D2[Loop1]:=Temp2[Loop1-1];
    End;
End;

{ **********************  GRAPHICS *************************** }

{ Place the first pixel at specified coordinates and set specified color }

Procedure FIRST_PIXEL (x,y : real; Color : byte);
Begin
  SetColor(Color);
  MoveTo(Real_Point_X(x),Real_Point_Y(y));
End;

{ Draw a line from current position to specified coordinates }

Procedure LINE_TO (x,y : real);
Begin
  LineTo(Real_Point_X(x),Real_Point_Y(y));
End;

{ Display a box at point #a coordinates }

Procedure DISPLAY_POINT (a : byte);
Var px,py  : integer;
    Number : string[2];
Begin
{ Display a box at point's coordinates }
  SetColor(LightBlue);
  px:=Real_Point_X(Points[a,1]);
  py:=Real_Point_Y(Points[a,2]);
  Rectangle(px-3,py-2,px+3,py+2);
{ Display point number }
  Str(a,Number);
  SetTextStyle(DefaultFont,Horizdir,1);
  OutTextXY(px-3,py+5,Number);
  MoveTo(px,py);
End;

{ Draw the control polygon }

Procedure DRAW_POLYGON;
Begin
{ Draw the control polygon }
  First_Pixel(Points[0,1],Points[0,2],LightBlue);
  For Loop:=0 to n do
    Begin
      Line_To(Points[Loop,1],Points[Loop,2]);
      Display_Point(Loop);
    End;
{ Draw tangent vectors for an Hermite curve }
  If Curve=1 then
    Begin
      Points[n+1,1]:=Points[0,1]+v1[1];
      Points[n+1,2]:=Points[0,2]+v1[2];
      Points[n+2,1]:=Points[n,1]+v2[1];
      Points[n+2,2]:=Points[n,2]+v2[2];
      SetColor(Yellow);
      Line(Real_Point_X(Points[0,1]),Real_Point_Y(Points[0,2]),
           Real_Point_X(Points[n+1,1]),Real_Point_Y(Points[n+1,2]));
      Line(Real_Point_X(Points[n,1]),Real_Point_Y(Points[n,2]),
           Real_Point_X(Points[n+2,1]),Real_Point_Y(Points[n+2,2]));
    end;
End;

{ Calculate the X and Y axis scales }

Procedure SCALES;
Begin
  ScaleX:=600/(maxX-minX);
  ScaleY:=440/(maxY-minY);
{ If user choose dependant scales for X and Y axis, update the values }
  If Scale then
    If ScaleX<ScaleY then
      Begin
        minY:=minY-(maxX-minX)*(1-ScaleX/ScaleY)/2;
        ScaleY:=ScaleX;
      End
    else
      Begin
        minX:=minX-(maxY-minY)*(1-ScaleY/ScaleX)/2;
        ScaleX:=ScaleY;
      End;
End;

{ Initialise screen X and Y corners coordinates }

Procedure MIN_MAX;
Var B1,B2,B3,B4 : real;
Begin
{ Calculate minimum and maximum points }
  minX:=Points[0,1];
  maxX:=Points[0,1];
  minY:=Points[0,2];
  maxY:=Points[0,2];
{ Include vectors for a Hermite curve }
  If Curve=1 then
    Begin
       Points[n+1,1]:=Points[0,1]+v1[1];
       Points[n+1,2]:=Points[0,2]+v1[2];
       Points[n+2,1]:=Points[n,1]+v2[1];
       Points[n+2,2]:=Points[n,2]+v2[2];
    End;
  For Loop:=1 to q do
    Begin
      If Points[Loop,1]<minX then minX:=Points[Loop,1];
      If Points[Loop,1]>maxX then maxX:=Points[Loop,1];
      If Points[Loop,2]<minY then minY:=Points[Loop,2];
      If Points[Loop,2]>maxY then maxY:=Points[Loop,2];
    End;
{ Hermite curve can be out of control polygon }
{ Seek these points by emulating the drawing }
  If Curve=1 then
    Begin
      Begin_Vector:=v1;
      For Loop:=0 to n-1 do
        Begin
          If (Loop<>n-1) then
            Begin
              End_Vector[1]:=3/4*(Points[Loop+2,1]-Points[Loop,1]);
              End_Vector[2]:=3/4*(Points[Loop+2,2]-Points[Loop,2]);
              If (Loop=0) then
                Begin
                  End_Vector[1]:=End_Vector[1]-v1[1]/4;
                  End_Vector[2]:=End_Vector[2]-v1[2]/4;
                End;
              If (Loop=n-2) then
                Begin
                  End_Vector[1]:=End_Vector[1]-v2[1]/4;
                  End_Vector[2]:=End_Vector[2]-v2[2]/4;
                End;
            End
          Else
            End_Vector:=v2;
          t:=0;
          Repeat
            t:=t+Delta;
            B1:=1-3*t*t+2*t*t*t;
            B2:=3*t*t-2*t*t*t;
            B3:=t-2*t*t+t*t*t;
            B4:=-t*t+t*t*t;
            xt:=B1*Points[Loop,1]+B2*points[Loop+1,1]+B3*Begin_Vector[1]+B4*End_Vector[1];
            yt:=B1*Points[Loop,2]+B2*points[Loop+1,2]+B3*Begin_Vector[2]+B4*End_Vector[2];
            If xt<minX then minX:=xt;
            If xt>maxX then maxX:=xt;
            If yt<minY then minY:=yt;
            If yt>maxY then maxY:=yt;
          Until t>=1;
          Begin_Vector:=End_Vector;
        End;
    End;
  Scales;
End;

{ **********************  GET DATA *************************** }

{ Get an integer at position (posX,posY). Assume "Default" as default value }

Function GET_INTEGER (posX,posY : byte; Default : integer) : integer;
Var Chaine : string;  { Temporary string }
    Long   : integer; { Lenght of string }
    Entier : integer;
Begin
{ Initialise }
  Long:=0;
  Chaine:='';
  TextBackGround(Black);
  GotoXY(posX,posY);
  Write('        ');
  Empty_Keyboard;
{ Get string }
  Repeat
    If KeyPressed then Key:=ReadKey
                  else Key:=#0;
    If ((Key in ['0'..'9']) or ((Long=0) and (Key='-'))) then
      Begin
        GotoXY(posX+Long,posY);
        Write(Key);
        Chaine:=Chaine+Key;
        Inc(Long);
      End;
    If ((Key=#8) and (Long>0)) then
      Begin
        Delete(Chaine,Long,1);
        Dec(long);
        GotoXY(posX+Long,posY);
        Write(#0);
      End;
  Until Key=#13;
{ Return integer or default value if null entry }
  If Chaine<>'' then Val(Chaine,Entier,ErrCode)
                else Entier:=Default;
  Get_Integer:=Entier;
  TextBackGround(Blue);
  GotoXY(PosX,PosY);
End;

{ Get a real at position (posX,posY). Assume "Default" as default value }

Function GET_REAL (posX,posY : byte; Default : real) : real;
Var Chaine : string;  { Temporary string }
    Long   : integer; { Lenght of string }
    Point  : boolean; { Point flag }
    Reel   : real;
Begin
{ Initialise }
  Long:=0;
  Chaine:='';
  Point:=false;
  TextBackGround(Black);
  GotoXY(posX,posY);
  Write('        ');
  Empty_Keyboard;
{ Get string }
  Repeat
    If KeyPressed then Key:=ReadKey
                  else Key:=#0;
    If ((Key in ['0'..'9']) or ((Long=0) and (Key='-'))) then
      Begin
        GotoXY(posX+Long,posY);
        Write(Key);
        Chaine:=Chaine+Key;
        Inc(Long);
      End;
    If ((Key='.') and not Point) then
      Begin
        GotoXY(posX+Long,posY);
        Write('.');
        Chaine:=Chaine+'.';
        Inc(Long);
        Point:=true;
      End;
    If ((Key=#8) and (Long>0)) then
      Begin
        Delete(Chaine,Long,1);
        Dec(long);
        GotoXY(posX+Long,posY);
        Write(#0);
        If pos('.',Chaine)=0 then Point:=false;
      End;
  Until Key=#13;
{ Return real or default if null entry }
  If Chaine<>'' then Val(Chaine,Reel,ErrCode)
                else Reel:=Default;
  Get_Real:=Reel;
  TextBackGround(Blue);
  GotoXY(PosX,PosY);
End;

{ Get coordinates for point #j }

Procedure GET_COORDINATES (j : integer);
Begin
  Clrscr;
  GotoXY(5,5);
  Write('Enter the X value for point #',j:2,' (0) : ');
  Points[j,1]:=Get_Real(43,5,0);
  Write(Points[j,1]:8:3);
  GotoXY(5,7);
  Write('Enter the Y value for point #',j:2,' (0) : ');
  Points[j,2]:=Get_Real(43,7,0);
  Write(Points[j,2]:8:3);
end;

{ Get data for a non uniform rational B-spline }

Procedure GET_DATA_B_SPLINE;
Begin
{ Get weighting factors }
  For Loop:=0 to n do
    Begin
      GotoXY(5,9);
      Write('Enter the weighting factor for point #',Loop:2,' (1) : ');
      Weight[Loop]:=Get_Real(52,9,1);
      ClrScr;
    End;
{ Get curve's order }
  GotoXY(5,10);
  Write('Enter the k parameter value (',n+1:2,') : ');
  Repeat
    k:=Get_Integer(40,10,n+1);
  Until (k>=2) and (k<=n+1);
End;

{ Get data for an Hermite curve }

Procedure GET_DATA_HERMITE;
Begin
{ Get begin tangent vector }
  GotoXY(5,5);
  Write('Enter the X value for tangent vector at point # 0 (0) : ');
  v1[1]:=Get_Real(61,5,0);
  Write(v1[1]:8:3);
  GotoXY(5,7);
  Write('Enter the Y value for tangent vector at point # 0 (0) : ');
  v1[2]:=Get_Real(61,7,0);
  Write(v1[2]:8:3);
{ Get end tangent vector }
  GotoXY(5,9);
  Write('Enter the X value for tangent vector at point #',n:2,' (0) : ');
  v2[1]:=Get_Real(61,9,0);
  Write(v2[1]:8:3);
  GotoXY(5,11);
  Write('Enter the Y value for tangent vector at point #',n:2,' (0) : ');
  v2[2]:=Get_Real(61,11,0);
End;

{ Get data for current style of curve }

Procedure GET_DATA;
Begin
{ *** Keyboard mode *** }
  If not Getting then
    Begin
      ClrScr;
      GotoXY(5,10);
{ Get number of vertices }
      Write('Enter the number of points of the polygon ');
      If Curve=1 then Write('(2..18) (2) : ')
                 else Write('(3..20) (3) : ');
      Repeat
        If Curve=1 then n:=Get_Integer(61,10,2)
                   else n:=Get_Integer(61,10,3);
      Until ((n in [2..18]) and (Curve=1)) or (n in [3..20]);
      Dec(n);
{ Get coordinates }
      For Loop:=0 to n do
        Begin
          Get_Coordinates(Loop);
{ Get weighting factor if NURBS }
          If Curve=3 then
          Begin
            GotoXY(5,9);
            Write('Enter the weighting factor for point #',Loop:2,' (1) : ');
            Weight[Loop]:=Get_Real(52,9,1);
            If Loop=n then
              Begin
                ClrScr;
                GotoXY(5,10);
                Write('Enter the k parameter value (',n+1:2,') : ');
                Repeat
                  k:=Get_Integer(40,10,n+1);
                Until (k>=2) and (k<=n+1);
              End;
          End;
        End;
    End
{ *** Graphical mode *** }
    else
      Begin
{ Get screen size for points catching }
        ClrScr;
        GotoXY(5,5);
        Write('Enter the minimum X value for graphical window    (0) : ');
        minX:=Get_Real(61,5,0);
        Write(minX:8:3);
        GotoXY(5,7);
        Write('Enter the minimum Y value for graphical window    (0) : ');
        minY:=Get_Real(61,7,0);
        Write(minY:8:3);
        GotoXY(5,9);
        Write('Enter the maximum X value for graphical window (1000) : ');
        maxX:=Get_Real(61,9,1000);
        Write(maxX:8:3);
        GotoXY(5,11);
        Write('Enter the maximum Y value for graphical window (1000) : ');
        maxY:=Get_Real(61,11,1000);
        ScaleX:=600/(maxX-minX);
        ScaleY:=440/(maxY-minY);
{ Prepare screen and mouse }
        InitGraph(Driver,Mode,'');
        Mickey:=Init_Mouse;
        Set_Pointer_Cross;
        Mouse_Cursor(On);
        Set_Mouse(320,200);
        n:=0;
        Empty_Keyboard;
        Repeat
          Move:=Read_Move;
{ Display coordinates if mouse move }
          If Move<>0 then Mouse_Coordinates;
{ If left button pressed }
          If Button=1 then
            Begin
{ Save coordinates as point }
              Points[n,1]:=Graph_Point_X;
              Points[n,2]:=Graph_Point_Y;
{ Display point and polygon line }
              Mouse_Cursor(off);
              If n<>0 then
                Begin
                  First_Pixel(Points[n-1,1],Points[n-1,2],LightBlue);
                  Line_To(Points[n,1],Points[n,2]);
                End;
              Display_Point(n);
              inc(n);
              Repeat until Button=0;
              Mouse_Cursor(on);
            End;
        Until ((KeyPressed)or(Button=2)or((Curve=1)and(n=18))or(n=20)) and (((Curve=1)and(n>=2))or(n>=3));
        Dec(n);
{ Last point : return to text mode }
        Repeat until Button=0;
        ClearViewPort;
        TextMode(Co80);
        TextBackGround(Blue);
        TextColor(Yellow);
    End;
{ *** Get more data if needed **** }
  ClrScr;
  Cursor(off);
  Case Curve of 1 : Get_Data_Hermite;
                3 : If Getting then Get_Data_B_Spline;
  end;
{ Create two more points for Hermite curve }
{ These are end points for begin and end tangent vectors }
  If Curve=1 then q:=n+2
             else q:=n;
End;

{ Ask for value of delta (increment value) }

Procedure GET_DELTA;
Begin
  ClrScr;
  GotoXY(10,10);
  Writeln('Enter the value of the increment (this value define');
  Write('         graphic accuracy) (0.005..0.1) (0.01) : ');
  Delta:=Get_Real(50,11,0.01);
{ Filter the value. Don't accept to small or to large values }
  If (Delta<0.005) or (Delta>0.1) then Delta:=0.01;
End;

{ **********************  MODIFICATIONS MENU *************************** }

{ End menu. User can modify data }

Procedure MODIF_MENU;
Begin
{ Prepare the screen }
  TextMode(Co80);
  TextBackGround(Blue);
  TextColor(LightRed);
  ClrScr;
  Cursor(off);
{ *** Display informations *** }
{ Basics }
  GotoXY(1,2);
  Write('You are now working on a ');
  Case Curve of 1 : Write('piecewise cubic Hermite curve');
                2 : Write('Bezier curve');
                3 : Write('non uniform rational B-spline');
  End;
  Writeln(' defined by ',n+1,' vertices.');
  TextColor(Yellow);
  Write('Increment value : ',delta:8:3);
{ Order for a NURBS }
  If Curve=3 then writeln(' ; Order : ',k:2) else writeln;
  GotoXY(65,3);
  If Scale then write('X,Y dependant') else write('X,Y independant');
  GotoXY(1,5);
{ Control Points }
  For Loop:=0 to n do
    Begin
      Write('Point #',Loop:2,'  X value : ',points[Loop,1]:8:3,' ; Y value : ',points[Loop,2]:8:3);
{ Weighting factors for a NURBS }
      If Curve=3 then Writeln(' ; Weighting factor : ',Weight[Loop]:7:3) else writeln;
    End;
{ Tangent vectors for an Hermite curve }
  If Curve=1 then
    Begin
      Writeln('Begining tangent vector  X value : ',v1[1]:8:3,' ; Y value : ',v1[2]:8:3);
      Writeln('Ending tangent vector    X value : ',v2[1]:8:3,' ; Y value : ',v2[2]:8:3);
    End;
{ Miscellaneous }
  TextBackGround(Green);
  TextColor(Magenta);
  GotoXY(1,1);
  Write('To modify a parameter, click on it and enter a new value. Commands on last line.');
  GotoXY(1,25);
  Write('          reDraw         resTart all         Screen saver         Quit         ');
  TextColor(White);
  GotoXY(13,25);
  Write('D');
  GotoXY(29,25);
  Write('T');
  GotoXY(46,25);
  Write('S');
  GotoXY(67,25);
  Write('Q');
  TextColor(Yellow);
  TextBackGround(Blue);
  Mickey:=Init_Mouse;
  Mouse_Cursor(on);
  Set_Mouse(320,100);
End;

{ **********************  SCREEN SAVER *************************** }

{ "Stars" screen saver }

Procedure SCREEN_SAVER;
Var  Speed : byte;
     Fin   : boolean;
     Put_X : array[1..80] of integer;
     Put_Y : array[1..80] of integer;
     Color : array[1..80] of byte;
Begin
{ Miscellaneous }
  InitGraph(Driver,Mode,'');
  Speed:=1;
  Fin:=false;
  Key:=#0;
  Randomize;
  Repeat Until Button=0;
{ Initialise stars }
  For Loop:=1 to 80 do
    begin
         Put_x[Loop]:=random(639);
         Put_y[Loop]:=random(479);
         Color[Loop]:=Colours[random(10)];
         PutPixel(Put_X[Loop],Put_Y[Loop],Color[Loop]);
    end;
{ The GREAT ! screen saver }
  Empty_Keyboard;
  Repeat
    If KeyPressed then
      Begin
        Key:=UpCase(Readkey);
        Case Key of
          '+' : If Speed<30 then Inc(Speed);
          '-' : If Speed>1  then Dec(Speed);
          #27 : Fin:=true;
        End;
      End;
    Empty_Keyboard;
    If (Button<>0) then Fin:=true;
    For Loop:=1 to 80 do
      Begin
        Putpixel(Put_X[Loop],Put_Y[Loop],Black);
        If Put_x[Loop]>320 then
            Inc(Put_X[Loop],abs((320-Put_X[Loop]) div (40-Speed))+1)
          else
            Dec(Put_X[Loop],abs((320-Put_X[Loop]) div (40-Speed))+1);
        If Put_Y[Loop]>240 then
            Inc(Put_Y[Loop],abs((240-Put_Y[Loop]) div (40-Speed))+1)
          else
            Dec(Put_Y[Loop],abs((240-Put_Y[Loop]) div (40-Speed))+1);
        If (Put_X[Loop]<=0) or (Put_X[Loop]>=639) or (Put_Y[Loop]<=0) or (Put_Y[Loop]>=439) then
          Begin
            Put_X[Loop]:=200+random(220);
            Put_Y[Loop]:=150+random(165);
          End;
        PutPixel(Put_X[Loop],Put_Y[Loop],Color[Loop]);
        Delay(1);
      End;
    Key:=#0;
  Until Fin;
  Empty_Keyboard;
  Repeat until Button=0;
  Modif_Menu;
end;

{ **********************  DRAW CURVES *************************** }

{ Calculate and draw a Bezier curve of degree n }

Procedure BEZIER_CURVE;
Var Ber : real;
Begin
{ First point on the curve = first vertice }
  First_Pixel(Points[0,1],Points[0,2],LightRed);
  t:=0;
  Repeat
    t:=t+Delta;
    If (1-t<Delta) then t:=1;
    xt:=0;
    yt:=0;
    For Loop:=0 to n do
      Begin
{ Calculate blending function }
        Ber:=Bernstein(Loop,n);
{ Calculate point }
        xt:=xt+Points[Loop,1]*Ber;
        yt:=yt+Points[Loop,2]*Ber;
      End;
{ Display a line from old point to new one }
    Line_To(xt,yt);
  Until t>=1; { 0<=t<=1 for a Bezier curve }
End;

{ Calculate and draw the radius of curvature for a Bezier curve }

Procedure BEZIER_CURVATURE;
Var Center,Dash,Dash_Dash : vector;
    Reel,Teta             : real;
Begin
  t:=0;
  Repeat
{ Calculate next point }
    t:=t+Delta;
    If (1-t<Delta) then t:=0.999;
    xt:=0;
    yt:=0;
    Dash[1]:=0;
    Dash[2]:=0;
    Dash_Dash[1]:=0;
    Dash_Dash[2]:=0;
    For Loop:=0 to n do
      Begin
{ Calculate P(t) }
        Reel:=Bernstein(Loop,n);
        xt:=xt+Points[Loop,1]*Reel;
        yt:=yt+Points[Loop,2]*Reel;
{ Calculate P'(t) }
        Reel:=Bernstein_Dash(Loop,n);
        Dash[1]:=Dash[1]+Reel*Points[Loop,1];
        Dash[2]:=Dash[2]+Reel*Points[Loop,2];
{ Calculate P''(t) }
        Reel:=Bernstein_Dash_Dash(Loop,n);
        Dash_Dash[1]:=Dash_Dash[1]+Reel*Points[Loop,1];
        Dash_Dash[2]:=Dash_Dash[2]+Reel*Points[Loop,2];
      End;
{ Calculate radius of curvature = 1/curvature }
    Reel:=(Sqr(Dash[1])+Sqr(Dash[2]))*Sqrt(Sqr(Dash[1])+Sqr(Dash[2]))
          /(Dash[1]*Dash_Dash[2]-Dash[2]*Dash_Dash[1]);
{ Calculate angle between X axis and normal vector }
    Teta:=Arctan(-Dash[1]/Dash[2]);
    If Dash[2]>0 then Teta:=Teta+3.1415927;
{ Calculate coordinates of center of curvature }
    Center[1]:=xt+Reel*Cos(Teta);
    Center[2]:=yt+Reel*Sin(Teta);
    SetColor(Green);
    Line(Real_Point_X(xt),Real_Point_Y(yt),Real_Point_X(Center[1]),Real_Point_Y(Center[2]));
    SetColor(Yellow);
    Rectangle(Real_Point_X(Center[1])-1,Real_Point_Y(Center[2])-1,Real_Point_X(Center[1])+1,Real_Point_Y(Center[2])+1);
  Until t>=0.999;
End;

{ Calculate and draw a NURBS of degree k-1 }

Procedure B_SPLINE;
Var Blending : real;
Begin
{ First point on the curve = first vertice }
  First_Pixel(Points[0,1],Points[0,2],LightRed);
  t:=0;
  Repeat
    t:=t+Delta;
    SetColor(Colours[trunc(t)]);
    If (n-k+2-t<Delta) then t:=n-k+2-0.001;
    xt:=0;
    yt:=0;
    Denominator:=0;
    For Loop:=0 to n do
      Begin
{ Calculate blending function }
        Blending:=Blend(Loop,k);
{ Calculate point }
        xt:=xt+Weight[Loop]*Points[Loop,1]*Blending;
        yt:=yt+Weight[Loop]*Points[Loop,2]*Blending;
        Denominator:=Denominator+Weight[Loop]*Blend(Loop,k);
      End;
    xt:=xt/Denominator;
    yt:=yt/Denominator;
{ Display a line from old point to new one }
    Line_To(xt,yt);
  Until t>=n-k+2-0.001; { 0<=t<=n-k+2 for a NURBS }
End;

{ Calculate and draw the radius of curvature for a NURBS }

Procedure B_SPLINE_CURVATURE;
Var Center,Dash,Dash_Dash : vector;
    Reel,Teta             : real;
Begin
  t:=0.001;
  Repeat
{ Calculate next point }
    t:=t+Delta;
    If (n-k+2-t<Delta) then t:=n-k+2-0.001;
    xt:=0;
    yt:=0;
    Dash[1]:=0;
    Dash[2]:=0;
    Dash_Dash[1]:=0;
    Dash_Dash[2]:=0;
    Denominator:=0;
    Derivatives;
    For Loop:=0 to n do
      Begin
{ Calculate P(t) }
        xt:=xt+Blend_F[Loop]*Points[Loop,1];
        yt:=yt+Blend_F[Loop]*Points[Loop,2];
{ Calculate P'(t) }
        Dash[1]:=Dash[1]+D1[Loop]*Points[Loop,1];
        Dash[2]:=Dash[2]+D1[Loop]*Points[Loop,2];
{ Calculate P''(t) }
        Dash_Dash[1]:=Dash_Dash[1]+D2[Loop]*Points[Loop,1];
        Dash_Dash[2]:=Dash_Dash[2]+D2[Loop]*Points[Loop,2];
      End;
{ Calculate radius of curvature = 1/curvature }
    Reel:=(Sqr(Dash[1])+Sqr(Dash[2]))*Sqrt(Sqr(Dash[1])+Sqr(Dash[2]))
          /(Dash[1]*Dash_Dash[2]-Dash[2]*Dash_Dash[1]);
{ Calculate angle between X axis and normal vector }
    Teta:=Arctan(-Dash[1]/Dash[2]);
    If Dash[2]>0 then Teta:=Teta+3.1415927;
{ Calculate coordinates of center of curvature }
    Center[1]:=xt+Reel*Cos(Teta);
    Center[2]:=yt+Reel*Sin(Teta);
    SetColor(Colours[Random(9)+1]);
    Line(Real_Point_X(xt),Real_Point_Y(yt),Real_Point_X(Center[1]),Real_Point_Y(Center[2]));
    SetColor(Yellow);
    Rectangle(Real_Point_X(Center[1])-1,Real_Point_Y(Center[2])-1,Real_Point_X(Center[1])+1,Real_Point_Y(Center[2])+1);
  Until t>=n-k+2-0.001; { 0<=t<=n-k+2 for a NURBS }
End;

{ Calculate and draw a cubic Hermite curve }

Procedure PIECEWISE_HERMITE_CURVE;
Var B1,B2,B3,B4 : real;
Begin
{ First point on the curve = first vertice }
  First_Pixel(Points[Loop,1],Points[Loop,2],LightRed);
  t:=0;
  Repeat
    t:=t+Delta;
    If (1-t<Delta) then t:=1;
{ Blending functions }
    B1:=1-3*Sqr(t)+2*Sqr(t)*t;
    B2:=3*Sqr(t)-2*Sqr(t)*t;
    B3:=t-2*Sqr(t)+Sqr(t)*t;
    B4:=-Sqr(t)+Sqr(t)*t;
{ Calculate point }
    xt:=B1*Points[Loop,1]+B2*Points[Loop+1,1]+B3*Begin_Vector[1]+B4*End_Vector[1];
    yt:=B1*Points[Loop,2]+B2*Points[Loop+1,2]+B3*Begin_Vector[2]+B4*End_Vector[2];
{ Display a line from old point to new one }
    Line_To(xt,yt);
  Until t>=1; { 0<=t<=1 for a cubic Hermite curve }
End;

{ Calculate and draw an piecewise cubic Hermite curve }
{ The curve will interpolate the data points }

Procedure HERMITE_CURVE;
Begin
  Begin_Vector:=v1;
  For Loop:=0 to n-1 do
    Begin
{ Calculate end tangent vector }
      If (Loop<>n-1) then
        Begin
          End_Vector[1]:=3/4*(Points[Loop+2,1]-Points[Loop,1]);
          End_Vector[2]:=3/4*(Points[Loop+2,2]-Points[Loop,2]);
          If (Loop=0) then
            Begin
              End_Vector[1]:=End_Vector[1]-v1[1]/4;
              End_Vector[2]:=End_Vector[2]-v1[2]/4;
            End;
          If (Loop=n-2) then
            Begin
              End_Vector[1]:=End_Vector[1]-v2[1]/4;
              End_Vector[2]:=End_Vector[2]-v2[2]/4;
            End;
        End
      Else
        End_Vector:=v2;
{ Draw a cubic curve }
      Piecewise_Hermite_curve;
{ Tangency continuity between succesive segments }
      Begin_Vector:=End_Vector;
    End;
End;

{ Calculate and draw the radius of curvature for a piecewise Hermite curve }

Procedure HERMITE_CURVATURE;
Var Center,Dash,Dash_Dash : vector;
    B1,B2,B3,B4           : real;
    Radius,Teta           : real;
Begin
  Begin_Vector:=v1;
  For Loop:=0 to n-1 do
    Begin
{ Calculate end tangent vector }
      If (Loop<>n-1) then
        Begin
          End_Vector[1]:=3/4*(Points[Loop+2,1]-Points[Loop,1]);
          End_Vector[2]:=3/4*(Points[Loop+2,2]-Points[Loop,2]);
          If (Loop=0) then
            Begin
              End_Vector[1]:=End_Vector[1]-v1[1]/4;
              End_Vector[2]:=End_Vector[2]-v1[2]/4;
            End;
          If (Loop=n-2) then
            Begin
              End_Vector[1]:=End_Vector[1]-v2[1]/4;
              End_Vector[2]:=End_Vector[2]-v2[2]/4;
            End;
        End
      Else
        End_Vector:=v2;
      t:=0;
      Repeat
        t:=t+n*Delta;
        If (1-t<Delta) then t:=0.999;
{ Calcuate P(t) }
        B1:=1-3*Sqr(t)+2*Sqr(t)*t;
        B2:=3*Sqr(t)-2*Sqr(t)*t;
        B3:=t-2*Sqr(t)+Sqr(t)*t;
        B4:=-Sqr(t)+Sqr(t)*t;
        xt:=B1*Points[Loop,1]+B2*Points[Loop+1,1]+B3*Begin_Vector[1]+B4*End_Vector[1];
        yt:=B1*Points[Loop,2]+B2*Points[Loop+1,2]+B3*Begin_Vector[2]+B4*End_Vector[2];
{ Calculate P'(t) }
        B1:=6*Sqr(t)-6*t;
        B2:=-6*Sqr(t)+6*t;
        B3:=3*Sqr(t)-4*t+1;
        B4:=3*Sqr(t)-2*t;
        Dash[1]:=B1*Points[Loop,1]+B2*Points[Loop+1,1]+B3*Begin_Vector[1]+B4*End_Vector[1];
        Dash[2]:=B1*Points[Loop,2]+B2*Points[Loop+1,2]+B3*Begin_Vector[2]+B4*End_Vector[2];
{ Calculate P''(t) }
        B1:=12*t-6;
        B2:=-12*t+6;
        B3:=6*t-4;
        B4:=6*t-2;
        Dash_Dash[1]:=B1*Points[Loop,1]+B2*Points[Loop+1,1]+B3*Begin_Vector[1]+B4*End_Vector[1];
        Dash_Dash[2]:=B1*Points[Loop,2]+B2*Points[Loop+1,2]+B3*Begin_Vector[2]+B4*End_Vector[2];
{ Calculate radius of curvature = 1/curvature }
        Radius:=(Sqr(Dash[1])+Sqr(Dash[2]))*Sqrt(Sqr(Dash[1])+Sqr(Dash[2]))
               /(Dash[1]*Dash_Dash[2]-Dash[2]*Dash_Dash[1]);
{ Calculate angle between X axis and normal vector }
        Teta:=Arctan(-Dash[1]/Dash[2]);
        If Dash[2]>0 then Teta:=Teta+3.1415927;
{ Calculate coordinates of center of curvature }
        Center[1]:=xt+Radius*Cos(Teta);
        Center[2]:=yt+Radius*Sin(Teta);
        SetColor(Colours[Loop+1]);
        Line(Real_Point_X(xt),Real_Point_Y(yt),Real_Point_X(Center[1]),Real_Point_Y(Center[2]));
        SetColor(Yellow);
        Rectangle(Real_Point_X(Center[1])-1,Real_Point_Y(Center[2])-1,Real_Point_X(Center[1])+1,Real_Point_Y(Center[2])+1);
       Until t>=0.999;
      Begin_Vector:=End_Vector;
    End;
End;

{ Plot current curve }

Procedure PLOT_CURVE;
Var Dist,moyX,moyY : real;
Begin
{ Initialise graphic mode }
  Clrscr;
  InitGraph(Driver,Mode,'');
{ Initialise screen }
  Min_Max;
  Draw_Polygon;
{ Draw curve }
  Case Curve of
     1 : Hermite_Curve;
     2 : Bezier_Curve;
     3 : B_Spline;
  End;
{ Initialise mouse }
  Mickey:=Init_Mouse;
  Set_Pointer_Cross;
  Mouse_Cursor(on);
  Set_Mouse(320,200);
{ *** Allow to modify curve *** }
  Repeat until Button=0;
  Empty_Keyboard;
  Key:=#0;
  Repeat
{ Display cursor coordinates }
    Move:=Read_Move;
    If Move<>0 then Mouse_Coordinates;
{ Check for 'C' or 'Z' }
    If KeyPressed then Key:=UpCase(ReadKey) else Key:=#0;
{ Draw the center of curvature curve if 'C' key pressed for a Bezier curve }
    If Key='C' then
      Begin
        Mouse_Cursor(Off);
        Case Curve of 1 : Hermite_Curvature;
                      2 : Bezier_Curvature;
                      { 3 : B_Spline_Curvature; DOESN'T WORK }
        End;
        Mouse_Cursor(On);
        Empty_Keyboard;
        Key:=#0;
      End;
{ Zoom routine }
    If (Key='Z') then
      Begin
        Mouse_Cursor(Off);
        SetColor(LightCyan);
        SetTextStyle(DefaultFont,HorizDir,1);
        OutTextXY(0,472,'Zoom box : twice left button ; zoom out factor û2 : once right button');
        Mouse_Cursor(On);
        Repeat until Button=0;
        Repeat
          Move:=Read_Move;
          If Move<>0 then Mouse_Coordinates;
        until (Button=1) or (Button=2);
{ If right button, proceed zoom out, factor sqrt(2) }
        If (Button=2) then
          Begin
            moyX:=(minX+maxX)/2;
            moyY:=(minY+maxY)/2;
            maxX:=moyX+1.414*(maxX-moyX);
            minX:=moyX-1.414*(moyX-minX);
            maxY:=moyY+1.414*(maxY-moyY);
            minY:=moyY-1.414*(moyY-minY);
          End
{ Else, left button, box zoom }
        else
          Begin
{ Left button pressed : get first corner }
{ Put in maxX/Y because minX/Y used for Graph_Point_X/Y }
            maxX:=Graph_Point_X;
            maxY:=Graph_Point_Y;
            Mouse_Cursor(Off);
            SetColor(LightCyan);
            Line(Get_Mouse_X-8,Get_Mouse_Y,Get_Mouse_X+8,Get_mouse_Y);
            Line(Get_Mouse_X,Get_Mouse_Y-8,Get_Mouse_X,Get_mouse_Y+8);
            Repeat until Button=0;
            Mouse_Cursor(On);
            Repeat
              Move:=Read_Move;
              If Move<>0 then Mouse_Coordinates;
            Until Button=1;
{ Release button : get second corner }
            minX:=Graph_Point_X;
            minY:=Graph_Point_Y;
{ Arrange corners }
            If minX>maxX then
              Begin
                moyX:=maxX;
                maxX:=minX;
                minX:=moyX;
              End;
            If minY>maxY then
              Begin
                moyY:=maxY;
                maxY:=minY;
                minY:=moyY;
              End;
          End;
        Scales;
{ Draw the curve with new scale }
        Repeat until Button=0;
        Mouse_Cursor(off);
        ClearViewPort;
        Draw_Polygon;
        Case Curve of
          1 : Hermite_Curve;
          2 : Bezier_Curve;
          3 : B_Spline;
        End;
        Mouse_Cursor(On);
        Empty_Keyboard;
        Key:=#0;
      End;
{ If left button pressed }
    If Button=1 then
      Begin
{ Seek nearest point }
        ErrCode:=0;
        Dist:=Sqr(Points[0,1]-Graph_Point_X)+Sqr(Points[0,2]-Graph_Point_Y);
        For loop:=1 to q do
          Begin
            If (Dist>Sqr(Points[Loop,1]-Graph_Point_X)+Sqr(Points[Loop,2]-Graph_Point_Y))
            then
              Begin
                ErrCode:=Loop;
                Dist:=Sqr(Points[Loop,1]-Graph_Point_X)+Sqr(Points[Loop,2]-Graph_Point_Y);
              End;
          End;
        Repeat
{ Check if mouse moved }
          Move:=Read_Move;
          If Move<>0 then
            Begin
{ Update point's coordinates }
              Points[ErrCode,1]:=Graph_Point_X;
              Points[ErrCode,2]:=Graph_Point_Y;
{ If Hermite curve, update tangent vectors if needed }
              If (Curve=1) and (ErrCode=q-1) then
                Begin
                  v1[1]:=Points[ErrCode,1]-Points[0,1];
                  v1[2]:=Points[ErrCode,2]-Points[0,2];
                End;
              If (Curve=1) and (ErrCode=q) then
                Begin
                  v2[1]:=Points[ErrCode,1]-Points[n,1];
                  v2[2]:=Points[ErrCode,2]-Points[n,2];
                End;
{ Draw the curve with new point }
              Mouse_Cursor(off);
              ClearViewPort;
              Draw_Polygon;
              Case Curve of
                1 : Hermite_Curve;
                2 : Bezier_Curve;
                3 : B_Spline;
              End;
              Mouse_Cursor(On);
{ Display point's coordinates }
              Mouse_Coordinates;
            End;
        Until Button=0;
      End;
  Until (Key<>#0) or (Button=2);
  Repeat until Button=0;
{ Display ending menu to allow mofifications }
  Modif_Menu;
End;

{ ************************  MAIN MENU  ************************** }

Procedure MAIN_MENU;
Begin
{ Prepare main menu screen }
  TextBackGround(Blue);
  ClrScr;
  TextColor(LightRed);
  GotoXY(13,5);
  Writeln('Generator of curves');
  Write('            ___________________');
  TextColor(LightGreen);
  GotoXY(13,17);
  Write('Getting method :');
  GotoXY(13,22);
  Write('Programmed by xxx, 19xx.');
  GotoXY(13,10);
  writeln('Type the number of your curve or click on it : ');
  TextColor(Yellow);
  Writeln;
  Writeln('            1 -> Hermite curve');
  Writeln('            2 -> Bezier curve');
  Writeln('            3 -> NUR B-spline');
  Writeln('            4 -> Quit');
  GotoXY(30,17);
  If Getting then Write('graphical')
             else Write('keyboard');
  Mouse_Cursor(on);
  Set_Mouse(320,100);
  Empty_Keyboard;
  Repeat
    Key:=#0;
    MouseX:=Get_Mouse_X;
    MouseY:=Get_Mouse_Y;
    If KeyPressed then Key:=ReadKey;
{ Change getting mode if required }
    If (key='G') or (key='g') or ((MouseX>=232) and (MouseY<=296) and (MouseY=128) and (button=1)) then
      Begin
        Mouse_Cursor(off);
        If Getting then
          Begin
            Getting:=false;
            GotoXY(30,17);
            Write('keyboard ');
            Repeat until Button=0;
          End
        else
          Begin
            Getting:=true;
            GotoXY(30,17);
            Write('graphical');
            Repeat until Button=0;
          End;
        Mouse_Cursor(on);
      End;
  Until (Key in ['1'..'4'])
     or ((Button<>0) and (MouseX in [96..232]) and (MouseY in [88..112]));
{ Get the type of curve }
  If (Key in ['1'..'4']) then Val(key,curve,ErrCode)
                         else Curve:=round(MouseY/8-10);
  Mouse_Cursor(off);
  If Curve<>4 then
    Begin
{ Get data }
      Get_Data;
      Get_Delta;
{ Plot curve }
      Plot_Curve;
{ End menu }
      Empty_Keyboard;
      Repeat
        Choice:=0;
        GotoXY(1,24);
        MouseX:=Get_Mouse_X;
        MouseY:=Get_Mouse_Y;
        GotoXY(1,24);
        Key:=#0;
{ Check if hot key pressed }
        If KeyPressed then
          Begin
            Key:=UpCase(readkey);
            Case Key of
              'D'     : Plot_Curve;
              'T'     : Choice:=1;
              'S'     : Choice:=2;
              'Q'     : Choice:=3;
{ Mouse emulation with cursor }
              'K','4' : If MouseX>0   then MouseX:=MouseX-8;
              'M','6' : If MouseX<632 then MouseX:=MouseX+8;
              'H','8' : If MouseY>0   then MouseY:=MouseY-8;
              'P','2' : If MouseY<192 then MouseY:=MouseY+8;
            End;
            Set_Mouse(MouseX,MouseY);
          End;
{ If left button or "enter" key pressed }
        If (Button=1) or (Key=#13) then
          Begin
            Mouse_Cursor(off);
            Case MouseY of
              16       : Case MouseX of
                           144..200 : Begin
        { Modify delta }                Delta:=Get_Real(19,3,Delta);
                                        If (Delta>0.1) or (Delta<0.005) then Delta:=0.01;
                                        GotoXY(19,3);
                                        Write(Delta:8:3);
                                      End;
                           296..304 : If Curve=3 then
        { Modify order if NURBS }       Repeat
                                          k:=Get_Integer(38,3,k);
                                          GotoXY(38,3);
                                          Write(k:2,'       ');
                                        Until (k>=2) and (k<=n+1);
                           512..624 : Begin
        { Modify scale type }           If Scale then
                                          Begin
                                            Scale:=false;
                                            GotoXY(65,3);
                                            Write('X,Y independant');
                                          End
                                        else
                                          Begin
                                            Scale:=true;
                                            GotoXY(65,3);
                                            Write('X,Y dependant  ');
                                          End;
                                        Repeat until Button=0;
                                      End;
                         End;
              192      : Case MouseX of
                           80..120  : Plot_Curve; { "Redraw" }
                           200..280 : Choice:=1;  { "Restart all" }
                           360..448 : Choice:=2;  { "Screen saver" }
                           528..552 : Choice:=3;  { "Quit" }
                         End;
            End;
{ Launch screen saver if required }
            If Choice=2 then
              Begin
                Screen_Saver;
                Choice:=0;
              End;
{ Modify control points }
            If (MouseY>=32) and (MouseY<=32+8*n) then
              Case MouseX of
                           168..224 : Begin
            { X coordinate } Points[trunc(MouseY/8)-4,1]:=Get_Real(22,trunc(MouseY/8+1),Points[trunc(MouseY/8)-4,1]);
                                        GotoXY(22,trunc(MouseY/8+1));
                                        Write(points[trunc(MouseY/8-4),1]:8:3);
                                      End;
                           336..392 : Begin
            { Y coordinate } Points[trunc(MouseY/8)-4,2]:=Get_Real(43,trunc(MouseY/8+1),Points[trunc(MouseY/8)-4,2]);
                                        GotoXY(43,trunc(MouseY/8+1));
                                        Write(points[trunc(MouseY/8-4),2]:8:3);
                                      End;
                           576..632 : If Curve=3 then
            { Weighting factor }        Begin
                             Weight[trunc(MouseY/8)-4]:=Get_Real(73,trunc(MouseY/8+1),Weight[trunc(MouseY/8)-4]);
                                          GotoXY(73,trunc(MouseY/8+1));
                                          Write(Weight[trunc(MouseY/8-4)]:7:3,' ');
                                        End;
              End;
{ Modify tangent vectors for a piecewise Hermite curve }
              If (Curve=1) and (MouseY>=40+8*n) and (MouseY<=48+8*n) then
              Case MouseX of
                           280..336 : Begin
              { X coordinate }          If trunc(MouseY/8)-4=n+1 then
                                          v1[1]:=Get_Real(36,trunc(MouseY/8+1),v1[1])
                                        else
                                          v2[1]:=Get_Real(36,trunc(MouseY/8+1),v2[1]);;
                                        GotoXY(36,trunc(MouseY/8+1));
                                        Write(t:8:3);
                                      End;
                           448..504 : Begin
              { Y coordinate }          If trunc(MouseY/8)-4=n+1 then
                                          v1[2]:=Get_Real(57,trunc(MouseY/8+1),v1[2])
                                        else
                                          v2[2]:=Get_Real(57,trunc(MouseY/8+1),v2[2]);
                                        GotoXY(57,trunc(MouseY/8+1));
                                        Write(t:8:3);
                                      End;
              End;
            Mouse_Cursor(on);
          End;
      Until Choice<>0;
      Mouse_Cursor(off);
    End
  else Choice:=3;
End;

{ ************************  MAIN PROGRAM  ************************** }

BEGIN
{ Look for Video Graphic Array card }
  Driver:=Detect;
  InitGraph(Driver,Mode,'');
  ErrCode:=GraphResult;
{ Initialise black sprite for coordinates displaying }
  GetMem(Text_Image,ImageSize(0,0,450,13));
  GetImage(0,0,450,13,Text_Image^);
  Clrscr;
  GotoXY(20,12);
{ Stop if error }
  If not ErrCode=GrOk then
    Begin
      WriteLn('Graphics error : ',GraphErrorMsg(ErrCode));
      Halt(1);
    End;
{ Stop if VGA 640x480 card not detected }
  If (Driver<>9) or (Mode<>2) then
    Begin
      Write('Sorry ! This program needs a VGA card in 640*480 mode.');
      Halt(1);
    End;
{ Look for mouse }
  Mickey:=Init_Mouse;
  If not Mickey then
    Begin
      Write('Sorry ! This program needs a mouse.');
      Halt(1);
  End;
{ If OK, run program }
  TextMode(Co80);
  Scale:=false;
  Getting:=true;
  Repeat
    Cursor(off);
    Main_Menu;
  Until Choice=3;
{ "Bye bye !" screen }
  TextBackGround(Blue);
  ClrScr;
  TextColor(White+Blink);
  GotoXY(25,12);
  Write('Good bye. Have a nice day !');
  Repeat until Button=0;
  Empty_Keyboard;
  Repeat until (KeyPressed) or (Button<>0);
  NormVideo;
  Cursor(on);
  ClrScr;
END.

{ END OF PROGRAM }