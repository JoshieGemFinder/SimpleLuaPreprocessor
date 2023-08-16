# Simple LUA Preprocessor.

Simple LUA Preproccessor does what it says on the tin: it preprocesses LUA files (following a set of rules, called "macros").

To run it, define a command alias for `lua luaMacro.lua` (for example, the provided `luam.bat`) and pass the file you want to compile as an argument.

## Macro Rules

Macros are indicated by the `@` character. They will almost always consume the rest of the current line, so they cannot be used inline, and are recommended to be placed at the start of lines.

* `@def` (Usage: `@def <name> <replacement>`). Simply replaces any further occurrences of `<name>` with the `<replacement>` tokens. `<replacement>` can be multiple tokens.
* `@eval` (Usage: `@eval <name>(<args>) <statement>`). Tries to evaluate further occurrences of `<name>` as a function with `<statement>` at compile time, will not evaluate if the arguments passed are not all constants or operators.
* `@func` (Usage: `@func <name>(<args>) <substitution>`). The same as `@eval`, but skips the evaluation step.
* `@comment` (Usage: `@comment`). Removes itself and the rest of the line from the output.


## Examples

### `@def`

```lua
@def HELLO "Hello World!"

print(HELLO) -- Prints "Hello World!"
print("HELLO") -- Prints "HELLO"
```

### `@eval`

```lua
@eval add(a, b) a + b

print(add(1, 2)) -- is print(3) in the output file

local function foo(bar, baz)
    return add(bar * baz, -baz) -- is return (bar * baz) + (-baz) in the output
end
```

### `@func`

```lua
@func add(a, b) a + b

print(add(1, 2)) -- is print((1) + (2)) in the output file

```

### `@comment`

```
@comment This comment won't show up in the output
--This comment will though
```

