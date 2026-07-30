package funkin.ui.debug.stageeditor.handlers;

#if FEATURE_STAGE_EDITOR
import funkin.data.stage.StageRegistry;
import funkin.util.FileUtil;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.xml.Printer;

using StringTools;

class StageFormatConverter
{
  public static final BASE:String = "base";
  public static final PSYCH:String = "psych";
  public static final CODENAME:String = "codename";

  static final BASE_BF:Array<Float> = [989.5, 885];
  static final BASE_GF:Array<Float> = [751.5, 787];
  static final BASE_DAD:Array<Float> = [335, 885];
  static final EXTERNAL_BF:Array<Float> = [770, 100];
  static final EXTERNAL_GF:Array<Float> = [400, 130];
  static final EXTERNAL_DAD:Array<Float> = [100, 100];

  public static function validateSource(engine:String, input:Bytes, fileName:String):Null<String>
  {
    var extension = Path.extension(fileName).toLowerCase();
    var validExtension = switch (engine)
    {
      case BASE: extension == "fnfs" || extension == "json";
      case PSYCH: extension == "json";
      case CODENAME: extension == "xml";
      default: false;
    };
    if (!validExtension) return 'The selected file is not a ${engineLabel(engine)} stage. Choose a ${expectedExtension(engine)} file.';

    try
    {
      switch (engine)
      {
        case BASE:
          parseBase(input, fileName);
        case PSYCH:
          parsePsych(input, fileName);
        case CODENAME:
          parseCodename(input, fileName);
        default:
          return "The selected source engine is not supported.";
      }
    }
    catch (error:Dynamic)
    {
      return 'The selected file is not a valid ${engineLabel(engine)} stage. ${Std.string(error)}';
    }
    return null;
  }

  public static function convert(sourceEngine:String, targetEngine:String, input:Bytes, fileName:String):StageConversionResult
  {
    if (sourceEngine == targetEngine) throw "Choose two different engine formats.";
    var data = switch (sourceEngine)
    {
      case BASE: parseBase(input, fileName);
      case PSYCH: parsePsych(input, fileName);
      case CODENAME: parseCodename(input, fileName);
      default: throw 'Unsupported source engine "$sourceEngine".';
    };
    var result = switch (targetEngine)
    {
      case BASE: writeBase(data);
      case PSYCH: writePsych(data);
      case CODENAME: writeCodename(data);
      default: throw 'Unsupported target engine "$targetEngine".';
    };
    result.warnings = uniqueWarnings(data.warnings.concat(result.warnings));
    return result;
  }

  static function parseBase(input:Bytes, fileName:String):StageConversionData
  {
    var raw:Dynamic = null;
    if (isZip(input))
    {
      for (entry in FileUtil.readZIPFromBytes(input))
      {
        if (Path.extension(entry.fileName).toLowerCase() != "json") continue;
        var candidate:Dynamic = Json.parse(entry.data.toString());
        if (Reflect.hasField(candidate, "props") && Reflect.hasField(candidate, "characters"))
        {
          raw = candidate;
          break;
        }
      }
      if (raw == null) throw "The Base Game stage package does not contain a stage JSON file.";
    }
    else
    {
      raw = Json.parse(input.toString());
    }
    if (raw == null || !Reflect.hasField(raw, "props") || !Reflect.hasField(raw, "characters"))
      throw "Missing Base Game props or characters data.";

    var data = makeData(readString(raw, "name", fileStem(fileName)));
    data.directory = readString(raw, "directory", "shared");
    data.cameraZoom = readFloat(raw, "cameraZoom", 1);
    var rawProps = readArray(raw, "props");
    for (index in 0...rawProps.length)
    {
      var prop = rawProps[index];
      var position = readPair(Reflect.field(prop, "position"), 0, 0);
      var scale = readScale(Reflect.field(prop, "scale"));
      var scroll = readPair(Reflect.field(prop, "scroll"), 1, 1);
      data.props.push({
        name: readString(prop, "name", 'prop${index + 1}'),
        assetPath: readString(prop, "assetPath", "#FFFFFF"),
        x: position[0],
        y: position[1],
        zIndex: readInt(prop, "zIndex", index * 10),
        isPixel: readBool(prop, "isPixel", false),
        scaleX: scale[0],
        scaleY: scale[1],
        alpha: readFloat(prop, "alpha", 1),
        danceEvery: readFloat(prop, "danceEvery", 0),
        scrollX: scroll[0],
        scrollY: scroll[1],
        flipX: readBool(prop, "flipX", false),
        flipY: readBool(prop, "flipY", false),
        angle: readFloat(prop, "angle", 0),
        color: readColor(Reflect.field(prop, "color"), "#FFFFFF"),
        animations: parseBaseAnimations(readArray(prop, "animations")),
        startingAnimation: readNullableString(prop, "startingAnimation")
      });
    }

    var characters = Reflect.field(raw, "characters");
    if (characters != null)
    {
      data.bf = parseBaseCharacter(Reflect.field(characters, "bf"), data.bf);
      data.gf = parseBaseCharacter(Reflect.field(characters, "gf"), data.gf);
      data.dad = parseBaseCharacter(Reflect.field(characters, "dad"), data.dad);
    }
    return data;
  }

  static function parsePsych(input:Bytes, fileName:String):StageConversionData
  {
    var raw:Dynamic = Json.parse(input.toString());
    if (raw == null
      || !Reflect.hasField(raw, "defaultZoom")
      || !Reflect.hasField(raw, "boyfriend")
      || !Reflect.hasField(raw, "girlfriend")
      || !Reflect.hasField(raw, "opponent"))
      throw "Missing Psych Engine zoom or character-position data.";
    var data = makeData(readString(raw, "name", fileStem(fileName)));
    data.directory = readString(raw, "directory", "");
    data.cameraZoom = readFloat(raw, "defaultZoom", 0.9);
    data.bf = parseExternalCharacter(Reflect.field(raw, "boyfriend"), BASE_BF, EXTERNAL_BF, data.bf);
    data.gf = parseExternalCharacter(Reflect.field(raw, "girlfriend"), BASE_GF, EXTERNAL_GF, data.gf);
    data.dad = parseExternalCharacter(Reflect.field(raw, "opponent"), BASE_DAD, EXTERNAL_DAD, data.dad);
    applyCamera(data.bf, Reflect.field(raw, "camera_boyfriend"));
    applyCamera(data.gf, Reflect.field(raw, "camera_girlfriend"));
    applyCamera(data.dad, Reflect.field(raw, "camera_opponent"));

    var objects = readArray(raw, "objects");
    if (objects.length == 0) data.warnings.push("This Psych stage has no editor objects. Objects created only by Haxe or Lua scripts cannot be converted.");
    for (index in 0...objects.length)
    {
      var object = objects[index];
      var type = readString(object, "type", "sprite").toLowerCase();
      var zIndex = (index + 1) * 10;
      switch (type)
      {
        case "boyfriend" | "bf" | "player":
          data.bf = applyPsychCharacterObject(object, data.bf, BASE_BF, EXTERNAL_BF, zIndex);
        case "girlfriend" | "gf":
          data.gf = applyPsychCharacterObject(object, data.gf, BASE_GF, EXTERNAL_GF, zIndex);
        case "dad" | "opponent":
          data.dad = applyPsychCharacterObject(object, data.dad, BASE_DAD, EXTERNAL_DAD, zIndex);
        case "sprite" | "animatedsprite" | "square" | "solid":
          data.props.push(parsePsychProp(object, index, type, zIndex));
        default:
          data.warnings.push('Psych object type "$type" is not supported and was skipped.');
      }
    }
    if (readBool(raw, "hide_girlfriend", false)) data.gf.alpha = 0;
    return data;
  }

  static function parseCodename(input:Bytes, fileName:String):StageConversionData
  {
    var document = Xml.parse(input.toString());
    var root:Xml = null;
    for (element in document.elements())
    {
      if (element.nodeName.toLowerCase() == "stage")
      {
        root = element;
        break;
      }
    }
    if (root == null) throw "The Codename Engine XML does not contain a stage root element.";

    var data = makeData(xmlString(root, "name", fileStem(fileName)));
    data.cameraZoom = xmlFloat(root, "zoom", 0.9);
    data.codenameFolder = xmlString(root, "folder", "");
    data.directory = "shared";
    var zIndex = 10;
    var propIndex = 0;
    for (node in root.elements())
    {
      var type = node.nodeName.toLowerCase();
      switch (type)
      {
        case "boyfriend" | "bf" | "player":
          data.bf = parseCodenameCharacter(node, data.bf, BASE_BF, EXTERNAL_BF, zIndex);
        case "girlfriend" | "gf":
          data.gf = parseCodenameCharacter(node, data.gf, BASE_GF, EXTERNAL_GF, zIndex);
        case "dad" | "opponent":
          data.dad = parseCodenameCharacter(node, data.dad, BASE_DAD, EXTERNAL_DAD, zIndex);
        case "sprite" | "spr" | "sparrow":
          data.props.push(parseCodenameSprite(node, data.codenameFolder, propIndex++, zIndex));
        case "box" | "solid":
          data.props.push(parseCodenameBox(node, propIndex++, zIndex));
        default:
          data.warnings.push('Codename node "$type" is not supported and was skipped.');
      }
      zIndex += 10;
    }
    return data;
  }

  static function writeBase(data:StageConversionData):StageConversionResult
  {
    var props:Array<Dynamic> = [];
    for (prop in data.props)
    {
      var outputScale:Dynamic = prop.scaleX == prop.scaleY ? prop.scaleX : [prop.scaleX, prop.scaleY];
      props.push({
        name: prop.name,
        assetPath: prop.assetPath,
        position: [prop.x, prop.y],
        zIndex: prop.zIndex,
        isPixel: prop.isPixel,
        flipX: prop.flipX,
        flipY: prop.flipY,
        scale: outputScale,
        alpha: prop.alpha,
        danceEvery: prop.danceEvery,
        scroll: [prop.scrollX, prop.scrollY],
        animations: writeBaseAnimations(prop.animations),
        startingAnimation: prop.startingAnimation,
        animType: "sparrow",
        angle: prop.angle,
        blend: "",
        color: prop.color
      });
    }
    var output:Dynamic = {
      version: StageRegistry.STAGE_DATA_VERSION,
      name: data.name,
      props: props,
      characters: {
        bf: writeBaseCharacter(data.bf),
        dad: writeBaseCharacter(data.dad),
        gf: writeBaseCharacter(data.gf)
      },
      cameraZoom: data.cameraZoom,
      directory: data.directory == "" ? "shared" : data.directory
    };
    var id = safeName(data.name);
    var zip = FileUtil.createZIPFromEntries([FileUtil.makeZIPEntry('$id.json', Json.stringify(output, null, "  "))]);
    return {
      bytes: zip,
      extension: "fnfs",
      defaultFileName: '$id.fnfs',
      warnings: ["The Base Game package contains layout data only. Copy the referenced stage images and animation XML files separately."]
    };
  }

  static function writePsych(data:StageConversionData):StageConversionResult
  {
    var pixel = hasPixelProps(data);
    var output:Dynamic = {
      directory: data.directory == "shared" ? "" : data.directory,
      defaultZoom: data.cameraZoom,
      isPixelStage: pixel,
      stageUI: pixel ? "pixel" : "normal",
      boyfriend: toExternalPosition(data.bf, BASE_BF, EXTERNAL_BF),
      girlfriend: toExternalPosition(data.gf, BASE_GF, EXTERNAL_GF),
      opponent: toExternalPosition(data.dad, BASE_DAD, EXTERNAL_DAD),
      hide_girlfriend: data.gf.alpha <= 0,
      camera_boyfriend: [data.bf.cameraX, data.bf.cameraY],
      camera_girlfriend: [data.gf.cameraX, data.gf.cameraY],
      camera_opponent: [data.dad.cameraX, data.dad.cameraY],
      camera_speed: 1,
      objects: writePsychObjects(data)
    };
    var id = safeName(data.name);
    return {
      bytes: Bytes.ofString(Json.stringify(output, null, "  ")),
      extension: "json",
      defaultFileName: '$id.json',
      warnings: ["Psych Engine scripts, shaders, filters, and custom object classes are not generated."]
    };
  }

  static function writeCodename(data:StageConversionData):StageConversionResult
  {
    var root = Xml.createElement("stage");
    root.set("zoom", numberString(data.cameraZoom));
    root.set("name", data.name);
    if (data.codenameFolder != "") root.set("folder", data.codenameFolder);
    for (item in orderedItems(data))
    {
      if (item.kind == "prop")
      {
        root.addChild(writeCodenameProp(cast item.value, data.codenameFolder));
      }
      else
      {
        var base = item.kind == "boyfriend" ? BASE_BF : item.kind == "girlfriend" ? BASE_GF : BASE_DAD;
        var external = item.kind == "boyfriend" ? EXTERNAL_BF : item.kind == "girlfriend" ? EXTERNAL_GF : EXTERNAL_DAD;
        root.addChild(writeCodenameCharacter(item.kind, cast item.value, base, external));
      }
    }
    var id = safeName(data.name);
    var xml = '<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE codename-engine-stage>\n' + Printer.print(root, true);
    return {
      bytes: Bytes.ofString(xml),
      extension: "xml",
      defaultFileName: '$id.xml',
      warnings: ["Codename Engine scripts, shaders, blend modes, and custom XML nodes are not generated."]
    };
  }

  static function parsePsychProp(raw:Dynamic, index:Int, type:String, zIndex:Int):StageConversionProp
  {
    var scale = readScale(Reflect.field(raw, "scale"));
    var scroll = readPair(Reflect.field(raw, "scroll"), 1, 1);
    var solid = type == "square" || type == "solid";
    var animations:Array<StageConversionAnimation> = [];
    for (animation in readArray(raw, "animations"))
    {
      animations.push({
        name: readString(animation, "name", readString(animation, "anim", "idle")),
        prefix: readString(animation, "anim", readString(animation, "name", "idle")),
        offsets: readPair(Reflect.field(animation, "offsets"), 0, 0),
        looped: readBool(animation, "loop", false),
        frameRate: readInt(animation, "fps", 24),
        frameIndices: readIntArray(Reflect.field(animation, "indices")),
        flipX: false,
        flipY: false
      });
    }
    var color = readColor(Reflect.field(raw, "color"), "#FFFFFF");
    return {
      name: readString(raw, "name", 'prop${index + 1}'),
      assetPath: solid ? color : readString(raw, "image", "#FFFFFF"),
      x: readFloat(raw, "x", 0),
      y: readFloat(raw, "y", 0),
      zIndex: zIndex,
      isPixel: !readBool(raw, "antialiasing", true),
      scaleX: solid ? readFloat(raw, "width", scale[0]) : scale[0],
      scaleY: solid ? readFloat(raw, "height", scale[1]) : scale[1],
      alpha: readFloat(raw, "alpha", 1),
      danceEvery: 0,
      scrollX: scroll[0],
      scrollY: scroll[1],
      flipX: readBool(raw, "flipX", false),
      flipY: readBool(raw, "flipY", false),
      angle: readFloat(raw, "angle", 0),
      color: solid ? "#FFFFFF" : color,
      animations: animations,
      startingAnimation: readNullableString(raw, "firstAnimation")
    };
  }

  static function parseCodenameSprite(node:Xml, folder:String, index:Int, zIndex:Int):StageConversionProp
  {
    var animations:Array<StageConversionAnimation> = [];
    for (animation in node.elementsNamed("anim"))
    {
      animations.push({
        name: xmlString(animation, "name", xmlString(animation, "anim", "idle")),
        prefix: xmlString(animation, "anim", xmlString(animation, "name", "idle")),
        offsets: [xmlFloat(animation, "x", 0), xmlFloat(animation, "y", 0)],
        looped: xmlBool(animation, "loop", false),
        frameRate: Std.int(xmlFloat(animation, "fps", 24)),
        frameIndices: parseIndices(xmlString(animation, "indices", "")),
        flipX: false,
        flipY: false
      });
    }
    var uniformScale = xmlFloat(node, "scale", 1);
    var assetPath = xmlString(node, "sprite", xmlString(node, "image", "#FFFFFF"));
    if (folder != "" && !assetPath.startsWith(folder)) assetPath = folder + assetPath;
    return {
      name: xmlString(node, "name", 'prop${index + 1}'),
      assetPath: assetPath,
      x: xmlFloat(node, "x", 0),
      y: xmlFloat(node, "y", 0),
      zIndex: zIndex,
      isPixel: !xmlBool(node, "antialiasing", true),
      scaleX: xmlFloat(node, "scalex", uniformScale),
      scaleY: xmlFloat(node, "scaley", uniformScale),
      alpha: xmlFloat(node, "alpha", 1),
      danceEvery: xmlFloat(node, "beatInterval", 0),
      scrollX: xmlFloat(node, "scrollx", xmlFloat(node, "scroll", 1)),
      scrollY: xmlFloat(node, "scrolly", xmlFloat(node, "scroll", 1)),
      flipX: xmlBool(node, "flipX", false),
      flipY: xmlBool(node, "flipY", false),
      angle: xmlFloat(node, "angle", 0),
      color: readColor(node.get("color"), "#FFFFFF"),
      animations: animations,
      startingAnimation: animations.length == 0 ? null : animations[0].name
    };
  }

  static function parseCodenameBox(node:Xml, index:Int, zIndex:Int):StageConversionProp
  {
    return {
      name: xmlString(node, "name", 'box${index + 1}'),
      assetPath: readColor(node.get("color"), "#FFFFFF"),
      x: xmlFloat(node, "x", 0),
      y: xmlFloat(node, "y", 0),
      zIndex: zIndex,
      isPixel: false,
      scaleX: xmlFloat(node, "width", 100),
      scaleY: xmlFloat(node, "height", 100),
      alpha: xmlFloat(node, "alpha", 1),
      danceEvery: 0,
      scrollX: xmlFloat(node, "scrollx", xmlFloat(node, "scroll", 1)),
      scrollY: xmlFloat(node, "scrolly", xmlFloat(node, "scroll", 1)),
      flipX: false,
      flipY: false,
      angle: xmlFloat(node, "angle", 0),
      color: "#FFFFFF",
      animations: [],
      startingAnimation: null
    };
  }

  static function writePsychObjects(data:StageConversionData):Array<Dynamic>
  {
    var result:Array<Dynamic> = [];
    for (item in orderedItems(data))
    {
      if (item.kind == "prop")
      {
        var prop:StageConversionProp = cast item.value;
        var solid = prop.assetPath.startsWith("#");
        var object:Dynamic = {
          type: solid ? "square" : prop.animations.length > 0 ? "animatedSprite" : "sprite",
          name: prop.name,
          x: prop.x,
          y: prop.y,
          scale: [prop.scaleX, prop.scaleY],
          scroll: [prop.scrollX, prop.scrollY],
          alpha: prop.alpha,
          angle: prop.angle,
          color: solid ? prop.assetPath.substring(1) : prop.color.substring(1),
          antialiasing: !prop.isPixel,
          flipX: prop.flipX,
          flipY: prop.flipY
        };
        if (solid)
        {
          Reflect.setField(object, "width", prop.scaleX);
          Reflect.setField(object, "height", prop.scaleY);
        }
        else
        {
          Reflect.setField(object, "image", prop.assetPath);
        }
        if (prop.animations.length > 0)
        {
          Reflect.setField(object, "animations", writePsychAnimations(prop.animations));
          Reflect.setField(object, "firstAnimation", prop.startingAnimation ?? prop.animations[0].name);
        }
        result.push(object);
      }
      else
      {
        var character:StageConversionCharacter = cast item.value;
        var base = item.kind == "boyfriend" ? BASE_BF : item.kind == "girlfriend" ? BASE_GF : BASE_DAD;
        var external = item.kind == "boyfriend" ? EXTERNAL_BF : item.kind == "girlfriend" ? EXTERNAL_GF : EXTERNAL_DAD;
        var position = toExternalPosition(character, base, external);
        result.push({
          type: item.kind,
          name: item.kind,
          x: position[0],
          y: position[1],
          scale: [character.scale, character.scale],
          scroll: [character.scrollX, character.scrollY],
          alpha: character.alpha,
          angle: character.angle
        });
      }
    }
    return result;
  }

  static function writeCodenameProp(prop:StageConversionProp, folder:String):Xml
  {
    if (prop.assetPath.startsWith("#"))
    {
      var box = Xml.createElement("box");
      box.set("name", prop.name);
      box.set("x", numberString(prop.x));
      box.set("y", numberString(prop.y));
      box.set("width", numberString(prop.scaleX));
      box.set("height", numberString(prop.scaleY));
      box.set("color", prop.assetPath);
      setCommonCodenameAttributes(box, prop);
      return box;
    }
    var sprite = Xml.createElement("sprite");
    sprite.set("name", prop.name);
    sprite.set("x", numberString(prop.x));
    sprite.set("y", numberString(prop.y));
    sprite.set("sprite", folder != "" && prop.assetPath.startsWith(folder) ? prop.assetPath.substring(folder.length) : prop.assetPath);
    if (prop.scaleX == prop.scaleY)
      setNumberIfChanged(sprite, "scale", prop.scaleX, 1);
    else
    {
      setNumberIfChanged(sprite, "scalex", prop.scaleX, 1);
      setNumberIfChanged(sprite, "scaley", prop.scaleY, 1);
    }
    setCommonCodenameAttributes(sprite, prop);
    if (prop.isPixel) sprite.set("antialiasing", "false");
    if (prop.flipX) sprite.set("flipX", "true");
    if (prop.flipY) sprite.set("flipY", "true");
    if (prop.danceEvery != 0) sprite.set("beatInterval", numberString(prop.danceEvery));
    if (prop.color != "#FFFFFF") sprite.set("color", prop.color);
    for (animation in prop.animations)
    {
      var node = Xml.createElement("anim");
      node.set("name", animation.name);
      node.set("anim", animation.prefix);
      setNumberIfChanged(node, "fps", animation.frameRate, 24);
      if (animation.looped) node.set("loop", "true");
      if (animation.offsets[0] != 0) node.set("x", numberString(animation.offsets[0]));
      if (animation.offsets[1] != 0) node.set("y", numberString(animation.offsets[1]));
      if (animation.frameIndices.length > 0) node.set("indices", animation.frameIndices.join(","));
      sprite.addChild(node);
    }
    return sprite;
  }

  static function setCommonCodenameAttributes(node:Xml, prop:StageConversionProp):Void
  {
    if (prop.scrollX == prop.scrollY)
      setNumberIfChanged(node, "scroll", prop.scrollX, 1);
    else
    {
      setNumberIfChanged(node, "scrollx", prop.scrollX, 1);
      setNumberIfChanged(node, "scrolly", prop.scrollY, 1);
    }
    setNumberIfChanged(node, "alpha", prop.alpha, 1);
    setNumberIfChanged(node, "angle", prop.angle, 0);
  }

  static function writeCodenameCharacter(kind:String, character:StageConversionCharacter, base:Array<Float>, external:Array<Float>):Xml
  {
    var node = Xml.createElement(kind);
    var position = toExternalPosition(character, base, external);
    node.set("x", numberString(position[0]));
    node.set("y", numberString(position[1]));
    setNumberIfChanged(node, "scale", character.scale, 1);
    if (character.scrollX == character.scrollY)
      setNumberIfChanged(node, "scroll", character.scrollX, 1);
    else
    {
      setNumberIfChanged(node, "scrollx", character.scrollX, 1);
      setNumberIfChanged(node, "scrolly", character.scrollY, 1);
    }
    setNumberIfChanged(node, "alpha", character.alpha, 1);
    setNumberIfChanged(node, "angle", character.angle, 0);
    if (character.cameraX != 0) node.set("camxoffset", numberString(character.cameraX));
    if (character.cameraY != 0) node.set("camyoffset", numberString(character.cameraY));
    return node;
  }

  static function orderedItems(data:StageConversionData):Array<Dynamic>
  {
    var result:Array<Dynamic> = [];
    for (prop in data.props)
      result.push({z: prop.zIndex, kind: "prop", value: prop});
    result.push({z: data.gf.zIndex, kind: "girlfriend", value: data.gf});
    result.push({z: data.dad.zIndex, kind: "dad", value: data.dad});
    result.push({z: data.bf.zIndex, kind: "boyfriend", value: data.bf});
    result.sort(function(a, b) return a.z == b.z ? 0 : a.z < b.z ? -1 : 1);
    return result;
  }

  static function makeData(name:String):StageConversionData
  {
    return {
      name: name == "" ? "Unnamed" : name,
      directory: "shared",
      codenameFolder: "",
      cameraZoom: 1,
      props: [],
      bf: makeCharacter(BASE_BF, 300, -100, -100),
      gf: makeCharacter(BASE_GF, 100, 0, 0),
      dad: makeCharacter(BASE_DAD, 200, 150, -100),
      warnings: []
    };
  }

  static function makeCharacter(position:Array<Float>, zIndex:Int, cameraX:Float, cameraY:Float):StageConversionCharacter
  {
    return {
      x: position[0],
      y: position[1],
      zIndex: zIndex,
      scale: 1,
      cameraX: cameraX,
      cameraY: cameraY,
      scrollX: 1,
      scrollY: 1,
      alpha: 1,
      angle: 0
    };
  }

  static function parseBaseCharacter(raw:Dynamic, fallback:StageConversionCharacter):StageConversionCharacter
  {
    if (raw == null) return fallback;
    var position = readPair(Reflect.field(raw, "position"), fallback.x, fallback.y);
    var camera = readPair(Reflect.field(raw, "cameraOffsets"), fallback.cameraX, fallback.cameraY);
    var scroll = readPair(Reflect.field(raw, "scroll"), 1, 1);
    return {
      x: position[0],
      y: position[1],
      zIndex: readInt(raw, "zIndex", fallback.zIndex),
      scale: readFloat(raw, "scale", 1),
      cameraX: camera[0],
      cameraY: camera[1],
      scrollX: scroll[0],
      scrollY: scroll[1],
      alpha: readFloat(raw, "alpha", 1),
      angle: readFloat(raw, "angle", 0)
    };
  }

  static function parseExternalCharacter(raw:Dynamic, base:Array<Float>, external:Array<Float>, fallback:StageConversionCharacter):StageConversionCharacter
  {
    var position = readPair(raw, external[0], external[1]);
    fallback.x = base[0] + position[0] - external[0];
    fallback.y = base[1] + position[1] - external[1];
    return fallback;
  }

  static function applyCamera(character:StageConversionCharacter, raw:Dynamic):Void
  {
    var camera = readPair(raw, 0, 0);
    character.cameraX = camera[0];
    character.cameraY = camera[1];
  }

  static function applyPsychCharacterObject(raw:Dynamic, fallback:StageConversionCharacter, base:Array<Float>, external:Array<Float>,
      zIndex:Int):StageConversionCharacter
  {
    fallback.x = base[0] + readFloat(raw, "x", external[0]) - external[0];
    fallback.y = base[1] + readFloat(raw, "y", external[1]) - external[1];
    fallback.zIndex = zIndex;
    fallback.scale = readScale(Reflect.field(raw, "scale"))[0];
    var scroll = readPair(Reflect.field(raw, "scroll"), 1, 1);
    fallback.scrollX = scroll[0];
    fallback.scrollY = scroll[1];
    fallback.alpha = readFloat(raw, "alpha", fallback.alpha);
    fallback.angle = readFloat(raw, "angle", fallback.angle);
    return fallback;
  }

  static function parseCodenameCharacter(node:Xml, fallback:StageConversionCharacter, base:Array<Float>, external:Array<Float>,
      zIndex:Int):StageConversionCharacter
  {
    fallback.x = base[0] + xmlFloat(node, "x", external[0]) - external[0];
    fallback.y = base[1] + xmlFloat(node, "y", external[1]) - external[1];
    fallback.zIndex = zIndex;
    fallback.scale = xmlFloat(node, "scale", 1);
    fallback.cameraX = xmlFloat(node, "camxoffset", fallback.cameraX);
    fallback.cameraY = xmlFloat(node, "camyoffset", fallback.cameraY);
    fallback.scrollX = xmlFloat(node, "scrollx", xmlFloat(node, "scroll", 1));
    fallback.scrollY = xmlFloat(node, "scrolly", xmlFloat(node, "scroll", 1));
    fallback.alpha = xmlFloat(node, "alpha", 1);
    fallback.angle = xmlFloat(node, "angle", 0);
    return fallback;
  }

  static function writeBaseCharacter(character:StageConversionCharacter):Dynamic
  {
    return {
      zIndex: character.zIndex,
      position: [character.x, character.y],
      scale: character.scale,
      cameraOffsets: [character.cameraX, character.cameraY],
      scroll: [character.scrollX, character.scrollY],
      alpha: character.alpha,
      angle: character.angle
    };
  }

  static function toExternalPosition(character:StageConversionCharacter, base:Array<Float>, external:Array<Float>):Array<Float>
  {
    return [external[0] + character.x - base[0], external[1] + character.y - base[1]];
  }

  static function parseBaseAnimations(raw:Array<Dynamic>):Array<StageConversionAnimation>
  {
    var result:Array<StageConversionAnimation> = [];
    for (animation in raw)
    {
      result.push({
        name: readString(animation, "name", "idle"),
        prefix: readString(animation, "prefix", readString(animation, "name", "idle")),
        offsets: readPair(Reflect.field(animation, "offsets"), 0, 0),
        looped: readBool(animation, "looped", false),
        frameRate: readInt(animation, "frameRate", 24),
        frameIndices: readIntArray(Reflect.field(animation, "frameIndices")),
        flipX: readBool(animation, "flipX", false),
        flipY: readBool(animation, "flipY", false)
      });
    }
    return result;
  }

  static function writeBaseAnimations(animations:Array<StageConversionAnimation>):Array<Dynamic>
  {
    return [for (animation in animations) {
      name: animation.name,
      prefix: animation.prefix,
      offsets: animation.offsets,
      looped: animation.looped,
      frameRate: animation.frameRate,
      frameIndices: animation.frameIndices,
      flipX: animation.flipX,
      flipY: animation.flipY
    }];
  }

  static function writePsychAnimations(animations:Array<StageConversionAnimation>):Array<Dynamic>
  {
    return [for (animation in animations) {
      anim: animation.prefix,
      name: animation.name,
      fps: animation.frameRate,
      loop: animation.looped,
      indices: animation.frameIndices,
      offsets: animation.offsets
    }];
  }

  static function hasPixelProps(data:StageConversionData):Bool
  {
    for (prop in data.props)
      if (prop.isPixel) return true;
    return false;
  }

  static function engineLabel(engine:String):String
  {
    return switch (engine)
    {
      case BASE: "Base Game";
      case PSYCH: "Psych Engine v1.0.4";
      case CODENAME: "Codename Engine";
      default: engine;
    };
  }

  static function expectedExtension(engine:String):String
  {
    return switch (engine)
    {
      case BASE: ".fnfs or Base Game .json";
      case PSYCH: "Psych Engine .json";
      case CODENAME: "Codename Engine .xml";
      default: "supported stage";
    };
  }

  static function fileStem(fileName:String):String
  {
    return Path.withoutExtension(Path.withoutDirectory(fileName));
  }

  static function isZip(bytes:Bytes):Bool
  {
    return bytes != null && bytes.length >= 2 && bytes.get(0) == 0x50 && bytes.get(1) == 0x4B;
  }

  static function readArray(data:Dynamic, field:String):Array<Dynamic>
  {
    if (data == null) return [];
    var value = Reflect.field(data, field);
    return Std.isOfType(value, Array) ? cast value : [];
  }

  static function readPair(value:Dynamic, fallbackX:Float, fallbackY:Float):Array<Float>
  {
    if (!Std.isOfType(value, Array)) return [fallbackX, fallbackY];
    var values:Array<Dynamic> = cast value;
    return [
      readDynamicFloat(values.length > 0 ? values[0] : null, fallbackX),
      readDynamicFloat(values.length > 1 ? values[1] : null, fallbackY)
    ];
  }

  static function readScale(value:Dynamic):Array<Float>
  {
    if (Std.isOfType(value, Array)) return readPair(value, 1, 1);
    var scale = readDynamicFloat(value, 1);
    return [scale, scale];
  }

  static function readIntArray(value:Dynamic):Array<Int>
  {
    if (!Std.isOfType(value, Array)) return [];
    return [for (item in (cast value:Array<Dynamic>)) Std.int(readDynamicFloat(item, 0))];
  }

  static function parseIndices(value:String):Array<Int>
  {
    var result:Array<Int> = [];
    if (value == null || value.trim() == "") return result;
    for (part in value.split(","))
    {
      var parsed = Std.parseInt(part.trim());
      if (parsed != null) result.push(parsed);
    }
    return result;
  }

  static function readString(data:Dynamic, field:String, fallback:String):String
  {
    if (data == null || !Reflect.hasField(data, field)) return fallback;
    var value = Reflect.field(data, field);
    return value == null ? fallback : Std.string(value);
  }

  static function readNullableString(data:Dynamic, field:String):Null<String>
  {
    if (data == null || !Reflect.hasField(data, field)) return null;
    var value = Reflect.field(data, field);
    return value == null || Std.string(value) == "" ? null : Std.string(value);
  }

  static function readFloat(data:Dynamic, field:String, fallback:Float):Float
  {
    return data == null ? fallback : readDynamicFloat(Reflect.field(data, field), fallback);
  }

  static function readInt(data:Dynamic, field:String, fallback:Int):Int
  {
    return Std.int(readFloat(data, field, fallback));
  }

  static function readBool(data:Dynamic, field:String, fallback:Bool):Bool
  {
    if (data == null || !Reflect.hasField(data, field)) return fallback;
    var value = Reflect.field(data, field);
    if (Std.isOfType(value, Bool)) return cast value;
    return Std.string(value).toLowerCase() == "true";
  }

  static function readDynamicFloat(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;
    var parsed = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? fallback : parsed;
  }

  static function readColor(value:Dynamic, fallback:String):String
  {
    if (value == null) return fallback;
    var color = Std.string(value).trim();
    if (color == "") return fallback;
    if (!color.startsWith("#")) color = "#" + color;
    return color.toUpperCase();
  }

  static function xmlString(node:Xml, attribute:String, fallback:String):String
  {
    var value = node.get(attribute);
    return value == null || value == "" ? fallback : value;
  }

  static function xmlFloat(node:Xml, attribute:String, fallback:Float):Float
  {
    return readDynamicFloat(node.get(attribute), fallback);
  }

  static function xmlBool(node:Xml, attribute:String, fallback:Bool):Bool
  {
    var value = node.get(attribute);
    return value == null ? fallback : value.toLowerCase() == "true";
  }

  static function setNumberIfChanged(node:Xml, attribute:String, value:Float, fallback:Float):Void
  {
    if (value != fallback) node.set(attribute, numberString(value));
  }

  static function numberString(value:Float):String
  {
    return value == Math.floor(value) ? Std.string(Std.int(value)) : Std.string(value);
  }

  static function safeName(value:String):String
  {
    var cleaned = ~/[^A-Za-z0-9_-]+/g.replace(value, "-").trim();
    while (cleaned.startsWith("-"))
      cleaned = cleaned.substring(1);
    while (cleaned.endsWith("-"))
      cleaned = cleaned.substring(0, cleaned.length - 1);
    return cleaned == "" ? "stage" : cleaned.toLowerCase();
  }

  static function uniqueWarnings(warnings:Array<String>):Array<String>
  {
    var result:Array<String> = [];
    for (warning in warnings)
      if (warning != null && warning != "" && !result.contains(warning)) result.push(warning);
    return result;
  }
}

typedef StageConversionResult =
{
  var bytes:Bytes;
  var extension:String;
  var defaultFileName:String;
  var warnings:Array<String>;
};

typedef StageConversionData =
{
  var name:String;
  var directory:String;
  var codenameFolder:String;
  var cameraZoom:Float;
  var props:Array<StageConversionProp>;
  var bf:StageConversionCharacter;
  var gf:StageConversionCharacter;
  var dad:StageConversionCharacter;
  var warnings:Array<String>;
};

typedef StageConversionProp =
{
  var name:String;
  var assetPath:String;
  var x:Float;
  var y:Float;
  var zIndex:Int;
  var isPixel:Bool;
  var scaleX:Float;
  var scaleY:Float;
  var alpha:Float;
  var danceEvery:Float;
  var scrollX:Float;
  var scrollY:Float;
  var flipX:Bool;
  var flipY:Bool;
  var angle:Float;
  var color:String;
  var animations:Array<StageConversionAnimation>;
  var startingAnimation:Null<String>;
};

typedef StageConversionCharacter =
{
  var x:Float;
  var y:Float;
  var zIndex:Int;
  var scale:Float;
  var cameraX:Float;
  var cameraY:Float;
  var scrollX:Float;
  var scrollY:Float;
  var alpha:Float;
  var angle:Float;
};

typedef StageConversionAnimation =
{
  var name:String;
  var prefix:String;
  var offsets:Array<Float>;
  var looped:Bool;
  var frameRate:Int;
  var frameIndices:Array<Int>;
  var flipX:Bool;
  var flipY:Bool;
};
#end
