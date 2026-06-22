package funkin.scripting;

#if FEATURE_LUA_SCRIPTS
import funkin.save.Save;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.options.OptionsState;
import funkin.ui.options.OptionsState.OptionsMenu;
import funkin.ui.options.PreferencesMenu;
import haxe.Json;
#end

#if FEATURE_LUA_SCRIPTS
typedef LuaOptionPage =
{
  var id:String;
  var title:String;
  var position:Int;
  var items:Array<LuaOptionItem>;
}

typedef LuaOptionItem =
{
  var kind:String;
  var key:String;
  var label:String;
  var description:String;
  var defaultValue:Dynamic;
  var min:Float;
  var max:Float;
  var step:Float;
  var precision:Int;
  var values:Dynamic;
}
#end

@:access(funkin.ui.Codex)
@:access(funkin.ui.MenuTypedList)
@:access(funkin.ui.options.OptionsState)
@:access(funkin.ui.options.OptionsState.OptionsMenu)
@:access(funkin.ui.options.PreferencesMenu)
@:privateAccess
class LuaOptionManager
{
  #if FEATURE_LUA_SCRIPTS
  static final SAVE_KEY:String = 'LuaSliceLuaOptions';
  var owner:LuaScriptManager;
  var pages:Map<String, LuaOptionPage> = [];

  public function new(owner:LuaScriptManager)
  {
    this.owner = owner;
  }

  public function defineOption(name:String, defaultValue:Dynamic):Dynamic
  {
    if (name == '') return defaultValue;
    var options = getOptionsObject();
    if (!Reflect.hasField(options, name))
    {
      Reflect.setField(options, name, defaultValue);
      Save.instance.setModOptions(SAVE_KEY, options);
    }
    return Reflect.field(options, name);
  }

  public function getOption(name:String, fallback:Dynamic):Dynamic
  {
    if (name == '') return fallback;
    var options = getOptionsObject();
    return Reflect.hasField(options, name) ? Reflect.field(options, name) : fallback;
  }

  public function setOption(name:String, value:Dynamic, flush:Bool):Bool
  {
    if (name == '') return false;
    var options = getOptionsObject();
    Reflect.setField(options, name, value);
    if (flush) Save.instance.setModOptions(SAVE_KEY, options);
    return true;
  }

  public function hasOption(name:String):Bool
  {
    if (name == '') return false;
    return Reflect.hasField(getOptionsObject(), name);
  }

  public function removeOption(name:String, flush:Bool):Bool
  {
    if (name == '') return false;
    var options = getOptionsObject();
    var existed = Reflect.deleteField(options, name);
    if (flush && existed) Save.instance.setModOptions(SAVE_KEY, options);
    return existed;
  }

  public function getOptions():Dynamic
  {
    try
    {
      return Json.parse(Json.stringify(getOptionsObject()));
    }
    catch (e)
    {
      return {};
    }
  }

  public function createPage(id:String, title:String, position:Int = -1):Bool
  {
    if (id == '') return false;
    if (!pages.exists(id)) pages.set(id, {id: id, title: title == '' ? id : title, position: position, items: []});
    else
    {
      pages.get(id).title = title == '' ? id : title;
      pages.get(id).position = position;
    }
    return true;
  }

  public function addCheckbox(pageId:String, key:String, label:String, description:String, defaultValue:Bool):Bool
  {
    var page = getOrCreatePage(pageId);
    if (page == null || key == '') return false;
    defineOption(key, defaultValue);
    upsertItem(page, {
      kind: 'checkbox',
      key: key,
      label: label == '' ? key : label,
      description: description,
      defaultValue: defaultValue,
      min: 0,
      max: 0,
      step: 0,
      precision: 0,
      values: null
    });
    return true;
  }

  public function addNumber(pageId:String, key:String, label:String, description:String, defaultValue:Float, min:Float, max:Float, step:Float,
      precision:Int):Bool
  {
    var page = getOrCreatePage(pageId);
    if (page == null || key == '') return false;
    defineOption(key, defaultValue);
    upsertItem(page, {
      kind: 'number',
      key: key,
      label: label == '' ? key : label,
      description: description,
      defaultValue: defaultValue,
      min: min,
      max: max,
      step: step,
      precision: precision,
      values: null
    });
    return true;
  }

  public function addEnum(pageId:String, key:String, label:String, description:String, values:Dynamic, defaultValue:String):Bool
  {
    var page = getOrCreatePage(pageId);
    if (page == null || key == '') return false;
    defineOption(key, defaultValue);
    upsertItem(page, {
      kind: 'enum',
      key: key,
      label: label == '' ? key : label,
      description: description,
      defaultValue: defaultValue,
      min: 0,
      max: 0,
      step: 0,
      precision: 0,
      values: values
    });
    return true;
  }

  public function attachToOptionsState(optionsState:OptionsState):Void
  {
    if (optionsState == null || pages == null) return;

    var optionsPage:OptionsMenu = cast optionsState.optionsCodex.pages.get(cast 'options');
    if (optionsPage == null) return;

    for (pageId in pages.keys())
    {
      var pageData = pages.get(pageId);
      if (pageData == null || pageData.items.length == 0 || isReservedPageId(pageId)) continue;
      if (optionsState.optionsCodex.pages.exists(cast pageId)) continue;

      var menuPage:PreferencesMenu = optionsState.optionsCodex.addPage(cast pageId, new PreferencesMenu());
      menuPage.onExit.add(function() optionsState.optionsCodex.switchPage(cast 'options'));
      clearPreferencesPage(menuPage);

      var rootItem = optionsPage.addLuaOptionsItem(pageData.title, function() optionsState.optionsCodex.switchPage(cast pageId));
      if (pageData.position < 0) insertBeforeExit(optionsPage, rootItem);
      else optionsPage.moveLuaOptionsItemToPosition(rootItem, pageData.position);

      for (item in pageData.items)
      {
        switch (item.kind)
        {
          case 'checkbox':
            menuPage.createPrefItemCheckbox(item.label, item.description, function(value:Bool):Void
            {
              setOption(item.key, value, true);
              owner.callHook('onLuaOptionChanged', [pageData.id, item.key, value]);
            }, getOption(item.key, item.defaultValue) == true);
          case 'number':
            menuPage.createPrefItemNumber(item.label, item.description, function(value:Float):Void
            {
              setOption(item.key, value, true);
              owner.callHook('onLuaOptionChanged', [pageData.id, item.key, value]);
            }, null, Std.parseFloat(Std.string(getOption(item.key, item.defaultValue))), item.min, item.max, item.step, item.precision);
          case 'enum':
            var enumValues = makeEnumValues(item.values);
            menuPage.createPrefItemEnum(item.label, item.description, enumValues, function(label:String, value:Dynamic):Void
            {
              setOption(item.key, value, true);
              owner.callHook('onLuaOptionChanged', [pageData.id, item.key, value]);
            }, findEnumLabel(enumValues, getOption(item.key, item.defaultValue)));
          default:
        }
      }

      menuPage.createPrefDescription();
    }

    repositionOptions(optionsPage);
  }

  function isReservedPageId(pageId:String):Bool
  {
    var key = pageId.toLowerCase();
    return key == 'options' || key == 'controls' || key == 'preferences' || key == 'offsets' || key == 'savedata' || key == 'colors' || key == 'mods';
  }
  function getOptionsObject():Dynamic
  {
    return Save.instance.getModOptions(SAVE_KEY);
  }

  function getOrCreatePage(id:String):Null<LuaOptionPage>
  {
    if (id == '') return null;
    if (!pages.exists(id)) createPage(id, id, -1);
    return pages.get(id);
  }

  function upsertItem(page:LuaOptionPage, item:LuaOptionItem):Void
  {
    for (i in 0...page.items.length)
    {
      if (page.items[i].key == item.key)
      {
        page.items[i] = item;
        return;
      }
    }
    page.items.push(item);
  }

  function clearPreferencesPage(page:PreferencesMenu):Void
  {
    page.preferenceDesc = [];
    page.items.clear();
    page.preferenceItems.clear();
    if (page.itemDesc != null) page.itemDesc.text = '';
  }

  function insertBeforeExit(optionsPage:OptionsMenu, item:TextMenuItem):Void
  {
    optionsPage.moveLuaOptionsItemBefore(item, 'EXIT');
  }

  function repositionOptions(optionsPage:OptionsMenu):Void
  {
    optionsPage.repositionLuaOptionsItems();
  }

  function makeEnumValues(values:Dynamic):Map<String, Dynamic>
  {
    var result:Map<String, Dynamic> = [];
    if (Std.isOfType(values, Array))
    {
      for (value in (cast values : Array<Dynamic>)) result.set(Std.string(value), value);
      return result;
    }

    if (values != null)
    {
      for (field in Reflect.fields(values)) result.set(field, Reflect.field(values, field));
    }

    return result;
  }

  function findEnumLabel(values:Map<String, Dynamic>, savedValue:Dynamic):String
  {
    var fallback = '';
    for (label in values.keys())
    {
      if (fallback == '') fallback = label;
      if (Std.string(values.get(label)) == Std.string(savedValue)) return label;
    }
    return fallback;
  }
  #end
}
