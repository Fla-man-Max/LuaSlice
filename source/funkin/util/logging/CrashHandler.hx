package funkin.util.logging;

import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.FlxG.FlxRenderMethod;
import haxe.io.Path;

/**
 * A custom crash handler that writes to a log file and displays a message box.
 */
@:nullSafety
class CrashHandler
{
  public static final LOG_FOLDER = 'logs';
  static var recoveringEditorCrash:Bool = false;
  static var handlingCrash:Bool = false;

  /**
   * Called before exiting the game when a standard error occurs, like a thrown exception.
   * @param message The error message.
   */
  public static var errorSignal(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  /**
   * Called before exiting the game when a critical error occurs, like a stack overflow or null object reference.
   * CAREFUL: The game may be in an unstable state when this is called.
   * @param message The error message.
   */
  public static var criticalErrorSignal(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  /**
   * Initializes
   */
  public static function initialize():Void
  {
    trace('[LOG] Enabling standard uncaught error handler...');
    Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);

    #if cpp
    trace('[LOG] Enabling C++ critical error handler...');
    untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError);
    #end
  }

  /**
   * Called when an uncaught error occurs.
   * This handles most thrown errors, and is sufficient to handle everything alone on HTML5.
   * @param error Information on the error that was thrown.
   */
  static function onUncaughtError(error:UncaughtErrorEvent):Void
  {
    final message:String = generateErrorMessage(error);

    if (handlingCrash)
    {
      trace('Additional error while handling a crash:\n$message');
      error.preventDefault();
      error.stopImmediatePropagation();
      return;
    }

    handlingCrash = true;

    try
    {
      try
      {
        errorSignal.dispatch(message);
      }
      catch (signalError:Dynamic)
      {
        trace('Error while notifying crash listeners: ${Std.string(signalError)}');
      }

      try
      {
        #if sys
        logErrorMessage(message);
        #end
      }
      catch (e:Dynamic)
      {
        trace('Error while logging error: ' + e);
      }

      if (isRecoverableState() && recoverState(message))
      {
        error.preventDefault();
        error.stopImmediatePropagation();
        return;
      }

      displayErrorMessage(message);
    }
    catch (e:Dynamic)
    {
      trace('Error while handling crash: ' + e);
    }

    #if sys
    Sys.sleep(1); // wait a few moments of margin to process.
    // Exit the game. Since it threw an error, we use a non-zero exit code.
    openfl.Lib.application.window.close();
    #end
  }

  static function onCriticalError(message:String):Void
  {
    if (handlingCrash)
    {
      trace('Additional critical error while handling a crash:\n$message');
      return;
    }

    handlingCrash = true;

    try
    {
      try
      {
        criticalErrorSignal.dispatch(message);
      }
      catch (signalError:Dynamic)
      {
        trace('Error while notifying critical crash listeners: ${Std.string(signalError)}');
      }

      #if sys
      try
      {
        logErrorMessage(message, true);
      }
      catch (logError:Dynamic)
      {
        trace('Error while logging critical error: ${Std.string(logError)}');
      }
      #end

      if (isRecoverableState() && recoverState(message)) return;

      displayErrorMessage(message);
    }
    catch (e:Dynamic)
    {
      trace('Error while handling crash: $e');

      trace('Message: $message');
    }

    #if sys
    Sys.sleep(1); // wait a few moments of margin to process.
    // Exit the game. Since it threw an error, we use a non-zero exit code.
    openfl.Lib.application.window.close();
    #end
  }

  static function displayError(error:UncaughtErrorEvent):Void
  {
    displayErrorMessage(generateErrorMessage(error));
  }

  static function displayErrorMessage(message:String):Void
  {
    funkin.util.WindowUtil.showCrashError("Fatal Uncaught Exception", message);
  }

  static function isRecoverableState():Bool
  {
    if (recoveringEditorCrash || FlxG.game == null || FlxG.state == null) return false;

    final stateClass:Null<Class<Dynamic>> = Type.getClass(FlxG.state);
    if (stateClass == null) return false;

    final stateName:String = Type.getClassName(stateClass) ?? '';
    return stateName.startsWith('funkin.ui.debug.') || stateName.startsWith('funkin.ui.modmenu.') || stateName.startsWith('funkin.ui.options.');
  }

  static function recoverState(message:String):Bool
  {
    recoveringEditorCrash = true;

    try
    {
      final stateClass:Null<Class<Dynamic>> = Type.getClass(FlxG.state);
      final stateName:String = stateClass == null ? 'Editor' : Type.getClassName(stateClass) ?? 'Editor';
      final editorState:Bool = stateName.startsWith('funkin.ui.debug.');
      final title:String = editorState ? 'Editor Crashed' : 'Menu Error';
      final label:String = editorState ? 'editor' : 'menu';
      trace('Crash recovery requested for $stateName:\n$message');
      funkin.util.WindowUtil.showCrashError(title,
        'The $label hit an error, but LuaSlice will keep running.\n\nPress OK to return to the main menu.\n\n$message', message);

      FlxG.sound.music?.stop();
      funkin.util.WindowUtil.setWindowTitle(Constants.TITLE);
      FlxG.signals.postStateSwitch.addOnce(function()
      {
        recoveringEditorCrash = false;
        handlingCrash = false;
      });
      FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
      return true;
    }
    catch (recoveryError:Dynamic)
    {
      trace('Editor crash recovery failed: ${Std.string(recoveryError)}');
      recoveringEditorCrash = false;
      return false;
    }
  }

  #if sys
  static function logError(error:UncaughtErrorEvent):Void
  {
    logErrorMessage(generateErrorMessage(error));
  }

  static function logErrorMessage(message:String, critical:Bool = false):Void
  {
    final report:String = try
    {
      buildCrashReport(message);
    }
    catch (reportError:Dynamic)
    {
      'LuaSlice crash report generation failed: ${Std.string(reportError)}\n\n$message\n';
    };

    final fileName:String = 'crash${critical ? '-critical' : ''}-${DateUtil.generateTimestamp()}.log';
    final candidates:Array<String> = [];

    #if mobile
    final storageDirectory:Null<String> = lime.system.System.applicationStorageDirectory;
    if (storageDirectory != null && storageDirectory.length > 0) candidates.push(Path.join([storageDirectory, LOG_FOLDER]));
    candidates.push(Path.join([Sys.getCwd(), LOG_FOLDER]));
    #else
    candidates.push(Path.join([FileUtil.gameDirectory, LOG_FOLDER]));
    candidates.push(Path.join([Sys.getCwd(), LOG_FOLDER]));
    final storageDirectory:Null<String> = lime.system.System.applicationStorageDirectory;
    if (storageDirectory != null && storageDirectory.length > 0) candidates.push(Path.join([storageDirectory, LOG_FOLDER]));
    #end

    var lastError:Null<Dynamic> = null;
    for (directory in candidates)
    {
      try
      {
        FileUtil.createDirIfNotExists(directory);
        sys.io.File.saveContent(Path.join([directory, fileName]), report);
        return;
      }
      catch (error:Dynamic)
      {
        lastError = error;
      }
    }

    throw 'Could not write crash log: ${Std.string(lastError)}';
  }
  #end

  static function buildCrashReport(message:String):String
  {
    var fullContents:String = '=====================\n';
    fullContents += ' Funkin Crash Report\n';
    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += buildSystemInfo();

    fullContents += '\n\n';

    fullContents += '=====================\n';

    fullContents += '\n';

    var currentState:String = 'No state loaded';
    if (FlxG.game != null && FlxG.state != null)
    {
      var currentStateCls:Null<Class<Dynamic>> = Type.getClass(FlxG.state);
      if (currentStateCls != null)
      {
        currentState = Type.getClassName(currentStateCls) ?? 'No state loaded';
      }
    }

    fullContents += 'Flixel Current State: ${currentState}\n';

    fullContents += '\n';

    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += 'Haxelibs: \n';

    for (lib in Constants.LIBRARY_VERSIONS)
    {
      fullContents += '- ${lib}\n';
    }

    fullContents += '\n';

    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += 'Loaded mods: \n';

    final loadedMods:Array<String> = try
    {
      funkin.modding.PolymodHandler.loadedModIds.copy();
    }
    catch (error:Dynamic)
    {
      [];
    };

    if (loadedMods.length == 0)
    {
      fullContents += 'No mods loaded.\n';
    }
    else
    {
      for (mod in loadedMods)
      {
        fullContents += '- ${mod}\n';
      }
    }

    fullContents += '\n';

    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += message;

    fullContents += '\n';

    return fullContents;
  }

  public static function buildSystemInfo():String
  {
    var fullContents = 'Generated by: ${Constants.GENERATED_BY}\n';
    fullContents += ' Git hash: ${Constants.GIT_HASH} (${Constants.GIT_HAS_LOCAL_CHANGES ? 'MODIFIED' : 'CLEAN'})\n';
    fullContents += 'System timestamp: ${DateUtil.generateTimestamp()}\n';
    var driverInfo:String = try
    {
      FlxG?.stage?.context3D?.driverInfo ?? 'N/A';
    }
    catch (error:Dynamic)
    {
      'N/A';
    };
    fullContents += 'Driver info: ${driverInfo}\n';
    #if android
    fullContents += 'Platform: Android\n';
    #elseif ios
    fullContents += 'Platform: iOS\n';
    #elseif sys
    fullContents += 'Platform: ${Sys.systemName()}\n';
    #end
    fullContents += 'Render method: ${renderMethod()}\n';

    fullContents += '\n';

    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += try
    {
      MemoryUtil.buildGCInfo();
    }
    catch (error:Dynamic)
    {
      'Memory information unavailable: ${Std.string(error)}';
    };

    return fullContents;
  }

  static function generateErrorMessage(error:UncaughtErrorEvent):String
  {
    var errorMessage:String = "";
    var callStack:Array<haxe.CallStack.StackItem> = try
    {
      haxe.CallStack.exceptionStack(true);
    }
    catch (stackError:Dynamic)
    {
      [];
    };

    errorMessage += try
    {
      '${Std.string(error.error)}\n';
    }
    catch (stringError:Dynamic)
    {
      'Unknown error\n';
    };

    for (stackItem in callStack)
    {
      switch (stackItem)
      {
        case FilePos(innerStackItem, file, line, column):
          errorMessage += ' in ${file}#${line}';
          if (column != null) errorMessage += ':${column}';
        case CFunction:
          errorMessage += '[Function] ';
        case Module(m):
          errorMessage += '[Module(${m})] ';
        case Method(classname, method):
          errorMessage += '[Function(${classname}.${method})] ';
        case LocalFunction(v):
          errorMessage += '[LocalFunction(${v})] ';
      }
      errorMessage += '\n';
    }

    return errorMessage;
  }

  public static function queryStatus():Void
  {
    @:privateAccess
    var currentStatus = Lib.current.stage.__uncaughtErrorEvents.__enabled;
    trace('ERROR HANDLER STATUS: ' + currentStatus);

    #if openfl_enable_handle_error
    trace('Define: openfl_enable_handle_error is enabled');
    #else
    trace('Define: openfl_enable_handle_error is disabled');
    #end

    #if openfl_disable_handle_error
    trace('Define: openfl_disable_handle_error is enabled');
    #else
    trace('Define: openfl_disable_handle_error is disabled');
    #end
  }

  public static function induceBasicCrash():Void
  {
    throw "This is an example of an uncaught exception.";
  }

  public static function induceNullObjectReference():Void
  {
    var obj:Dynamic = null;
    var value = obj.test;
  }

  public static function induceNullObjectReference2():Void
  {
    var obj:Dynamic = null;
    var value = obj.test();
  }

  public static function induceNullObjectReference3():Void
  {
    var obj:Dynamic = null;
    var value = obj();
  }

  static function renderMethod():String
  {
    var outputStr:String = 'UNKNOWN';
    outputStr = try
    {
      switch (FlxG.renderMethod)
      {
        case FlxRenderMethod.DRAW_TILES:
          'DRAW_TILES';
        case FlxRenderMethod.BLITTING:
          'BLITTING';
        default:
          'UNKNOWN';
      }
    }
    catch (e)
    {
      'ERROR ON QUERY RENDER METHOD: ${e}';
    }

    return outputStr;
  }
}
