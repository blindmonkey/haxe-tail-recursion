package recursion;

import haxe.macro.Expr;
import haxe.macro.Context;

typedef PositionedExprDef = {
  expr: PositionedExprDef,
  pos: haxe.macro.Position
}

class TailRecursion {
  private static
  function any<T>(items:Array<T>, selector:T->Bool):Bool {
    for (item in items)
      if (selector(item)) return true;
    return false;
  }

  private static function log(msg:String, expr:Expr):Expr {
    trace(msg, expr);
    return expr;
  }

  private static
  function doOptimizeTailRecursiveExpr(
      expr:Expr,
      isOriginalFunction:Expr->Bool,
      args:Array<{name: String}>,
      ?directlyInReturn:Bool = false):Expr {
    /*
      var factorial = function(n, acc) {
        if (n > 0) return factorial(n - 1, acc * n);
        return acc;
      };

      transforms into:
      var fresult = null;
      while ((function() {
          if (n > 0) {
            n = n - 1;
            acc = acc * n;
            return true;
          }
          fresult = acc;
        })()) {}
      return fresult;
    */

    var thisf = doOptimizeTailRecursiveExpr;
    if (directlyInReturn) {
      switch (expr.expr) {
        case ECall(funcExpr, argsExprs):
          if (!isOriginalFunction(funcExpr)) {
            return expr;
          }
          var outputExprs:Array<Expr> = [];
          for (argIndex in 0...args.length) {
            var arg = args[argIndex];
            outputExprs.push({
              expr: EBinop(OpAssign, {
                  expr: EConst(CIdent(arg.name)),
                  pos: expr.pos
                }, argsExprs[argIndex]),
              pos: expr.pos
            });
          }
          outputExprs.push({
            expr: EReturn({
              expr: EConst(CIdent("true")),
              pos: expr.pos}),
            pos: expr.pos});

          return {
            expr: EBlock(outputExprs),
            pos: expr.pos
          };
        case EConst(constExpr):
          return {
            expr: EBlock([{
              expr: EBinop(OpAssign, {
                  expr: EConst(CIdent('__fresult')),
                  pos: expr.pos
                }, expr),
              pos: expr.pos
            }, {
              expr: EReturn({
                expr: EConst(CIdent("false")),
                pos: expr.pos}),
              pos: expr.pos
            }]),
            pos: expr.pos
          };
        default:
          trace(expr);
          throw 'Invalid format for tail recursive function: expecting the return to call the function or return a constant';
      };
    }
    return switch (expr.expr) {
      case EBlock(exprs):
        macro $b{[for (e in exprs)
          doOptimizeTailRecursiveExpr(e, isOriginalFunction, args)]};
      case EIf(conditionExpr, thenExpr, elseExpr):
        { expr: EIf(
            doOptimizeTailRecursiveExpr(conditionExpr, isOriginalFunction, args),
            doOptimizeTailRecursiveExpr(thenExpr, isOriginalFunction, args),
            if (elseExpr == null) null else doOptimizeTailRecursiveExpr(elseExpr, isOriginalFunction, args)),
          pos: expr.pos };
      case EBinop(operationType, operandLeft, operandRight):
        { expr: EBinop(operationType,
            doOptimizeTailRecursiveExpr(operandLeft, isOriginalFunction, args),
            doOptimizeTailRecursiveExpr(operandRight, isOriginalFunction, args)),
          pos: expr.pos };
      case EReturn(valueExpr):
        macro return $e{doOptimizeTailRecursiveExpr(
              valueExpr, isOriginalFunction, args, true)};
      case EConst(_): expr;
      default: log('=== unrecognized', expr);
    };
  }

  private static function doOptimizeTailRecursiveFunction(field:Field, name:String) {
    var func = field.kind;
    trace(field);
    var isStatic = false;
    if (field.access != null) {
      for (a in field.access) {
        if (switch(a) {
          case AStatic: true;
          default: false;
        }) {
          isStatic = true;
          break;
        }
      }
    }

    switch (func) {
      case FFun(description):
        trace('found function!');
        var input:Expr = description.expr;
        var p = function(expr) {
          return {expr: expr, pos: input.pos};
        };
        description.expr = p(EBlock([
          p(EVars([{
            type: null,
            expr: null,
            name: '__fresult'
          }])),
          p(EWhile(
            p(ECall(
            p(EFunction(null, {
              args: [],
              expr:
              doOptimizeTailRecursiveExpr(input, function(f) {
                return switch (f.expr) {
                  case EConst(CIdent(cname)):
                    name == cname;
                  case EField(src, fname):
                    false;
                  default: false;
                };
              }, description.args)
              ,
              params: null,
              ret: null
            })), []
            )),
            p(EBlock([])),
            true)),
          p(EReturn(p(EConst(CIdent("__fresult")))))
          ]));
        return FFun(description);
      default:
        trace('unrecognized: $func');
    }
    return func;
  }

  private static function optimizeTailRecursiveFunction(func:Field):Field {
    trace('optimizing ${func.name}');
    func.kind = doOptimizeTailRecursiveFunction(func, func.name);
    return func;
  }

  public static
  function recursive():Array<Field> {
    trace(Context);
    return [
      for (field in Context.getBuildFields())
        switch (field.kind) {
          case FFun(_):
            if (any(field.meta, function(m) {
                  return m.name == 'tailrecursive'; }))
              optimizeTailRecursiveFunction(field);
            else field;
          default: field;
        }
    ];
  }
}
