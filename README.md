# Simple LUA Preprocessor.

Simple LUA Preproccessor does what it says on the tin: it preprocesses LUA files, following a set of rules, called "macros".

To run the program, define a command alias for `lua luaMacro.lua` (for example, the provided `luam.bat`) and pass the path to the file you want to compile as an argument.

## Special Token Types

This program breaks up a lua script into "tokens",  which can be parsed and preprocessesed.  
For example, `print("Hello, World!")` would be split into the tokens `print`, `(`, `"Hello, World!"` & `)`

There are two unique types of tokens that this program can use, but are not part of base lua.  
* `@<macro>` tokens. Prefixed with an `@`, these are used to define macros.
* `!<special>` tokens. Prefixed with `!`, these can be used as macro names in places where spaces may not be appropriate.

```lua
@def !customKey [1]

local table1 = {
    !customKey = 4  -- [1] = 4
}

print(table1!customKey) -- print(table1[1])
```

## Macro Rules

Macros are indicated by the `@` character. They will almost always consume the rest of the current line, so they cannot be used inline, and are recommended to be placed at the start of lines.
**A macro name cannot be composed of more than one token**

* `@def` (Usage: `@def <name> <...replacement>`). Simply replaces any further occurrences of `<name>` with the `<replacement>` tokens. `<replacement>` can be multiple tokens.
* `@raw` (Usage: `@raw <name> <...replacement>`). Same behaviour as `@def`, but will not attempt to evaluate simple maths or encapsulate in brackets.
* `@eval` (Usage: `@eval <name>(<args>) <...statement>`). Tries to evaluate further occurrences of `<name>` as a function with `<statement>` at compile time, will not evaluate if the arguments passed are not all constants or operators.
* `@func` (Usage: `@func <name>(<args>) <...substitution>`). The same as `@eval`, but skips the evaluation step.
* `@comment` (Usage: `@comment`). Removes itself and the rest of the line from the output.

Some more complex macros are:  
* `@del` (Usage: `@del <name1> [name2] [name3] [...names]`). Deletes any macros with the specified names.
* `@enum` (Usage: `@enum [start] [increment]; <name1>, [name2], [name3], ...`). Will `@def` all of the `<name>` tokens with the values `[start]` (default: `1`) incrementing by `[increment]` (default: `1`).

Macros can also other macros in their definitions (but only if that macro was defined earlier!)

```lua
@def foo 2
@def bar 1 + foo

print(bar) -- print(1 + 2)
```

## Examples

### `@def`

```lua
@def HELLO "Hello World!"

print(HELLO) -- Prints "Hello World!"
print("HELLO") -- Prints "HELLO"
```

`@def` also attempts to evaluate simple equations when the content tokens are surrounded by brackets:

```lua
@def foo (1 + 2)
@def bar 3 + 4

print(foo) -- becomes print(3)
print(bar) -- becomes print(3 + 4)

--this works on strings, too.
@def HELLO ("Hello" .. " World!")
@def LUA "Lua " .. "is " .. "cool."

print(HELLO) -- print("Hello World!")
print(LUA)   -- print("Lua " .. "is " .. "cool.")
```

### `@raw`

`@raw` acts the exact same as `@def`, except it will not try to evaluate anything at compile time.

```lua
@raw foo (1 + 2)
@raw bar 3 + 4

print(foo) -- becomes print((1 + 2))
print(bar) -- becomes print(3 + 4)
```

### `@eval`

`@eval` will attempt to evaluate at compile time when referenced like a function.

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

### `@del`

```lua

@def HELLO "Hello World!"

-- print("Hello World!") in the output
print(HELLO)

-- delete the HELLO macro
@del HELLO

-- print(HELLO) in the output
print(HELLO)
```

### `@enum`

```lua

--start and increment default to 1 here
@enum A B C D E F

--print(1, 2, 3, 4, 5 ,6)
print(A, B, C, D, E F)

--the semicolon is not strictly necessary here, but it makes good readability
@enum 0; G H I

--print(0, 1, 2)
print(G, H, I)

--start at index 10, increment by 4
@enum 10, 4; J, K, L, M, N, O, P

--print(10, 14, 18, 22, 26, 30, 34)
print(J, K, L, M, N, O, P)

```