{
 *  Copyright © Kemka Andrey aka Andru
 *  mail: dr.andru@gmail.com
 *  site: http://andru-kun.inf.ua
 *
 *  This file is part of ZenGL.
 *
 *  ZenGL is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as
 *  published by the Free Software Foundation, either version 3 of
 *  the License, or (at your option) any later version.
 *
 *  ZenGL is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with ZenGL. If not, see http://www.gnu.org/licenses/
}
unit zgl_mouse;

{$I zgl_config.cfg}

interface
uses
  Windows;

const
  M_BLEFT   = 0;
  M_BMIDDLE = 1;
  M_BRIGHT  = 2;
  M_WUP     = 0;
  M_WDOWN   = 1;

function mouse_X : Integer;
function mouse_Y : Integer;
function mouse_DX : Integer;
function mouse_DY : Integer;
function mouse_Down( const Button : Byte ) : Boolean;
function mouse_Up( const Button : Byte ) : Boolean;
function mouse_Click( const Button : Byte ) : Boolean;
function mouse_DblClick( const Button : Byte ) : Boolean;
function mouse_Wheel( const Axis : Byte ) : Boolean;
procedure mouse_ClearState;
procedure mouse_Lock;

var
  mouseX        : Integer;
  mouseY        : Integer;
  mouseDown     : array[ 0..2 ] of Boolean;
  mouseUp       : array[ 0..2 ] of Boolean;
  mouseClick    : array[ 0..2 ] of Boolean;
  mouseCanClick : array[ 0..2 ] of Boolean;
  mouseDblClick : array[ 0..2 ] of Boolean;
  mouseDblCTime : array[ 0..2 ] of Double;
  mouseDblCInt  : Integer = 250;
  mouseWheel    : array[ 0..1 ] of Boolean;
  mouseLock     : Boolean;
  cursorpos : TPoint;
  getcurpos : Boolean;

implementation
uses
  zgl_window,
  zgl_screen;

function mouse_X;
begin
  if getcurpos Then
    begin
      getcurpos := FALSE;
      GetCursorPos( cursorpos );
    end;
  if wnd_FullScreen Then
    Result := cursorpos.X
  else
    Result := cursorpos.X - wnd_X - wnd_BrdSizeX;
  Result := Round( ( Result - scr_AddCX ) / scr_ResCX );
end;

function mouse_Y;
begin
  if getcurpos Then
    begin
      getcurpos := FALSE;
      GetCursorPos( cursorpos );
    end;
  if wnd_FullScreen Then
    Result := cursorpos.Y
  else
    Result := cursorpos.Y - wnd_Y - wnd_BrdSizeY - wnd_CpnSize;
  Result := Round( ( Result - scr_AddCY ) / scr_ResCY );
end;

function mouse_DX;
begin
  getcurpos := TRUE;
  Result := mouse_X() - wnd_Width div 2;
end;

function mouse_DY;
begin
  getcurpos := TRUE;
  Result := mouse_Y() - wnd_Height div 2;
end;

function mouse_Down;
begin
  case Button of
    M_BLEFT:   Result := GetAsyncKeyState( VK_LBUTTON ) and $8000 <> 0;
    M_BMIDDLE: Result := GetAsyncKeyState( VK_MBUTTON ) and $8000 <> 0;
    M_BRIGHT:  Result := GetAsyncKeyState( VK_RBUTTON ) and $8000 <> 0;
  end;
end;

function mouse_Up;
begin
  Result := mouseUp[ Button ];
end;

function mouse_Click;
begin
  Result := mouseClick[ Button ];
end;

function mouse_DblClick;
begin
  Result := mouseDblClick[ Button ];
end;

function mouse_Wheel;
begin
  Result := mouseWheel[ Axis ];
end;

procedure mouse_ClearState;
begin
  getcurpos := TRUE;
  FillChar( mouseUp[ 0 ], 3, 0 );
  FillChar( mouseClick[ 0 ], 3, 0 );
  FillChar( mouseDblClick[ 0 ], 3, 0 );
  FillChar( mouseCanClick[ 0 ], 3, 1 );
  FillChar( mouseWheel[ 0 ], 2, 0 );
end;

procedure mouse_Lock;
begin
  if wnd_FullScreen Then
    SetCursorPos( wnd_Width div 2, wnd_Height div 2 )
  else
    SetCursorPos( wnd_X + wnd_BrdSizeX + wnd_Width div 2, wnd_Y + wnd_BrdSizeY + wnd_CpnSize + wnd_Height div 2 );
end;

end.
