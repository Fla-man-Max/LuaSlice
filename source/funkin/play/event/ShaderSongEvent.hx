// =========================================================
// 1. funkin/play/event/ShaderSongEvent.hx
// =========================================================
package funkin.play.event;

import funkin.Paths;
import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventSchemaField;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;
import funkin.modding.base.ScriptedFlxRuntimeShader;
import openfl.Assets;
import openfl.utils.AssetType;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

class ShaderSongEvent extends SongEvent
{
  public static final MAX_PROPERTY_SLOTS:Int = 16;

  public function new() super('Shader', {processOldEvents: true});
  public override function getTitle():String return 'Shader';

  public override function handleEvent(data:SongEventData):Void
  {
    final runtime = PlayState.instance?.songEventRuntime;
    if (runtime == null) return;
    final action = data.getString('action') ?? 'apply';
    final shaderSelection = data.getString('shader') ?? '';
    final fragmentShader = shaderSelection.startsWith('frag:');
    final builtInShader = shaderSelection.startsWith('builtin:');
    final shaderId = fragmentShader ? shaderSelection.substr(5) : shaderSelection.startsWith('hxc:') ? shaderSelection.substr(4) : builtInShader
      ? shaderSelection.substr(8) : shaderSelection;
    final configuredTag = (data.getString('tag') ?? '').trim();
    final tag = configuredTag == '' ? (shaderId == '' ? 'shader' : shaderId) : configuredTag;
    final targetType = data.getString('targetType') ?? 'camera';
    final target = switch (targetType)
    {
      case 'character': data.getString('characterTarget') ?? 'all';
      case 'camera': data.getString('cameraTarget') ?? 'game';
      default: data.getString('target') ?? '';
    };
    final property = data.getString('property') ?? 'amount';
    final valueType = data.getString('valueType') ?? getUniformValueTypeForShader(shaderSelection, property);
    switch (action)
    {
      case 'apply':
        runtime.clearShadersForTarget(targetType, target);
        final ignoreTransparentPixels = fragmentShader && targetType != 'camera' && (data.getBool('ignoreTransparentPixels') ?? true);
        final includeTransparentPixels = fragmentShader && targetType != 'camera' && !ignoreTransparentPixels;
        final applied = fragmentShader ? runtime.applyShader(shaderId, tag, targetType, target, 'amount', 0, 0, ignoreTransparentPixels,
          includeTransparentPixels) : builtInShader ? runtime.applyBuiltInShader(shaderId, tag, targetType, target) : runtime.applyScriptedShader(shaderId,
            tag, targetType, target);
        if (applied)
        {
          final appliedProperties:Array<String> = [];
          for (slot in 1...(MAX_PROPERTY_SLOTS + 1))
          {
            final selectedProperty = data.getString(slotField('property', slot)) ?? '';
            if (selectedProperty == '' || appliedProperties.contains(selectedProperty)) continue;
            final selectedType = getUniformValueTypeForShader(shaderSelection, selectedProperty);
            applySelectedProperty(runtime, tag, selectedProperty, selectedType, data, slot);
            appliedProperties.push(selectedProperty);
          }
        }
      case 'remove':
        runtime.removeShader(targetType, target, tag, data.getFloat('fadeOut') ?? 0, property);
      case 'set':
        switch (valueType)
        {
          case 'position': runtime.setShaderPosition(tag, property, data.getFloat('valueX') ?? 0, data.getFloat('valueY') ?? 0);
          case 'color': runtime.setShaderColor(tag, property, data.getDynamic('color') ?? '#FFFFFF');
          case 'integer': runtime.setShaderInteger(tag, property, data.getInt('value') ?? 0);
          case 'bool': runtime.setShaderBool(tag, property, data.getBool('boolValue') ?? false);
          default: runtime.setShaderProperty(tag, property, data.getFloat('value') ?? 0);
        }
      case 'tween':
        switch (valueType)
        {
          case 'position':
            runtime.tweenShaderPosition(tag, property, data.getFloat('fromX'), data.getFloat('fromY'), data.getFloat('valueX') ?? 0,
              data.getFloat('valueY') ?? 0, data.getFloat('duration') ?? 1, data.getString('ease') ?? 'linear');
          case 'color':
            runtime.tweenShaderColor(tag, property, data.getDynamic('fromColor'), data.getDynamic('color') ?? '#FFFFFF', data.getFloat('duration') ?? 1,
              data.getString('ease') ?? 'linear');
          case 'integer':
            runtime.tweenShaderInteger(tag, property, data.getFloat('from'), data.getInt('value') ?? 0, data.getFloat('duration') ?? 1,
              data.getString('ease') ?? 'linear');
          case 'bool': runtime.setShaderBool(tag, property, data.getBool('boolValue') ?? false);
          default:
            runtime.tweenShaderProperty(tag, property, data.getFloat('from'), data.getFloat('value') ?? 0, data.getFloat('duration') ?? 1,
              data.getString('ease') ?? 'linear');
        }
      default: LuaSliceSongEventRuntime.warn('Unknown Shader action: ${action}');
    }
  }

  static function applySelectedProperty(runtime:LuaSliceSongEventRuntime, tag:String, property:String, valueType:String, data:SongEventData, slot:Int):Void
  {
    if (property == '' || valueType == 'none') return;
    final fadeIn = data.getFloat('fadeIn') ?? 0;
    final fadeOut = data.getFloat('fadeOut') ?? 0;
    final valueField = slotField('value', slot);
    final boolField = slotField('boolValue', slot);
    final colorField = slotField('color', slot);
    final xField = slotField('valueX', slot);
    final yField = slotField('valueY', slot);
    switch (valueType)
    {
      case 'position': runtime.setShaderPosition(tag, property, data.getFloat(xField) ?? 0, data.getFloat(yField) ?? 0);
      case 'color': runtime.setShaderColor(tag, property, data.getDynamic(colorField) ?? '#FFFFFF');
      case 'integer':
        final value = data.getInt(valueField) ?? 1;
        if (fadeIn > 0) runtime.tweenShaderInteger(tag, property, 0, value, fadeIn, 'linear');
        else runtime.setShaderInteger(tag, property, value);
        if (fadeOut > 0) runtime.schedule(Math.max(0, fadeIn), function() runtime.tweenShaderInteger(tag, property, null, 0, fadeOut, 'linear'));
      case 'bool': runtime.setShaderBool(tag, property, data.getBool(boolField) ?? true);
      default:
        final value = data.getFloat(valueField) ?? 1;
        if (fadeIn > 0) runtime.tweenShaderProperty(tag, property, 0, value, fadeIn, 'linear');
        else runtime.setShaderProperty(tag, property, value);
        if (fadeOut > 0) runtime.schedule(Math.max(0, fadeIn), function() runtime.tweenShaderProperty(tag, property, null, 0, fadeOut, 'linear'));
    }
  }

  static inline function slotField(base:String, slot:Int):String
  {
    return slot == 1 ? base : '${base}${slot}';
  }

  static var _cachedSchema:Null<SongEventSchema> = null;

  public static function invalidateSchemaCache():Void
  {
    _cachedSchema = null;
  }

  public override function getEventSchema():SongEventSchema
  {
    if (_cachedSchema != null) return _cachedSchema;

    final shaders:Map<String, Dynamic> = [];
    shaders.set('[BUILT-IN] Drop Shadow', 'builtin:DropShadowShader');
    final classNames = ScriptedFlxRuntimeShader.listScriptClasses();
    classNames.sort(function(a, b) return Reflect.compare(a, b));
    for (className in classNames) shaders.set('[HXC] ${className}', className);
    final fragments = listFragmentShaders();
    for (fragment in fragments) shaders.set('[FRAG] ${fragment}', 'frag:${fragment}');
    if (shaders.size() == 0) shaders.set('No shader files found', '');
    final defaultShader = fragments.contains('grayscale') ? 'frag:grayscale' : fragments.length > 0 ? 'frag:${fragments[0]}' : classNames.length > 0 ? classNames[0] : '';

    final properties:Map<String, Dynamic> = ['None' => '', 'amount (Number)' => 'amount', 'position (X/Y)' => 'position'];
    for (fragment in fragments)
    {
      for (uniform in listFragmentUniforms(fragment))
      {
        final label = '${uniform.name} (${uniformLabel(uniform.type)})';
        properties.set(label, uniform.name);
      }
    }

    var propertySlotCount = 2;
    for (fragment in fragments)
      propertySlotCount = Std.int(Math.min(MAX_PROPERTY_SLOTS, Math.max(propertySlotCount, listFragmentUniforms(fragment).length)));
    for (className in classNames)
      propertySlotCount = Std.int(Math.min(MAX_PROPERTY_SLOTS, Math.max(propertySlotCount, listPropertiesForShader(className).length)));
    final settingsFields:Array<SongEventSchemaField> = [];
    for (slot in 1...(propertySlotCount + 1))
    {
      final suffix = slot == 1 ? '' : Std.string(slot);
      settingsFields.push({
        name: 'property${suffix}', title: slot == 1 ? 'Shader Property' : 'Shader Property ${slot}', defaultValue: slot == 1 ? 'amount' : '',
        type: SongEventFieldType.ENUM, keys: properties
      });
      settingsFields.push({
        name: 'valueType${suffix}', title: 'Value Type', defaultValue: slot == 1 ? 'number' : 'none', type: SongEventFieldType.ENUM,
        keys: ['No Settings' => 'none', 'Number' => 'number', 'Whole Number' => 'integer', 'On / Off' => 'bool', 'Position (X/Y)' => 'position',
          'Color' => 'color']
      });
      settingsFields.push({name: 'value${suffix}', title: 'Value', defaultValue: 1.0, step: 0.05, type: SongEventFieldType.FLOAT});
      settingsFields.push({name: 'boolValue${suffix}', title: 'Enabled', defaultValue: true, type: SongEventFieldType.BOOL});
      settingsFields.push({name: 'color${suffix}', title: 'Color', defaultValue: '#FFFFFF', type: SongEventFieldType.COLOR});
      settingsFields.push({name: 'valueX${suffix}', title: 'X', defaultValue: 0.0, step: 0.05, type: SongEventFieldType.FLOAT});
      settingsFields.push({name: 'valueY${suffix}', title: 'Y', defaultValue: 0.0, step: 0.05, type: SongEventFieldType.FLOAT});
    }
    settingsFields.push({
      name: 'fadeIn', title: 'Fade In Duration', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    });
    settingsFields.push({
      name: 'fadeOut', title: 'Fade Out Duration', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    });

    _cachedSchema = new SongEventSchema([{
      name: 'action', title: 'Action', defaultValue: 'apply', type: SongEventFieldType.ENUM,
      keys: ['Apply Shader' => 'apply', 'Remove Shader' => 'remove', 'Set Property' => 'set', 'Tween Property' => 'tween']
    }, {
      name: 'shader', title: 'Shader File', defaultValue: defaultShader, type: SongEventFieldType.ENUM, keys: shaders
    }, {
      name: 'tag', title: 'Shader Tag (Optional)', defaultValue: '', type: SongEventFieldType.STRING
    }, {
      name: 'targetType', title: 'Target Type', defaultValue: 'camera', type: SongEventFieldType.ENUM,
      keys: ['Camera' => 'camera', 'Character' => 'character', 'Object' => 'object', 'Stage Object' => 'stageobject', 'Overlay' => 'overlay']
    }, {
      name: 'characterTarget', title: 'Character Target', defaultValue: 'all', type: SongEventFieldType.ENUM,
      keys: ['All Characters' => 'all', 'BF (Player)' => 'bf', 'Dad (Opponent)' => 'dad', 'GF' => 'gf']
    }, {
      name: 'cameraTarget', title: 'Camera Target', defaultValue: 'game', type: SongEventFieldType.ENUM,
      keys: ['Screen (Game + HUD)' => 'screen', 'Game' => 'game', 'HUD' => 'hud', 'Cutscene' => 'cutscene']
    }, {
      name: 'target', title: 'Target Name', defaultValue: 'game', type: SongEventFieldType.STRING
    }, {
      name: 'ignoreTransparentPixels', title: 'Ignore Transparent Pixels', defaultValue: true, type: SongEventFieldType.BOOL
    }, {
      name: 'removeExisting', title: 'Remove Existing Shaders', defaultValue: true, type: SongEventFieldType.BOOL
    }, {
      name: 'settings', title: 'Property Settings', type: SongEventFieldType.FRAME, collapsible: false, children: settingsFields
    }]);
    return _cachedSchema;
  }

  public static function listFragmentShaders():Array<String>
  {
    final result:Array<String> = [];
    for (asset in Assets.list(AssetType.TEXT))
    {
      final normalized = asset.replace('\\', '/');
      if (!normalized.toLowerCase().contains('/shaders/') || !normalized.toLowerCase().endsWith('.frag')) continue;
      final name = Path.withoutExtension(Path.withoutDirectory(normalized));
      if (!result.contains(name)) result.push(name);
    }
    for (directory in ['assets/shaders', 'assets/shared/shaders', 'assets/preload/shaders', 'mods/shaders'])
    {
      if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory)) continue;
      for (file in FileSystem.readDirectory(directory))
      {
        if (!file.toLowerCase().endsWith('.frag')) continue;
        final name = Path.withoutExtension(file);
        if (!result.contains(name)) result.push(name);
      }
    }
    result.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
    return result;
  }

  public static function listFragmentUniforms(shader:String):Array<ShaderUniformInfo>
  {
    final source = readFragment(shader);
    if (source == null) return [];
    var result:Array<ShaderUniformInfo> = [];
    var remaining = ~/\/\*[\s\S]*?\*\//g.replace(source, '');
    remaining = ~/\/\/[^\r\n]*/g.replace(remaining, '');
    final regex = ~/uniform\s+(?:(?:lowp|mediump|highp)\s+)?(float|int|bool|vec2|vec3|vec4)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[[^\]]+\])?\s*;/;
    while (regex.match(remaining))
    {
      final type = regex.matched(1);
      final name = regex.matched(2);
      if (!result.exists(function(entry) return entry.name == name)) result.push({name: name, type: uniformValueType(type)});
      remaining = regex.matchedRight();
    }
    final hasColorParts = result.exists(function(entry) return entry.name == 'colorRed') && result.exists(function(entry) return entry.name == 'colorGreen')
      && result.exists(function(entry) return entry.name == 'colorBlue');
    if (hasColorParts)
    {
      result = result.filter(function(entry) return !['colorAlpha', 'colorRed', 'colorGreen', 'colorBlue'].contains(entry.name));
      result.push({name: 'color', type: 'color'});
    }
    result.sort(function(a, b) return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
    return result;
  }

  public static function getUniformValueType(name:String):String
  {
    for (shader in listFragmentShaders())
      for (uniform in listFragmentUniforms(shader))
        if (uniform.name == name) return uniform.type;
    return name == 'position' ? 'position' : 'number';
  }

  public static function getUniformValueTypeForShader(selection:String, name:String):String
  {
    for (uniform in listPropertiesForShader(selection))
      if (uniform.name == name) return uniform.type;
    return name == 'position' ? 'position' : 'number';
  }

  public static function getUniformRangeForShader(selection:String, name:String):ShaderUniformRange
  {
    final normalized = name == null ? '' : name.toLowerCase();
    final valueType = getUniformValueTypeForShader(selection, name);
    if (selection == 'builtin:DropShadowShader')
    {
      if (normalized == 'angle' || normalized == 'basehue') return {min: -180, max: 180, step: 1};
      if (normalized == 'distance') return {min: 0, max: 100, step: 1};
      if (normalized == 'antialiasamt') return {min: 0, max: 8, step: 1};
      if (['basebrightness', 'basesaturation', 'basecontrast'].contains(normalized)) return {min: -100, max: 100, step: 1};
      if (['strength', 'threshold'].contains(normalized)) return {min: 0, max: 1, step: 0.01};
    }
    if (valueType == 'integer') return {min: 0, max: 100, step: 1};
    if (normalized.contains('hue') || normalized.contains('angle') || normalized.contains('rotation')) return {min: -180, max: 180, step: 1};
    if (normalized.contains('brightness') || normalized.contains('saturation') || normalized.contains('lightness') || normalized.contains('contrast'))
      return {min: 0, max: 100, step: 1};
    if (normalized.contains('amount') || normalized.contains('strength') || normalized.contains('intensity') || normalized.contains('alpha')
      || normalized.contains('opacity') || normalized.contains('mix') || normalized.contains('threshold')) return {min: 0, max: 1, step: 0.01};
    return {min: -100, max: 100, step: 0.1};
  }

  public static function getShaderSource(selection:String):Null<String>
  {
    if (selection == null || selection == '') return null;
    if (selection.startsWith('frag:')) return readFragment(selection.substr(5));
    if (selection.startsWith('builtin:')) return null;
    return readScriptedShader(selection.startsWith('hxc:') ? selection.substr(4) : selection);
  }

  public static function getSupportedTargetTypes(selection:String):Array<String>
  {
    final all = ['camera', 'character', 'object', 'stageobject', 'overlay'];
    if (selection == null || selection == '') return all;
    final source = getShaderSource(selection);
    if (source == null) return all;

    final lower = source.toLowerCase();
    final targetsRegex = ~/\/\/\s*@(targets|targettypes)\s+([^\r\n]+)/i;
    if (targetsRegex.match(source))
    {
      final list = targetsRegex.matched(2).toLowerCase().split(',').map(function(s) return s.trim());
      final filtered = all.filter(function(t) return list.contains(t));
      if (filtered.length > 0) return filtered;
    }

    var result = all.copy();
    if (lower.contains('//@no-character') || lower.contains('//@nocharacter') || lower.contains('//@no-characters'))
      result.remove('character');
    if (lower.contains('//@no-camera') || lower.contains('//@nocamera'))
      result.remove('camera');
    if (lower.contains('//@no-object') || lower.contains('//@noobject'))
    {
      result.remove('object');
      result.remove('stageobject');
    }
    if (lower.contains('//@no-overlay') || lower.contains('//@nooverlay'))
      result.remove('overlay');

    return result.length > 0 ? result : all;
  }

  public static function getSupportedCameraTargets(selection:String):Array<String>
  {
    final all = ['screen', 'game', 'hud', 'cutscene'];
    if (selection == null || selection == '') return all;
    final source = getShaderSource(selection);
    if (source == null) return all;

    final lower = source.toLowerCase();
    final cameraRegex = ~/\/\/\s*@(cameras|cameratargets)\s+([^\r\n]+)/i;
    if (cameraRegex.match(source))
    {
      final list = cameraRegex.matched(2).toLowerCase().split(',').map(function(s) return s.trim());
      final filtered = all.filter(function(c) return list.contains(c));
      if (filtered.length > 0) return filtered;
    }

    var result = all.copy();
    if (lower.contains('//@no-hud') || lower.contains('//@nohud'))
    {
      result.remove('hud');
      result.remove('screen');
    }
    if (lower.contains('//@no-game') || lower.contains('//@nogame'))
    {
      result.remove('game');
      result.remove('screen');
    }
    if (lower.contains('//@no-cutscene') || lower.contains('//@nocutscene'))
      result.remove('cutscene');

    return result.length > 0 ? result : all;
  }

  public static function getSupportedCharacterTargets(selection:String):Array<String>
  {
    final all = ['all', 'bf', 'dad', 'gf'];
    if (selection == null || selection == '') return all;
    final source = getShaderSource(selection);
    if (source == null) return all;

    final charRegex = ~/\/\/\s*@(characters|charactertargets)\s+([^\r\n]+)/i;
    if (charRegex.match(source))
    {
      final list = charRegex.matched(2).toLowerCase().split(',').map(function(s) return s.trim());
      final filtered = all.filter(function(c) return list.contains(c));
      if (filtered.length > 0) return filtered;
    }

    return all;
  }

  public static function listPropertiesForShader(selection:String):Array<ShaderUniformInfo>
  {
    if (selection == 'builtin:DropShadowShader')
    {
      return [
        {name: 'color', type: 'color'},
        {name: 'angle', type: 'number'},
        {name: 'distance', type: 'number'},
        {name: 'strength', type: 'number'},
        {name: 'threshold', type: 'number'},
        {name: 'antialiasAmt', type: 'integer'},
        {name: 'baseHue', type: 'number'},
        {name: 'baseSaturation', type: 'number'},
        {name: 'baseBrightness', type: 'number'},
        {name: 'baseContrast', type: 'number'}
      ];
    }
    if (selection != null && selection.startsWith('frag:'))
    {
      final uniforms = listFragmentUniforms(selection.substr(5));
      return uniforms.length == 0 ? [{name: '', type: 'none'}] : uniforms;
    }
    final source = readScriptedShader(selection == null ? '' : selection);
    if (source != null)
    {
      final fragmentReference = ~/Paths\.frag\(\s*['"]([^'"]+)['"]\s*\)/;
      if (fragmentReference.match(source))
      {
        final uniforms = listFragmentUniforms(fragmentReference.matched(1));
        if (uniforms.length > 0) return uniforms;
      }
    }
    return [{name: 'amount', type: 'number'}, {name: 'position', type: 'position'}];
  }

  static function readScriptedShader(className:String):Null<String>
  {
    if (className == null || className == '') return null;
    final fileName = '${Path.withoutExtension(Path.withoutDirectory(className))}.hxc';
    for (asset in Assets.list(AssetType.TEXT))
    {
      final normalized = asset.replace('\\', '/');
      if (normalized.toLowerCase().contains('/scripts/shaders/') && Path.withoutDirectory(normalized).toLowerCase() == fileName.toLowerCase())
        return Assets.getText(asset);
    }
    for (directory in ['assets/scripts/shaders', 'assets/preload/scripts/shaders', 'assets/shared/scripts/shaders', 'mods/scripts/shaders'])
    {
      final path = '${directory}/${fileName}';
      if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return File.getContent(path);
    }
    return null;
  }

  static function readFragment(shader:String):Null<String>
  {
    for (path in [shader, 'mods/shaders/${shader}.frag', 'assets/shaders/${shader}.frag', 'assets/shared/shaders/${shader}.frag',
      'assets/preload/shaders/${shader}.frag'])
      if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return File.getContent(path);
    final asset = Paths.frag(shader);
    return Assets.exists(asset, AssetType.TEXT) ? Assets.getText(asset) : null;
  }

  static function uniformValueType(type:String):String
  {
    return switch (type)
    {
      case 'vec2': 'position';
      case 'vec3', 'vec4': 'color';
      case 'int': 'integer';
      case 'bool': 'bool';
      default: 'number';
    };
  }

  public static function uniformLabel(type:String):String
  {
    return switch (type)
    {
      case 'position': 'X/Y';
      case 'color': 'Color';
      case 'integer': 'Whole Number';
      case 'bool': 'On / Off';
      case 'none': 'No Settings';
      default: 'Number';
    };
  }
}

typedef ShaderUniformInfo =
{
  var name:String;
  var type:String;
}

typedef ShaderUniformRange =
{
  var min:Float;
  var max:Float;
  var step:Float;
}


// =========================================================
// 2. QtStagePico.hx
// =========================================================
import flixel.FlxG;
import funkin.play.character.CharacterType;
import funkin.play.PlayState;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.play.stage.Stage;
import funkin.graphics.shaders.AdjustColorShader;
import funkin.play.character.BaseCharacter;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxTiledSprite;
import flixel.graphics.frames.FlxFrame;
import openfl.geom.ColorTransform;
import flixel.FlxSprite;
import funkin.graphics.shaders.GaussianBlurShader;
import funkin.audio.FunkinSound;

class QtStagePico extends Stage
{
  private var colorShader:AdjustColorShader = new AdjustColorShader();
  var carInterruptable:Bool = true;
  var carGoingRight:Bool = true;
  var busIsPassing:Bool = false;

  function new()
  {
    super('qtStagePico');
  }

  var clouds:FlxTiledSprite;
  var colorShaderBfGf:AdjustColorShader;
  var colorShaderDad:AdjustColorShader;
  var colorShaderGf:AdjustColorShader;
  var busSprite:BusSprite;
  var blurShader:GaussianBlurShader;
  var blurAmount:Float = 1.0;
  var cars;

  override function buildStage()
  {
    super.buildStage();
    if (Math.random() < 0.05) getNamedProp("lucky").loadGraphic(Paths.image('outskirts/qtPlush'));

    clouds = new FlxBackdrop(Paths.image('outskirts/clouds'), 0x01);
    clouds.scrollFactor.set(0.25, 0.25);
    clouds.setPosition(-340.5, -237.5);
    clouds.zIndex = 11;
    clouds.velocity.x = 17;
    add(clouds);
    busSprite = new BusSprite(-656, -30);
    busSprite.zIndex = 12;
    add(busSprite);
    cars = getNamedProp('randomCars');
    blurShader = new GaussianBlurShader();
    cars.shader = blurShader;

    refresh();

    colorShaderBfGf = new AdjustColorShader();
    colorShaderBfGf.brightness = 5;
    colorShaderBfGf.hue = 12;
    colorShaderBfGf.contrast = 5;
    colorShaderBfGf.saturation = -10;
  }

  override function onPause(event:PauseScriptEvent)
  {
    super.onPause(event);
    FlxTween.globalManager.forEach((tween:FlxTween) -> tween.active = false);
  }

  override function onResume(e)
  {
    super.onResume(e);
    FlxTween.globalManager.forEach((tween:FlxTween) -> tween.active = true);
  }

  override function onCreate(event:ScriptEvent):Void
  {
    super.onCreate(event);
    resetCar();
  }

  override function addCharacter(character:BaseCharacter, charType:CharacterType):Void
  {
    super.addCharacter(character, charType);
    switch (charType)
    {
      case CharacterType.BF:
        character.shader = colorShaderBfGf;
      case CharacterType.DAD:
        colorShaderDad = new AdjustColorShader();
        colorShaderDad.brightness = -40;
        colorShaderDad.hue = -35;
        colorShaderDad.contrast = -25;
        colorShaderDad.saturation = -30;
        character.shader = colorShaderDad;
        character.colorTransform = new ColorTransform(0.9, 1, 1, 1, 0, 0, 0);
      case CharacterType.GF:
        character.shader = colorShaderBfGf;
    }
  }

  private function updateColorShader(hue:Int, saturation:Int, contrast:Int, brightness:Int):Void
  {
    colorShader.hue = hue;
    colorShader.saturation = saturation;
    colorShader.contrast = contrast;
    colorShader.brightness = brightness;
  }

  function resetCar():Void
  {
    carInterruptable = true;
    carGoingRight = true;
    busIsPassing = false;

    var cars = getNamedProp('randomCars');
    if (cars != null)
    {
      FlxTween.cancelTweensOf(cars);
      FlxTween.cancelTweensOf(cars.offset);
      cars.x = -300;
      cars.flipX = false;
    }

    if (busSprite != null)
    {
      busSprite.animation.finishCallback = null;
      busSprite.animation.stop();
      busSprite.animation.frameIndex = 0;
    }
  }

  function driveCar():Void
  {
    if (!carInterruptable) return;

    carInterruptable = false;
    cars = getNamedProp('randomCars');
    if (cars == null || cars.animation == null) return;

    FlxTween.cancelTweensOf(cars);

    var variant:Int = FlxG.random.int(0, 3);
    cars.animation.play('car-' + variant);

    var duration:Float;

    switch (variant)
    {
      case 3: // moto
        duration = FlxG.random.float(1.85, 1.9);
        blurAmount = 9.0;
        FunkinSound.playOnce(Paths.sound("gameplay/motorcycle"), 0.8);

      case 2: // pickup
        duration = FlxG.random.float(2.4, 2.8);
        blurAmount = 2.0;
      case 0: // car
        duration = FlxG.random.float(3, 3.5);
        blurAmount = 1.0;
      case 1: // van
        duration = FlxG.random.float(3.8, 4.0);
        blurAmount = 0.3;
    }

    blurShader.setAmount(blurAmount);

    var startX:Float;
    var endX:Float;

    if (carGoingRight)
    {
      startX = -600;
      endX = 2400;
      cars.flipX = false;
    }
    else
    {
      startX = 2400;
      endX = -600;
      cars.flipX = true;
    }

    cars.x = startX;
    cars.offset.y = 0;

    FlxTween.tween(cars, {x: endX}, duration, {
      ease: FlxEase.sineInOut,
      onComplete: function(_)
      {
        carInterruptable = true;
        carGoingRight = !carGoingRight;
        cars.offset.y = 0;
      }
    });

    FlxTween.tween(cars.offset, {y: 3}, 0.1, {
      ease: FlxEase.sineInOut,
      type: 4,
      loopDelay: 0
    });
  }

  function driveBus():Void
  {
    if (busIsPassing) return;
    busIsPassing = true;
    busSprite.animation.play("BusGuillen");

    busSprite.animation.finishCallback = function(name:String)
    {
      busIsPassing = false;
      busSprite.animation.finishCallback = null;
    };
  }

  override function onBeatHit(event:SongTimeScriptEvent):Void
  {
    super.onBeatHit(event);
    if (event.beat == 242 && !busIsPassing) if (FlxG.random.bool(5)) driveBus();
    if (!busIsPassing && FlxG.random.bool(10) && carInterruptable) driveCar();
  }

  override function onSongRetry(event:ScriptEvent):Void
  {
    super.onSongRetry(event);
    resetCar();
    busIsPassing = false;
  }
}