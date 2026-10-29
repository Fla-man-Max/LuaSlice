import luaslice.modding.ModWarningPolicy;

class ModWarningPolicyTest
{
  static var checks:Int = 0;

  static function expect(condition:Bool, name:String):Void
  {
    checks++;
    if (!condition) throw name;
  }

  static function main():Void
  {
    var policy = new ModWarningPolicy();
    var flagged = '{"title":"Neon","metadata":{"photosensitivityWarning":"true"}}';
    var booleanFlag = '{"title":"Sky","metadata":{"photosensitivityWarning":true}}';
    var enabled = [{dir: 'neon', contents: flagged}, {dir: 'sky', contents: booleanFlag}];
    var warnings = policy.pending(enabled);
    expect(warnings.length == 2, 'Explicit string and boolean opt-ins warn before first load');
    expect(warnings[0].title == 'Neon' && warnings[1].title == 'Sky', 'Warnings identify each flagged mod');
    expect(policy.pending(enabled).length == 2, 'Checking does not acknowledge an unresolved warning');
    policy.acknowledge(warnings);
    expect(policy.pending(enabled).length == 0, 'Acknowledgment survives ordinary reloads');

    var changed = [{dir: 'neon', contents: '{"title":"Neon 2","metadata":{"photosensitivityWarning":"true"}}'}, enabled[1]];
    expect(policy.pending(changed).length == 1, 'Changed metadata invalidates acknowledgment only for that mod');
    policy.acknowledge(policy.pending(changed));
    expect(policy.pending(changed).length == 0, 'Updated mod can be acknowledged');
    policy.pending([changed[1]]);
    expect(policy.pending(changed).length == 1, 'Disabling then re-enabling a mod requires a new acknowledgment');

    var cases:Array<Null<String>> = [null, '', '{', 'null', 'true', '123', '[]', '"text"', '{}',
      '{"metadata":null}', '{"metadata":[]}', '{"metadata":"true"}',
      '{"photosensitivityWarning":true}', '{"metadata":{"photosensitivityWarning":false}}',
      '{"metadata":{"photosensitivityWarning":"false"}}', '{"metadata":{"photosensitivityWarning":1}}',
      '{"metadata":{"photosensitivityWarning":{}}}', '{"metadata":{"photosensitivityWarning":"yes"}}'];
    for (contents in cases)
      expect(new ModWarningPolicy().pending([{dir: 'plain', contents: contents}]).length == 0, 'Missing or malformed metadata stays optional: $contents');

    var unnamed = policy.pending([{dir: 'fallback', contents: '{"title":{},"metadata":{"photosensitivityWarning":" TRUE "}}'}]);
    expect(unnamed.length == 1 && unnamed[0].title == 'fallback', 'Malformed title falls back to the directory without losing the warning');
    var distinct = [{dir: 'first', contents: flagged}, {dir: 'second', contents: flagged}];
    var separate = new ModWarningPolicy();
    separate.acknowledge(separate.pending([distinct[0]]));
    expect(separate.pending(distinct).length == 1, 'Same metadata in different mod directories is acknowledged separately');
    var defensive = new ModWarningPolicy();
    var original = defensive.pending(enabled);
    original.pop();
    expect(defensive.pending(enabled).length == 2, 'Returned warning arrays cannot mutate the active selection');
    var toggled = new ModWarningPolicy();
    toggled.acknowledge(toggled.pending([enabled[0]]));
    toggled.pending([{dir: 'neon', contents: '{"metadata":{"photosensitivityWarning":"false"}}'}]);
    expect(toggled.pending([enabled[0]]).length == 1, 'Removing then restoring the flag requires acknowledgment again');
    Sys.println('ModWarningPolicyTest passed $checks checks.');
  }
}
