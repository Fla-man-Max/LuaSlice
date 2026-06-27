package funkin.scripting;

#if FEATURE_LUA_SCRIPTS
class LuaApiPrelude
{
  public static function source():String
  {
    return [
      "LuaSlice = LuaSlice or {}",
      "LuaSlice.version = '0.0.4'",
      "local function v(value, fallback) if value == nil then return fallback end return value end",
      "function addLuaMainMenu(id, position, target, assetPath, animName) return addLuaMainMenuItem(id, assetPath or 'images:mainmenu/storymode', v(position, 999), animName or 'storymode', target or '') end",
      "function makeLuaMenuSimple(id, items, x, y, spacing) local sp = v(spacing, 34); local ok = createLuaMenu(id, items or {}, v(x, 80), v(y, 120), 600, 'hud', 'white', 'yellow'); setLuaMenuPosition(id, v(x, 80), v(y, 120), sp); return ok end",
      "function makeLuaImageMenuSimple(id, items, x, y, spacing) return createLuaImageMenu(id, items or {}, v(x, 80), v(y, 120), v(spacing, 95), 'hud', {}) end",
      "function initLuaShader(name, tag) return initLuaShaderRaw(name, tag) end",
      "function makeLuaShader(tag, pathOrSource, vertexPathOrSource) if pathOrSource == nil then return initLuaShader(tag) end return createShader(tag, pathOrSource, vertexPathOrSource) end",
      "function setLuaShader(tag, target) return applyShader(tag, target) end",
      "function setShaderOnSprite(sprite, tag) return applyShader(tag, sprite) end",
      "function removeLuaShader(target) return clearShader(target) end",
      "function setLuaCameraShader(tag, camera) return applyCameraShader(tag, camera or 'game') end",
      "function removeLuaCameraShader(camera) return clearCameraShader(camera or 'game') end",
      "function setLuaShaderFloatSimple(tag, name, value) return setShaderFloat(tag, name, value) end",
      "return true"
    ].join("\n");
  }
}
#end
