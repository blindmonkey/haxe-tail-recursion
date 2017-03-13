# haxe-tail-recursion
A proof of concept macro that eliminates tail recursion from a function by transforming it to iterative form. I made this while I was playing around with Haxe macros

The way it works is by taking the body of the function, identifying the returns that recursively call the function, and replacing them with direct updates to variables. For an example, it turns the factorial function implemented as:
```
var factorial = function(n, acc) {
    if (n > 0) return factorial(n - 1, acc * n);
    return acc;
};
```
into
```
var factorial = function(n, acc) {
    var fresult = null;
    while ((function() {
        if (n > 0) {
          let n_new = n - 1;
          let acc_new = acc * n;
          n = n_new;
          acc = acc_new;
          return true;
        }
        fresult = acc;
    })()) {}
    return fresult;
};
```

This function that runs as the `while` loop condition is the full implementation of the transformed factorial function. The macro should unroll our update to `n` as well as our update to `acc` into updates to the variables themselves instead of as new parameters to a function. Here we have to define new variables instead of immediately assigning, otherwise when we do `acc * n`, we would accidentally do `acc * (n - 1)`. For the recursion case, we then `return true` to the `while` loop to let it continue. Once we reach the non-recursive condition, instead of returning we assign the final value to the enclosed variable `fresult`, and return a falsey value to tell the `while` loop to end.

Happily, the Haxe compiler does us one better by inlining the nested function and giving us a nice flat `while` loop:
```
function(n,acc) {
    var __fresult;
    while(true) {
        var tmp;
        if(n > 0) {
            --n;
            acc *= n;
            tmp = true;
        } else {
            __fresult = acc;
            tmp = false;
        }
        if(!tmp) {
            break;
        }
    }
    return __fresult;
};
```

This is by no means production code. This was an experiment that I may work on further as I have time. It is completely untested, there are a number of known bugs, and probably a larger number of unknown bugs.


## Using and Building
For an example of usage, look at `factorialHelper` in `RecursionTest.hx`. I haven't yet worked enough with macros to know the minimum necessary annotation amount. As I understand it, one has to add the build macro `@:build(recursion.TailRecursion.recursive())` to a class to enable the tail-recursion elimination, and then tail-recursive functions can be marked with `@tailrecursive`. This will enable the macro to run on that function.

To build, run `haxe -m RecursionTest -js recursion.js`. This will build a JavaScript version of `RecursionTest`.


## Known Issues
1. This macro currently doesn't create new variables for recursive calls, so when computing the second argument to a recursive call, if the first argument is used in the computation then the updated first argument will be used, instead of the old value. To solve this, we need to generate assignments to new temporary variables that we can use to hold the results of the computations.
