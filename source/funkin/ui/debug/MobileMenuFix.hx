package funkin.ui.debug;

import haxe.ui.containers.menus.Menu;
import haxe.ui.containers.menus.Menu.MenuEvents;
import haxe.ui.containers.menus.MenuBar;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.components.Button;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.Toolkit;

class MobileMenuFix
{
  public static function enable(menuBar:MenuBar):Void
  {
    centerMenuBar(menuBar);
    menuBar.registerEvent(UIEvent.RESIZE, _ -> centerMenuBar(menuBar));

    for (menu in menuBar.findComponents(null, Menu)) enableMenu(menu);
  }

  static function centerMenuBar(menuBar:MenuBar):Void
  {
    Toolkit.callLater(() ->
    {
      if (menuBar == null || @:privateAccess menuBar._isDisposed) return;

      menuBar.syncComponentValidation();
      @:privateAccess final builder:Dynamic = menuBar._compositeBuilder;
      @:privateAccess final buttons:Array<Button> = cast builder._buttons;
      if (buttons == null || buttons.length == 0) return;

      var buttonsWidth:Float = 0;
      var visibleButtons:Int = 0;
      for (button in buttons)
      {
        if (button == null || button.hidden) continue;
        buttonsWidth += button.actualComponentWidth;
        visibleButtons++;
      }

      final spacing:Float = menuBar.style?.horizontalSpacing ?? 0;
      if (visibleButtons > 1) buttonsWidth += spacing * (visibleButtons - 1);
      final targetPadding:Float = Math.max(0, (menuBar.actualComponentWidth - buttonsWidth) / 2);
      if (Math.abs((menuBar.paddingLeft ?? 0) - targetPadding) > 0.5) menuBar.paddingLeft = targetPadding;
    });
  }

  static function enableMenu(menu:Menu):Void
  {
    @:privateAccess final builder:Dynamic = menu._compositeBuilder;
    @:privateAccess final subMenus:Map<MenuItem, Menu> = cast builder._subMenus;

    for (item => subMenu in subMenus)
    {
      #if mobile
      item.registerEvent(MouseEvent.CLICK, (event:MouseEvent) ->
      {
        if (!event.touchEvent) return;

        @:privateAccess final events:MenuEvents = cast menu._internalEvents;
        @:privateAccess events.showSubMenu(subMenu, item);
      });
      #end

      enableMenu(subMenu);
    }
  }
}
