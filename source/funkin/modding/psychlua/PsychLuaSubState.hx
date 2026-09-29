package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
class PsychLuaSubState extends flixel.FlxSubState
{
  final host:PsychLuaHost;
  public final luaName:String;
  final previousUpdate:Bool;
  final previousPause:Bool;

  public function new(host:PsychLuaHost, name:String, pauseGame:Bool)
  {
    super();
    this.host = host;
    luaName = name;
    previousUpdate = host.game.persistentUpdate;
    previousPause = host.game.shouldSubstatePause;
    host.game.persistentUpdate = !pauseGame;
    cameras = [host.camera('other')];
  }

  override public function create():Void
  {
    super.create();
    host.variables.set('customSubstate', this);
    host.variables.set('customSubstateName', luaName);
    host.call('onCustomSubstateCreate', [luaName]);
    host.call('onCustomSubstateCreatePost', [luaName]);
  }

  override public function update(elapsed:Float):Void
  {
    host.call('onCustomSubstateUpdate', [luaName, elapsed]);
    super.update(elapsed);
    host.call('onCustomSubstateUpdatePost', [luaName, elapsed]);
  }

  override public function destroy():Void
  {
    host.call('onCustomSubstateDestroy', [luaName]);
    for (tag in [for (tag => container in host.containers) if (container == this) tag]) host.removeObject(tag, true);
    host.variables.remove('customSubstate');
    host.variables.remove('customSubstateName');
    host.game.persistentUpdate = previousUpdate;
    host.game.shouldSubstatePause = previousPause;
    super.destroy();
  }
}
#end
