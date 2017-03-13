package;

@:build(recursion.TailRecursion.recursive())
class RecursionTest {

  @tailrecursive
  private static function factorialHelper(n, acc) {
    if (n > 0) {
      return /*/RecursionTest./*/factorialHelper(n - 1, acc * n);
    }
    return acc;
  }

  public static function factorial(n) {
    return factorialHelper(n, 1);
  }

  public static function main() {
    trace ('hello');
  }
}