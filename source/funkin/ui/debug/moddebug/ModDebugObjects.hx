package funkin.ui.debug.moddebug;

#if (FEATURE_HAXEUI && (windows || android))
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import funkin.play.stage.Stage;
import luaslice.debug.ModDebugSession;

typedef ModDebugObject = {name:String, sprite:FlxSprite, stage:Stage, generation:Int};

@:access(funkin.play.stage.Stage)
class ModDebugObjects
{
  public static final uniforms:Array<String> = ['uTime', 'uIntensity', 'uStrength', 'intensity', 'strength'];
  final session:ModDebugSession;
  final preview:ModDebugPreview;
  final undo:Array<{object:ModDebugObject, property:String, restore:Void->Void}> = [];

  public function new(session:ModDebugSession, preview:ModDebugPreview)
  {
    this.session = session;
    this.preview = preview;
  }

  public function list():Array<ModDebugObject>
  {
    var stage = preview.stage;
    if (stage == null || preview.testing) return [];
    var generation = session.previewGeneration();
    var objects:Array<ModDebugObject> = [];
    for (name => sprite in stage.characters)
      if (sprite != null) objects.push({name: 'Character: $name', sprite: sprite, stage: stage, generation: generation});
    for (name => sprite in stage.namedProps)
      if (sprite != null) objects.push({name: 'Prop: $name', sprite: sprite, stage: stage, generation: generation});
    objects.sort((a, b) -> Reflect.compare(a.name, b.name));
    return objects;
  }

  function valid(object:Null<ModDebugObject>):Bool
  {
    return object != null && !preview.testing && session.ownsPreview(object.generation)
      && preview.stage == object.stage && object.sprite.exists && object.sprite.animation != null;
  }

  function remember(object:ModDebugObject, property:String, restore:Void->Void):Void
  {
    for (item in undo)
      if (item.object.sprite == object.sprite && item.property == property) return;
    undo.push({object: object, property: property, restore: restore});
  }

  public function describe(object:Null<ModDebugObject>):String
  {
    if (!valid(object)) return 'Refresh and select a live stage object.';
    var sprite = object.sprite;
    var shader = sprite.shader == null ? 'none' : Type.getClassName(Type.getClass(sprite.shader));
    return '${object.name}\nX: ${sprite.x}  Y: ${sprite.y}\nAlpha: ${sprite.alpha}  Visible: ${sprite.visible}\nShader: $shader';
  }

  public function edit(object:Null<ModDebugObject>, property:String, value:Float):Bool
  {
    if (!valid(object) || !Math.isFinite(value)) return false;
    var sprite = object.sprite;
    switch (property)
    {
      case 'X':
        var old = sprite.x;
        remember(object, property, () -> sprite.x = old);
        sprite.x = value;
      case 'Y':
        var old = sprite.y;
        remember(object, property, () -> sprite.y = old);
        sprite.y = value;
      case 'Alpha':
        if (value < 0 || value > 1) return false;
        var old = sprite.alpha;
        remember(object, property, () -> sprite.alpha = old);
        sprite.alpha = value;
      case 'Visible':
        if (value != 0 && value != 1) return false;
        var old = sprite.visible;
        remember(object, property, () -> sprite.visible = old);
        sprite.visible = value == 1;
      default:
        return false;
    }
    session.diagnostics.record('object', object.name, '$property = $value', haxe.Timer.stamp());
    return true;
  }

  public function setUniform(object:Null<ModDebugObject>, name:String, value:Float):Bool
  {
    if (!valid(object) || !uniforms.contains(name) || !Math.isFinite(value)) return false;
    if (!Std.isOfType(object.sprite.shader, FlxRuntimeShader)) return false;
    var shader:FlxRuntimeShader = cast object.sprite.shader;
    var old = shader.getFloat(name);
    if (old == null) return false;
    remember(object, 'uniform:$name', () ->
    {
      if (object.sprite.shader == shader) shader.setFloat(name, old);
    });
    shader.setFloat(name, value);
    session.diagnostics.record('shader', object.name, '$name = $value', haxe.Timer.stamp());
    return true;
  }

  public function reset():Void
  {
    for (item in undo) if (valid(item.object)) item.restore();
    undo.resize(0);
  }
}
#end
