package luaslice.debug;

class CharacterEditorDrag
{
  public var finger(default, null):Null<Int>;
  var x:Float = 0;
  var y:Float = 0;
  var editing:Bool = false;

  public function new() {}

  public function begin(id:Int, x:Float, y:Float, editing:Bool):Void
  {
    finger = id;
    this.x = x;
    this.y = y;
    this.editing = editing;
  }

  public function move(id:Int, x:Float, y:Float, zoom:Float, speed:Float):Null<{x:Float, y:Float, edit:Bool}>
  {
    if (finger != id || zoom <= 0 || (this.x == x && this.y == y)) return null;
    final scale = (editing ? speed : 1) / zoom;
    final delta = {x: (this.x - x) * scale, y: (this.y - y) * scale, edit: editing};
    this.x = x;
    this.y = y;
    return delta;
  }

  public function cancel():Void
  {
    finger = null;
  }
}
