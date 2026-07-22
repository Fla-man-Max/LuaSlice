package;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import funkin.Paths;
import funkin.Preferences;
import funkin.graphics.FunkinSprite;
import funkin.graphics.shaders.DropShadowShader;
import funkin.graphics.shaders.RuntimePostEffectShader;
import funkin.graphics.shaders.RuntimeRainShader;
import funkin.play.PlayState;
import funkin.modding.base.ScriptedFlxRuntimeShader;
import haxe.io.Path;
import openfl.Assets;
import openfl.filters.ShaderFilter;
import sys.FileSystem;
import sys.io.File;
#end

class LuaShaderManager
{
  #if FEATURE_LUA_SCRIPTS
  var shaders:Map<String, FlxShader> = [];
  var appliedTargets:Array<Dynamic> = [];
  var appliedCameras:Array<FlxCamera> = [];
  var suppressedTargetShaders:Array<SuppressedTargetShader> = [];
  var suppressedCameraFilters:Array<SuppressedCameraFilters> = [];
  var cameraFilters:Map<FlxCamera, Array<LuaCameraFilterEntry>> = [];
  var cameraBaseFilters:Map<FlxCamera, Array<openfl.filters.BitmapFilter>> = [];
  var cameraBaseFiltersEnabled:Map<FlxCamera, Bool> = [];
  var targetShaderInstances:Array<LuaShaderTarget> = [];
  var transparentGuards:Map<String, Bool> = [];
  var transparentIncludes:Map<String, Bool> = [];

  public function new() {}

  public function createShader(tag:String, fragment:String, vertex:String, ignoreTransparentPixels:Bool = false, includeTransparentPixels:Bool = false):Bool
  {
    if (tag == '' || fragment == '') return false;
    try
    {
      var fragmentSource = readShaderSource(fragment, true);
      var vertexSource = vertex == '' ? null : readShaderSource(vertex, false);
      if (fragmentSource == null) return false;
      if (ignoreTransparentPixels) fragmentSource = addTransparentPixelGuard(fragmentSource);
      else if (includeTransparentPixels) fragmentSource = addTransparentPixelSupport(fragmentSource);
      final shaderName = Path.withoutExtension(Path.withoutDirectory(fragment)).toLowerCase();
      final shader:FlxRuntimeShader = if (shaderName == 'rain' && vertexSource == null)
        new RuntimeRainShader();
      else if (vertexSource == null && requiresPostEffectRuntime(fragmentSource))
        new RuntimePostEffectShader(fragmentSource);
      else
        new FlxRuntimeShader(fragmentSource, vertexSource);
      shaders.set(tag, shader);
      transparentGuards.set(tag, ignoreTransparentPixels);
      transparentIncludes.set(tag, includeTransparentPixels);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] createShader failed: ${e}');
      return false;
    }
  }

  public function initScriptedShader(className:String, ?tag:String = ''):Bool
  {
    if (className == '') return false;
    final resolvedTag = tag == '' ? className : tag;
    try
    {
      final shader = ScriptedFlxRuntimeShader.scriptInit(className);
      if (shader == null) return false;
      shaders.set(resolvedTag, shader);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] initScriptedShader failed: ${e}');
      return false;
    }
  }

  public function initBuiltInShader(name:String, ?tag:String = ''):Bool
  {
    if (name == '') return false;
    final resolvedTag = tag == '' ? name : tag;
    if (isDropShadowShader(name))
    {
      final shader = new DropShadowShader();
      shaders.set(resolvedTag, shader);
      return true;
    }
    return false;
  }

  public function destroyShader(tag:String):Bool
  {
    final base = shaders.get(tag);
    if (base != null)
    {
      for (camera => list in cameraFilters)
      {
        clearCameraTag(camera, tag);
      }
      for (target in appliedTargets.copy())
      {
        clearTargetTag(target, tag);
      }
      transparentGuards.remove(tag);
      transparentIncludes.remove(tag);
      return shaders.remove(tag);
    }
    return false;
  }

  public function hasShader(tag:String):Bool
  {
    return shaders.exists(tag);
  }

  public function aliasShader(sourceTag:String, newTag:String):Bool
  {
    final source = shaders.get(sourceTag);
    if (source == null) return false;
    shaders.set(newTag, source);
    transparentGuards.set(newTag, usesTransparentPixelGuard(sourceTag));
    transparentIncludes.set(newTag, includesTransparentPixels(sourceTag));
    return true;
  }

  public function setFloat(tag:String, name:String, value:Float):Bool
  {
    var result = false;
    for (shader in shaderInstances(tag))
      result = setFloatOnShader(shader, name, value) || result;
    return result;
  }

  public function setFloatArray(tag:String, name:String, values:Array<Float>):Bool
  {
    var result = false;
    for (shader in shaderInstances(tag))
    {
      if (Std.isOfType(shader, DropShadowShader)) continue;
      if (!Std.isOfType(shader, FlxRuntimeShader)) continue;
      try
      {
        cast(shader, FlxRuntimeShader).setFloatArray(name, values);
        result = true;
      }
      catch (e)
      {
        trace('[LuaShaderManager] setFloatArray failed: ${e}');
      }
    }
    return result;
  }

  public function setInt(tag:String, name:String, value:Int):Bool
  {
    var result = false;
    for (shader in shaderInstances(tag))
    {
      if (Std.isOfType(shader, DropShadowShader)) continue;
      if (!Std.isOfType(shader, FlxRuntimeShader)) continue;
      try
      {
        cast(shader, FlxRuntimeShader).setInt(name, value);
        result = true;
      }
      catch (e) {}
    }
    return result;
  }

  public function setBool(tag:String, name:String, value:Bool):Bool
  {
    var result = false;
    for (shader in shaderInstances(tag))
    {
      if (Std.isOfType(shader, DropShadowShader))
      {
        final drop:DropShadowShader = cast shader;
        if (name == 'useAltMask')
        {
          drop.useAltMask = value;
          result = true;
        }
        continue;
      }
      if (!Std.isOfType(shader, FlxRuntimeShader)) continue;
      try
      {
        cast(shader, FlxRuntimeShader).setBool(name, value);
        result = true;
      }
      catch (e)
      {
        trace('[LuaShaderManager] setBool failed: ${e}');
      }
    }
    return result;
  }

  public function setColor(tag:String, name:String, value:FlxColor):Bool
  {
    if (name != 'color') return false;
    var result = false;
    for (shader in shaderInstances(tag))
    {
      if (!Std.isOfType(shader, DropShadowShader)) continue;
      cast(shader, DropShadowShader).color = value;
      result = true;
    }
    return result;
  }

  public function applyToTarget(tag:String, target:Dynamic):Bool
  {
    if (PlayState.instance != null && !Preferences.allowSongShaders()) return false;
    var shader = shaders.get(tag);
    if (shader == null || target == null) return false;
    try
    {
      var previousShader:Dynamic = Reflect.getProperty(target, 'shader');
      var targetShader:FlxShader = shader;
      if (Std.isOfType(shader, DropShadowShader))
      {
        final dropShadowSource:DropShadowShader = Std.isOfType(previousShader, DropShadowShader) ? cast previousShader : cast shader;
        targetShader = cloneDropShadowShader(dropShadowSource);
      }
      for (entry in targetShaderInstances.copy())
      {
        if (entry.target != target) continue;
        if (previousShader == entry.shader) previousShader = entry.previousShader;
        if (entry.tag == tag) targetShaderInstances.remove(entry);
      }
      if (!appliedTargets.contains(target)) appliedTargets.push(target);
      targetShaderInstances.push({target: target, shader: targetShader, tag: tag, previousShader: previousShader});
      rebuildTargetShader(target);
      prepareTargetShader(targetShader, target);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] applyToTarget failed: ${e}');
      return false;
    }
  }

  function rebuildTargetShader(target:Dynamic):Void
  {
    if (target == null) return;
    final entries = targetShaderInstances.filter(function(e) return e.target == target);
    if (entries.length == 0) return;
    final top = entries[entries.length - 1];
    Reflect.setProperty(target, 'shader', top.shader);
  }

  public function clearTargetTag(target:Dynamic, tag:String):Bool
  {
    if (target == null) return false;
    try
    {
      var removed = false;
      var originalShader:Dynamic = null;
      for (entry in targetShaderInstances.copy())
      {
        if (entry.target != target) continue;
        if (originalShader == null) originalShader = entry.previousShader;
        if (entry.tag == tag)
        {
          targetShaderInstances.remove(entry);
          removed = true;
        }
      }
      if (!removed) return false;

      var remaining = targetShaderInstances.filter(function(e) return e.target == target);
      if (remaining.length > 0)
      {
        rebuildTargetShader(target);
      }
      else
      {
        Reflect.setProperty(target, 'shader', originalShader);
        appliedTargets.remove(target);
      }
      return true;
    }
    catch (e)
    {
      return false;
    }
  }

  public function clearTarget(target:Dynamic):Bool
  {
    if (target == null) return false;
    try
    {
      var foundEntry = false;
      var originalShader:Dynamic = null;
      for (entry in targetShaderInstances.copy())
      {
        if (entry.target != target) continue;
        foundEntry = true;
        if (originalShader == null) originalShader = entry.previousShader;
        targetShaderInstances.remove(entry);
      }
      if (!foundEntry) return false;
      Reflect.setProperty(target, 'shader', originalShader);
      appliedTargets.remove(target);
      return true;
    }
    catch (e)
    {
      return false;
    }
  }

  public function suppressTargetShaders(target:Dynamic):Bool
  {
    if (target == null) return false;
    try
    {
      clearTarget(target);
      if (!Lambda.exists(suppressedTargetShaders, function(entry) return entry.target == target))
      {
        suppressedTargetShaders.push({target: target, shader: Reflect.getProperty(target, 'shader')});
      }
      Reflect.setProperty(target, 'shader', null);
      return true;
    }
    catch (e)
    {
      return false;
    }
  }

  public inline function applyToObject(tag:String, target:Dynamic):Bool
  {
    return applyToTarget(tag, target);
  }

  public inline function clearObject(target:Dynamic):Bool
  {
    return clearTarget(target);
  }

  public function applyToCamera(tag:String, camera:FlxCamera):Bool
  {
    if (PlayState.instance != null && !Preferences.allowSongShaders()) return false;
    var shader = shaders.get(tag);
    if (shader == null || camera == null) return false;
    if (Std.isOfType(shader, DropShadowShader)) return false;

    var list = cameraFilters.get(camera);
    if (list == null)
    {
      cameraBaseFilters.set(camera, camera.filters == null ? [] : camera.filters.copy());
      cameraBaseFiltersEnabled.set(camera, camera.filtersEnabled);
      list = [];
      cameraFilters.set(camera, list);
    }

    var found = false;
    for (entry in list)
    {
      if (entry.tag == tag)
      {
        found = true;
        entry.shader = shader;
        entry.filter = new ShaderFilter(shader);
        break;
      }
    }

    if (!found)
    {
      final filter = new ShaderFilter(shader);
      list.push({tag: tag, filter: filter, shader: shader});
    }

    rebuildCameraFilters(camera);
    prepareCameraShader(shader, camera);
    if (!appliedCameras.contains(camera)) appliedCameras.push(camera);
    return true;
  }

  function rebuildCameraFilters(camera:FlxCamera):Void
  {
    if (camera == null) return;
    final list = cameraFilters.get(camera);
    if (list == null || list.length == 0)
    {
      camera.filters = [];
      camera.filtersEnabled = false;
      return;
    }
    final filters:Array<openfl.filters.BitmapFilter> = cameraBaseFilters.get(camera)?.copy() ?? [];
    for (entry in list)
    {
      filters.push(entry.filter);
    }
    camera.filters = filters;
    camera.filtersEnabled = filters.length > 0 || (cameraBaseFiltersEnabled.get(camera) ?? false);
  }

  public function clearCameraTag(camera:FlxCamera, tag:String):Bool
  {
    if (camera == null) return false;
    final list = cameraFilters.get(camera);
    if (list == null) return false;
    var removed = false;
    for (entry in list.copy())
    {
      if (entry.tag == tag)
      {
        list.remove(entry);
        removed = true;
      }
    }
    if (removed) rebuildCameraFilters(camera);
    if (list.length == 0)
    {
      cameraFilters.remove(camera);
      cameraBaseFilters.remove(camera);
      cameraBaseFiltersEnabled.remove(camera);
    }
    return removed;
  }

  public function initShader(name:String, ?tag:String = '', ignoreTransparentPixels:Bool = false, includeTransparentPixels:Bool = false):Bool
  {
    if (name == '') return false;
    final resolvedTag = tag == '' ? name : tag;
    if (isDropShadowShader(name)) return initBuiltInShader(name, resolvedTag);
    return createShader(resolvedTag, name, '', ignoreTransparentPixels, includeTransparentPixels);
  }

  public function usesTransparentPixelGuard(tag:String):Bool
  {
    return transparentGuards.get(tag) ?? false;
  }

  public function includesTransparentPixels(tag:String):Bool
  {
    return transparentIncludes.get(tag) ?? false;
  }

  public function clearCamera(camera:FlxCamera):Bool
  {
    if (camera == null) return false;
    final list = cameraFilters.get(camera);
    if (list == null) return false;
    final baseFilters = cameraBaseFilters.get(camera)?.copy() ?? [];
    final baseEnabled = cameraBaseFiltersEnabled.get(camera) ?? false;
    cameraFilters.remove(camera);
    cameraBaseFilters.remove(camera);
    cameraBaseFiltersEnabled.remove(camera);
    camera.filters = baseFilters;
    camera.filtersEnabled = baseEnabled;
    appliedCameras.remove(camera);
    return true;
  }

  public function suppressCameraShaders(camera:FlxCamera):Bool
  {
    if (camera == null) return false;
    clearCamera(camera);
    if (!Lambda.exists(suppressedCameraFilters, function(entry) return entry.camera == camera))
    {
      suppressedCameraFilters.push({camera: camera, filters: camera.filters == null ? [] : camera.filters.copy(), filtersEnabled: camera.filtersEnabled});
    }
    camera.filters = [];
    camera.filtersEnabled = false;
    return true;
  }

  public function clear():Void
  {
    for (target in appliedTargets.copy()) clearTarget(target);
    appliedTargets = [];
    targetShaderInstances = [];
    for (camera in appliedCameras.copy()) clearCamera(camera);
    appliedCameras = [];
    cameraFilters.clear();
    cameraBaseFilters.clear();
    cameraBaseFiltersEnabled.clear();
    for (entry in suppressedTargetShaders)
    {
      if (entry.target != null) Reflect.setProperty(entry.target, 'shader', entry.shader);
    }
    suppressedTargetShaders = [];
    for (entry in suppressedCameraFilters)
    {
      if (entry.camera == null) continue;
      entry.camera.filters = entry.filters;
      entry.camera.filtersEnabled = entry.filtersEnabled;
    }
    suppressedCameraFilters = [];
    shaders.clear();
    transparentGuards.clear();
    transparentIncludes.clear();
  }

  public function update(elapsed:Float):Void
  {
    final updatedRainShaders:Array<RuntimeRainShader> = [];
    for (shader in shaders)
    {
      if (!Std.isOfType(shader, RuntimeRainShader)) continue;
      final rain:RuntimeRainShader = cast shader;
      if (updatedRainShaders.contains(rain)) continue;
      rain.update(elapsed);
      updatedRainShaders.push(rain);
    }

    for (camera => list in cameraFilters)
      for (entry in list)
        prepareCameraShader(entry.shader, camera);
    for (entry in targetShaderInstances)
      prepareTargetShader(entry.shader, entry.target);
  }

  function prepareCameraShader(shader:FlxShader, camera:FlxCamera):Void
  {
    if (!Std.isOfType(shader, RuntimePostEffectShader)) return;
    final post:RuntimePostEffectShader = cast shader;
    if (Std.isOfType(shader, RuntimeRainShader)) cast(shader, RuntimeRainShader).spriteMode = false;
    post.updateViewInfo(FlxG.width, FlxG.height, camera);
  }

  function prepareTargetShader(shader:FlxShader, target:Dynamic):Void
  {
    final sprite:FlxSprite = Std.isOfType(target, FlxSprite) ? cast target : null;
    if (Std.isOfType(shader, DropShadowShader))
    {
      final drop:DropShadowShader = cast shader;
      if (Std.isOfType(sprite, FunkinSprite))
      {
        final funkinSprite:FunkinSprite = cast sprite;
        if (drop.attachedSprite != funkinSprite) drop.attachedSprite = funkinSprite;
        else if (funkinSprite.frame != null) drop.updateFrameInfo(funkinSprite.frame);
      }
      else if (sprite?.frame != null)
      {
        drop.updateFrameInfo(sprite.frame);
      }
      return;
    }
    if (!Std.isOfType(shader, RuntimePostEffectShader)) return;
    final post:RuntimePostEffectShader = cast shader;
    final camera = sprite?.cameras != null && sprite.cameras.length > 0 ? sprite.cameras[0] : FlxG.camera;
    post.updateViewInfo(FlxG.width, FlxG.height, camera);
    if (sprite?.frame != null) post.updateFrameInfo(sprite.frame);
    if (Std.isOfType(shader, RuntimeRainShader)) cast(shader, RuntimeRainShader).spriteMode = true;
  }

  function shaderInstances(tag:String):Array<FlxShader>
  {
    final result:Array<FlxShader> = [];
    final base = shaders.get(tag);
    if (base != null) result.push(base);
    for (entry in targetShaderInstances)
      if (entry.tag == tag && !result.contains(entry.shader)) result.push(entry.shader);
    return result;
  }

  function setFloatOnShader(shader:FlxShader, name:String, value:Float):Bool
  {
    if (Std.isOfType(shader, DropShadowShader)) return setDropShadowFloat(cast shader, name, value);
    if (!Std.isOfType(shader, FlxRuntimeShader)) return false;
    try
    {
      cast(shader, FlxRuntimeShader).setFloat(name, value);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] setFloat failed: ${e}');
      return false;
    }
  }

  static function setDropShadowFloat(shader:DropShadowShader, name:String, value:Float):Bool
  {
    switch (name)
    {
      case 'angle': shader.angle = value;
      case 'distance': shader.distance = value;
      case 'strength': shader.strength = value;
      case 'threshold': shader.threshold = value;
      case 'antialiasAmt': shader.antialiasAmt = value;
      case 'baseHue': shader.baseHue = value;
      case 'baseSaturation': shader.baseSaturation = value;
      case 'baseBrightness': shader.baseBrightness = value;
      case 'baseContrast': shader.baseContrast = value;
      case 'maskThreshold': shader.maskThreshold = value;
      default: return false;
    }
    return true;
  }

  static function cloneDropShadowShader(source:DropShadowShader):DropShadowShader
  {
    final shader = new DropShadowShader();
    shader.color = source.color;
    shader.angle = source.angle;
    shader.distance = source.distance;
    shader.strength = source.strength;
    shader.threshold = source.threshold;
    shader.antialiasAmt = source.antialiasAmt;
    shader.baseHue = source.baseHue;
    shader.baseSaturation = source.baseSaturation;
    shader.baseBrightness = source.baseBrightness;
    shader.baseContrast = source.baseContrast;
    shader.maskThreshold = source.maskThreshold;
    shader.useAltMask = source.useAltMask;
    if (source.altMaskImage != null) shader.altMaskImage = source.altMaskImage;
    return shader;
  }

  static function isDropShadowShader(name:String):Bool
  {
    if (name == null) return false;
    var normalized = name.toLowerCase();
    for (part in ['builtin:', 'built-in:', ' ', '-']) normalized = StringTools.replace(normalized, part, '');
    return normalized == 'dropshadow' || normalized == 'dropshadowshader';
  }

  function requiresPostEffectRuntime(source:String):Bool
  {
    return source.indexOf('screenToWorld(') != -1 || source.indexOf('worldToScreen(') != -1 || source.indexOf('screenToFrame(') != -1
      || source.indexOf('sampleBitmapWorld(') != -1;
  }

  function addTransparentPixelGuard(source:String):String
  {
    final mainPattern = ~/void\s+main\s*\(\s*(?:void\s*)?\)/;
    if (!mainPattern.match(source)) return source;
    final guardedSource = mainPattern.replace(source, 'void luasliceShaderMain()');
    return '${guardedSource}\nvoid main()\n{\n  vec4 luasliceSourcePixel = flixel_texture2D(bitmap, openfl_TextureCoordv);\n  if (luasliceSourcePixel.a <= 0.0)\n  {\n    gl_FragColor = vec4(0.0);\n    return;\n  }\n  luasliceShaderMain();\n}\n';
  }

  function addTransparentPixelSupport(source:String):String
  {
    final adjustedSource = source.split('flixel_texture2D').join('luasliceTexture2D');
    final helper = '\nvec4 luasliceTexture2D(sampler2D texture, vec2 coord)\n{\n  vec4 pixel = flixel_texture2D(texture, coord);\n  if (pixel.a <= 0.0) pixel.a = 1.0;\n  return pixel;\n}\n';
    return adjustedSource.indexOf('#pragma header') != -1 ? StringTools.replace(adjustedSource, '#pragma header', '#pragma header${helper}') : '${helper}${adjustedSource}';
  }

  function readShaderSource(key:String, fragment:Bool):Null<String>
  {
    if (FileSystem.exists(key)) return File.getContent(key);

    var ext = fragment ? 'frag' : 'vert';
    var directPath = 'mods/shaders/${key}.${ext}';
    if (FileSystem.exists(directPath)) return File.getContent(directPath);

    var assetPath = fragment ? Paths.frag(key) : Paths.vert(key);
    if (Assets.exists(assetPath)) return Assets.getText(assetPath);

    return null;
  }
  #end
}

#if FEATURE_LUA_SCRIPTS
private typedef SuppressedTargetShader =
{
  var target:Dynamic;
  var shader:Dynamic;
}

private typedef SuppressedCameraFilters =
{
  var camera:FlxCamera;
  var filters:Array<openfl.filters.BitmapFilter>;
  var filtersEnabled:Bool;
}
#end

typedef LuaCameraFilterEntry =
{
  var tag:String;
  var filter:openfl.filters.ShaderFilter;
  var shader:flixel.system.FlxAssets.FlxShader;
}

typedef LuaShaderTarget =
{
  var target:Dynamic;
  var shader:flixel.system.FlxAssets.FlxShader;
  var tag:String;
  var previousShader:Dynamic;
}
