package funkin.scripting;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxCamera;
import flixel.addons.display.FlxRuntimeShader;
import funkin.Paths;
import openfl.Assets;
import openfl.filters.ShaderFilter;
import sys.FileSystem;
import sys.io.File;
#end

class LuaShaderManager
{
  #if FEATURE_LUA_SCRIPTS
  var shaders:Map<String, FlxRuntimeShader> = [];
  var appliedTargets:Array<Dynamic> = [];
  var appliedCameras:Array<FlxCamera> = [];
  var cameraShaders:Map<FlxCamera, ShaderFilter> = [];

  public function new() {}

  public function createShader(tag:String, fragment:String, vertex:String):Bool
  {
    if (tag == '' || fragment == '') return false;
    try
    {
      var fragmentSource = readShaderSource(fragment, true);
      var vertexSource = vertex == '' ? null : readShaderSource(vertex, false);
      if (fragmentSource == null) return false;
      shaders.set(tag, new FlxRuntimeShader(fragmentSource, vertexSource));
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] createShader failed: ${e}');
      return false;
    }
  }

  public function destroyShader(tag:String):Bool
  {
    return shaders.remove(tag);
  }

  public function setFloat(tag:String, name:String, value:Float):Bool
  {
    var shader = shaders.get(tag);
    if (shader == null || name == '') return false;
    try
    {
      shader.setFloat(name, value);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] setFloat failed: ${e}');
      return false;
    }
  }

  public function setFloatArray(tag:String, name:String, values:Array<Float>):Bool
  {
    var shader = shaders.get(tag);
    if (shader == null || name == '') return false;
    try
    {
      shader.setFloatArray(name, values);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] setFloatArray failed: ${e}');
      return false;
    }
  }

  public function setInt(tag:String, name:String, value:Int):Bool
  {
    var shader = shaders.get(tag);
    if (shader == null || name == '') return false;
    try
    {
      shader.setInt(name, value);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] setInt failed: ${e}');
      return false;
    }
  }

  public function setBool(tag:String, name:String, value:Bool):Bool
  {
    var shader = shaders.get(tag);
    if (shader == null || name == '') return false;
    try
    {
      shader.setBool(name, value);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] setBool failed: ${e}');
      return false;
    }
  }

  public function applyToTarget(tag:String, target:Dynamic):Bool
  {
    var shader = shaders.get(tag);
    if (shader == null || target == null) return false;
    try
    {
      Reflect.setProperty(target, 'shader', shader);
      if (!appliedTargets.contains(target)) appliedTargets.push(target);
      return true;
    }
    catch (e)
    {
      trace('[LuaShaderManager] applyToTarget failed: ${e}');
      return false;
    }
  }

  public function clearTarget(target:Dynamic):Bool
  {
    if (target == null) return false;
    try
    {
      Reflect.setProperty(target, 'shader', null);
      appliedTargets.remove(target);
      return true;
    }
    catch (e)
    {
      return false;
    }
  }

  public function applyToCamera(tag:String, camera:FlxCamera):Bool
  {
    var shader = shaders.get(tag);
    if (shader == null || camera == null) return false;
    clearCamera(camera);
    var filter = new ShaderFilter(shader);
    camera.filters = [filter];
    camera.filtersEnabled = true;
    cameraShaders.set(camera, filter);
    if (!appliedCameras.contains(camera)) appliedCameras.push(camera);
    return true;
  }

  public function initShader(name:String, ?tag:String = ''):Bool
  {
    if (name == '') return false;
    return createShader(tag == '' ? name : tag, name, '');
  }

  public function clearCamera(camera:FlxCamera):Bool
  {
    if (camera == null) return false;
    camera.filters = [];
    camera.filtersEnabled = false;
    cameraShaders.remove(camera);
    appliedCameras.remove(camera);
    return true;
  }

  public function clear():Void
  {
    for (target in appliedTargets) clearTarget(target);
    appliedTargets = [];
    for (camera in appliedCameras) clearCamera(camera);
    appliedCameras = [];
    cameraShaders.clear();
    shaders.clear();
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
