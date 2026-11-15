package funkin.util.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class PolymodPrinterMacro
{
  public static macro function build():Array<Field>
  {
    final fields = Context.getBuildFields();
    var patched = 0;
    for (field in fields)
    {
      if (field.name != 'printType' && field.name != 'toString') continue;
      switch (field.kind)
      {
        case FFun(fn) if (fn.args.length == 1 && field.access.contains(AStatic)):
          final input = fn.args[0].name;
          final method = field.name == 'printType' ? 'typeToString' : 'exprToString';
          fn.expr = macro return new polymod.hscript._internal.Printer().$method($i{input});
          patched++;
        default:
          Context.error('Unsupported Polymod printer signature.', field.pos);
      }
    }
    if (patched != 2) Context.error('Could not find both Polymod printer entry points.', Context.currentPos());
    return fields;
  }
}
#end
