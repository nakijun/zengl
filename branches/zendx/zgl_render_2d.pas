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
unit zgl_render_2d;

{$I zgl_config.cfg}

interface
uses
  zgl_direct3d,
  zgl_direct3d_all,
  zgl_textures;

procedure batch2d_Begin;
procedure batch2d_End;
procedure batch2d_Flush;
function  batch2d_Check( Mode, FX : LongWord; Texture : zglPTexture ) : Boolean;

function sprite2d_InScreenSimple( X, Y, W, H, Angle : Single ) : Boolean;
function sprite2d_InScreenCamera( X, Y, W, H, Angle : Single ) : Boolean;

var
  render2d_Clip    : Boolean;
  b2d_Started      : Boolean;
  b2d_New          : Boolean;
  b2d_Batches      : LongWord;
  b2dcur_Mode      : LongWord;
  b2dcur_FX        : LongWord;
  b2dcur_Blend     : LongWord;
  b2dcur_Color     : LongWord;
  b2dcur_ColorMask : LongWord;
  b2dcur_Tex       : zglPTexture;
  b2dcur_Smooth    : LongWord;
  sprite2d_InScreen : function( X, Y, W, H, Angle : Single ) : Boolean;

implementation
uses
  zgl_screen,
  zgl_fx,
  zgl_camera_2d,
  zgl_primitives_2d;

procedure batch2d_Begin;
begin
  b2d_New     := TRUE;
  b2d_Started := TRUE;
end;

procedure batch2d_End;
begin
  batch2d_Flush();
  b2d_Batches  := 0;
  b2dcur_Mode  := 0;
  b2dcur_FX    := 0;
  b2dcur_Blend := 0;
  b2dcur_Color := 0;
  b2dcur_Tex   := nil;
  b2d_Started  := FALSE;
end;

procedure batch2d_Flush;
begin
  if b2d_Started and ( not b2d_New ) Then
    begin
      INC( b2d_Batches );
      b2d_New := TRUE;
      glEnd();

      glDisable( GL_TEXTURE_2D );
      glDisable( GL_ALPHA_TEST );
      glDisable( GL_BLEND );

      if b2dcur_Smooth > 0 Then
        begin
          b2dcur_Smooth := 0;
          glDisable( GL_LINE_SMOOTH    );
          glDisable( GL_POLYGON_SMOOTH );
        end;
    end;
end;

function batch2d_Check( Mode, FX : LongWord; Texture : zglPTexture ) : Boolean;
begin
  if ( Mode <> b2dcur_Mode ) or ( Texture <> b2dcur_Tex ) or ( ( FX and FX_BLEND = 0 ) and ( b2dcur_Blend <> 0 ) ) or
     ( b2dcur_Smooth <> FX and PR2D_SMOOTH ) Then
    begin
      if not b2d_New Then
        batch2d_Flush();
      b2d_New := TRUE;
    end;

  b2dcur_Mode   := Mode;
  b2dcur_Tex    := Texture;
  b2dcur_FX     := FX;
  b2dcur_Smooth := FX and PR2D_SMOOTH;
  if FX and FX_BLEND = 0 Then
    b2dcur_Blend := 0;

  Result := b2d_New;
  b2d_New := FALSE;
end;

function sprite2d_InScreenSimple( X, Y, W, H, Angle : Single ) : Boolean;
begin
  if Angle <> 0 Then
    Result := ( ( X + W + H / 2 > ogl_ClipX ) and ( X - W - H / 2 < ogl_ClipX + ogl_ClipW / scr_ResCX ) and
                ( Y + H + W / 2 > ogl_ClipY ) and ( Y - W - H / 2 < ogl_ClipY + ogl_ClipH / scr_ResCY ) )
  else
    Result := ( ( X + W > ogl_ClipX ) and ( X < ogl_ClipX + ogl_ClipW / scr_ResCX ) and
                ( Y + H > ogl_ClipY ) and ( Y < ogl_ClipY + ogl_ClipH / scr_ResCY ) );
end;

function sprite2d_InScreenCamera( X, Y, W, H, Angle : Single ) : Boolean;
  var
    sx, sy, srad : Single;
begin
  if not cam2d.OnlyXY Then
    begin
      sx   := X + W / 2;
      sy   := Y + H / 2;
      srad := ( W + H ) / 2;

      Result := sqr( sx - cam2d.CX ) + sqr( sy - cam2d.CY ) < sqr( srad + ogl_ClipR );
    end else
      if Angle <> 0 Then
        Result := ( ( X + W + H / 2 > ogl_ClipX + cam2d.Global.X ) and ( X - W - H / 2 < ogl_ClipX + ogl_ClipW / scr_ResCX + cam2d.Global.X ) and
                    ( Y + H + W / 2 > ogl_ClipY + cam2d.Global.Y ) and ( Y - W - H / 2 < ogl_ClipY + ogl_ClipH / scr_ResCY + cam2d.Global.Y ) )
      else
        Result := ( ( X + W > ogl_ClipX + cam2d.Global.X ) and ( X < ogl_ClipX + ogl_ClipW / scr_ResCX + cam2d.Global.X ) and
                    ( Y + H > ogl_ClipY + cam2d.Global.Y ) and ( Y < ogl_ClipY + ogl_ClipH / scr_ResCY + cam2d.Global.Y ) );
end;

initialization
  sprite2d_InScreen := sprite2d_InScreenSimple;

end.
