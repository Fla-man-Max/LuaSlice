package funkin.util.macro;

#if macro
class AssetMacro
{
  public static macro function buildPolymodAudio():Array<haxe.macro.Expr.Field>
  {
    var fields = haxe.macro.Context.getBuildFields();
    if (!haxe.macro.Context.defined('sys') || haxe.macro.Context.defined('html5')) return fields;

    for (field in fields)
    {
      if (field.name != 'loadAudioBuffer') continue;
      switch (field.kind)
      {
        case FFun(func):
          if (func.expr == null || !Lambda.exists(func.args, argument -> argument.name == 'id'))
          {
            haxe.macro.Context.error('Unsupported Polymod audio loader signature.', field.pos);
          }

          var original = func.expr;
          func.expr = macro {
            var modSymbol = new polymod.backends.LimeBackend.IdAndLibrary(id, this);
            if (p.check(modSymbol.modId))
            {
              return luaslice.modding.ModAudio.load(p.file(modSymbol.modId), p.fileSystem);
            }
            $e{original};
          };
          return fields;
        default:
          haxe.macro.Context.error('Polymod audio loader must be a function.', field.pos);
      }
    }

    haxe.macro.Context.error('Polymod audio loader was not found.', haxe.macro.Context.currentPos());
    return fields;
  }

  public static macro function buildOpenFLAssets():Array<haxe.macro.Expr.Field>
  {
    var fields = haxe.macro.Context.getBuildFields();
    for (field in fields)
    {
      if (field.name != 'getBitmapData') continue;

      switch (field.kind)
      {
        case FFun(func):
          if (func.expr == null || !Lambda.exists(func.args, argument -> argument.name == 'allowCompressedTextures'))
          {
            haxe.macro.Context.error('Unsupported OpenFL bitmap loader signature.', field.pos);
          }

          var original = func.expr;
          func.expr = macro {
            if (allowCompressedTextures && id != null && haxe.io.Path.extension(id) == 'png')
            {
              var modAssetLibrary = @:privateAccess polymod.Polymod.assetLibrary;
              if (modAssetLibrary != null)
              {
                var modAssetId = id.substring(id.indexOf(':') + 1);
                if (modAssetLibrary.check(modAssetId)) allowCompressedTextures = false;
              }
            }
            $e{original};
          };
          return fields;
        default:
          haxe.macro.Context.error('OpenFL bitmap loader must be a function.', field.pos);
      }
    }

    haxe.macro.Context.error('OpenFL bitmap loader was not found.', haxe.macro.Context.currentPos());
    return fields;
  }
}
#end
