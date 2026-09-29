import luaslice.script.ScriptPropertyService;
import luaslice.script.ScriptProfiler;
import hscript.SScript;

class ScriptPropertiesTest
{
  static function main():Void
  {
    var current:Dynamic = {counter: 0, actor: {x: 10.0, alpha: 1.0}, values: [1, 2, 3]};
    final errors:Array<String> = [];
    final properties = new ScriptPropertyService(root -> root == null || root == 'state' ? current : Reflect.field(current, root),
      message -> errors.push(message));
    if (!properties.set('actor.x', 700) || properties.get('actor.x') != 700) throw 'Single property failed';
    if (!properties.setMany('actor', {x: 710}) || properties.get('actor.x') != 710) throw 'Target properties failed';
    if (!properties.setMany(['actor.x' => 720]) || properties.get('actor.x') != 720) throw 'Map properties failed';
    final full:Dynamic = {};
    Reflect.setField(full, 'actor.x', 730);
    Reflect.setField(full, 'missing.field', 1);
    if (properties.setMany(full) || properties.get('actor.x') != 730 || errors.length != 1) throw 'Partial assignment recovery failed';
    if (properties.get('state.values[1]') != 2) throw 'Indexed property read failed';
    current = {counter: 0, actor: {x: 900, alpha: 1.0}, values: []};
    if (properties.get('actor.x') != 900) throw 'Stale root reference';
    final script = new SScript('', true, false);
    script.set('state', current);
    script.set('setProperties', properties.setMany);
    script.set('configure', properties.configure);
    script.doString('function onCreate():Void { state.counter = 7; setProperties(["actor.x" => 800]); setProperties("actor", {alpha: 0.5}); configure(state, {counter: 9}); }', 'property-test.ss');
    if (script.parsingException != null) throw script.parsingException;
    final result = script.call('onCreate', []);
    if (!result.succeeded) throw result.exceptions[0];
    if (current.counter != 9 || current.actor.x != 800 || current.actor.alpha != 0.5) throw 'SScript direct/Map/configuration failed';
    script.destroy();
    ScriptProfiler.start();
    properties.get('actor.x');
    properties.set('actor.x', 42);
    final snapshot = ScriptProfiler.snapshot();
    if (snapshot.propertyReads == 0 || snapshot.propertyWrites == 0) throw 'Profiler did not count';
    ScriptProfiler.stop();
    properties.get('actor.x');
    if (ScriptProfiler.snapshot().propertyReads != snapshot.propertyReads) throw 'Disabled profiler updated counters';
    Sys.println('PASS: property overloads, partial failures, fresh roots, real SScript Map syntax, direct access and disabled profiler');
  }
}
