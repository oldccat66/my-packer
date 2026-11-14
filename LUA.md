# Lua scripting

my-vmp embeds **Lua 5.3.4** to configure a protection build, inspect the input,
select functions, and run callbacks while producing the output. Scripts run on
the machine executing `my-vmp.exe`; they are not embedded application scripts
and do not run each time a protected program starts.

This guide covers Lua syntax and the main project APIs exposed by the current
CLI. See [USAGE.md](USAGE.md) for profile and command-line options.

## Loading a script

Save this as `inspect.lua`:

```lua
local core = myvmp.core()
print("Input: " .. core:inputFileName())
print("Output: " .. core:outputFileName())

function OnAfterCompilation()
    print("Protection completed")
end
```

Run it with an existing profile:

```powershell
.\my-vmp.exe .\input.exe .\protected.exe -pf .\pack.cfg -sf .\inspect.lua
```

`-sf` replaces the profile's embedded script and enables it. Its path is relative
to the CLI's current working directory. Alternatively, append Lua directly to
your TOML profile:

```toml
[script]
enable = true
source = '''
local core = myvmp.core()
print("Input: " .. core:inputFileName())

function OnAfterCompilation()
    print("Protection completed")
end
'''
```

If source is present, omitting `enable` enables it. `enable = false` retains the
embedded text without executing it. Do not define `[script]` twice in one CFG.

The standard `io`, `os`, `package`, and `debug` libraries are available. Scripts
are **not sandboxed**: run only scripts you trust. This is standard Lua, not
LuaJIT; LuaJIT's `ffi` module is not supplied. The bundled build also opens
`coroutine`, `table`, `string`, `math`, and compatibility `bit32`; it does not
open the `utf8` library.

`require` uses Lua's package search paths. Do not assume that module or `io.open`
paths are relative to the `.lua` file; use explicit paths when necessary.

## Included example

Use [examples/example.lua](examples/example.lua) with the supplied
[packing profile](examples/pack.cfg). From the directory containing the
downloaded CLI, with `test.exe` as your input:

```powershell
.\my-vmp.exe .\test.exe .\test.protected.exe -pf .\examples\pack.cfg -sf .\examples\example.lua
```

The script enables packing while preserving other profile flags, prints input
metadata, and logs all five callback stages when the input path supports them.
It handles missing function lists in managed-image wrappers. The profile uses
LZMA and the `fast` cipher without the optional second pass; it does not select
application functions for virtualization. Run `test.protected.exe` separately
to test the result.

## Syntax essentials

### Variables, strings, and tables

```lua
-- A line comment. Prefer local variables for script state.
local enabled = true
local count = 3
local missing = nil
local label = "build " .. count  -- .. concatenates strings/numbers

-- Quoted strings interpret escapes; long-bracket strings do not.
local escaped = "C:\\Apps\\input.exe"
local literal = [[C:\Apps\input.exe]]
local bytes = "\x4D\x5A\x00"  -- binary string, including a zero byte

local settings = {mode = "fast", enabled = true}
local names = {"first", "second"}
print(settings.mode, names[1])
```

Lua is case-sensitive. `true`, `false`, and `nil` are lowercase keywords. Only
`false` and `nil` are false in conditions; `0` and the empty string are true.
Use `#text` for a string's byte length and `#items` for a table's sequence length.
Lua tables can have arbitrary keys; the sequence examples here start at `1`.

Use `--[[ ... ]]` for a block comment. Long strings/comments can use matching
`[=[ ... ]=]` delimiters when their contents include `]]`.

### Conditions, loops, and functions

```lua
local function describe(value)
    if value == nil then
        return "missing"
    elseif value ~= "" then
        return tostring(value)
    else
        return "empty"
    end
end

for i = 1, 3 do
    print(i, describe("item"))
end

for i, name in ipairs({"alpha", "beta"}) do
    print(i, name)
end
```

Blocks end with `end`; semicolons and braces are not required. `==` compares,
`~=` means not equal, and `and`, `or`, and `not` are logical operators. Use
`pairs(table)` for general key/value iteration; its order is not guaranteed.
`ipairs(table)` visits consecutive sequence elements until the first absent one.

Lua 5.3 supports integer bitwise operators: `|`, `&`, `~` (XOR, or unary NOT),
`<<`, and `>>`. These work for option masks; the API's uint64 address userdata
has separate rules described below.

### Dot versus colon

Use a dot for library functions and a colon for methods on returned objects:

```lua
local core = myvmp.core()
local input = core:inputFile()
print(input:count())

-- Equivalent method calls:
print(core:inputFileName())
print(core.inputFileName(core))
```

`core.inputFileName()` without the receiver is incorrect. Object settings are
methods, not assignable Lua fields: use `core:setOptions(mask)`, not
`core.options = mask`.

## Execution order and callbacks

The CLI loads the profile, applies explicit CLI overrides, then executes the
script's top-level code. It next snapshots global compilation settings and
starts processing the output architectures. Recognized callbacks are global
functions with these exact names:

| Callback | When it runs |
| --- | --- |
| `OnBeforeCompilation()` | Before compiling the current output architecture. Use it to inspect or update that architecture's function selections. |
| `OnBeforeSaveFile()` | After architecture compilation, before its save stage. |
| `OnBeforePackFile()` | In the native PE save path, before packing, when packing is enabled. |
| `OnAfterSaveFile()` | After the architecture's save stage; the outer output transaction may still be active. |
| `OnAfterCompilation()` | After successful compilation and finalization of the output file. Useful for final logging. |

Callbacks receive no arguments and their return values are ignored. Missing
callbacks are skipped. Architecture callbacks may run more than once, including
for managed images with native and managed views; do not assume that every
callback runs exactly once or is available on every input path.

Define callbacks with `function OnBeforeCompilation()`, **not**
`local function OnBeforeCompilation()`. Helpers and state can remain local:

```lua
local visits = 0

function OnBeforeCompilation()
    visits = visits + 1
    local arch = myvmp.core():outputArchitecture()
    if arch then
        print("Compiling architecture: " .. arch:name())
    end
end

function OnAfterCompilation()
    print("Architecture callbacks: " .. visits)
end
```

Put global option, output-name, VM-section, and watermark changes at **top
level**. `OnBeforeCompilation` occurs after global settings have been copied
for the current build; changing `core` settings there is too late to reliably
affect that build. `outputFile()` and `outputArchitecture()` are `nil` while
top-level code runs. Reacquire the current architecture inside each callback
instead of retaining a previous callback's output object.

## Project API

`myvmp` is the main global table. `vmprotect` remains a compatibility alias to
the same table; new scripts should use `myvmp`.

```lua
local core = myvmp.core()
```

| Core method | Purpose |
| --- | --- |
| `inputFileName()` | Input filename. |
| `outputFileName()` | Resolved output filename. |
| `projectFileName()` | Current project filename. |
| `inputFile()` / `outputFile()` | Input/output file objects; output is unavailable at top level. |
| `inputArchitecture()` / `outputArchitecture()` | Current architecture objects; check for `nil`. |
| `options()` / `setOptions(mask)` | Read/replace the complete protection bitmask. |
| `setOutputFileName(path)` | Change the output path at top level; an absolute path avoids profile-directory ambiguity. |
| `watermarkName()` / `setWatermarkName(name)` | Read/select an existing watermark. |
| `vmSectionName()` / `setVMSectionName(name)` | Read/change the VM section-name setting. |
| `watermarks()` | Access the watermark collection. |
| `saveProject()` | Explicitly save the project; this writes a profile and is not required to protect a file. |

For example, enable packing while preserving the other profile flags:

```lua
-- Top-level code, before the compilation settings snapshot.
local core = myvmp.core()
core:setOptions(core:options() | ProjectOption.Pack)
```

To remove that flag, use `core:setOptions(core:options() & ~ProjectOption.Pack)`.
Calling `setOptions(ProjectOption.Pack)` instead replaces the mask and clears
other flags.

Useful constants include `ProjectOption.Pack`, `ImportProtection`,
`MemoryProtection`, `ResourceProtection`, `CheckDebugger`, `CheckVirtualMachine`,
`StripFixups`, and `StripDebugInfo`, each with the `ProjectOption.` prefix.
Legacy `ProjectOption.CheckKernelDebugger` does not add driver-image support.

Compression, packer-cipher mode, the second pass, CPU-hash slots, and VM-entry
buffer length have no dedicated Lua setters in this binding. Configure them
through the CFG or the documented CLI switches where available.

Other global helpers are `myvmp.extractFilePath(path)`, `extractFileName(path)`,
`extractFileExt(path)`, `expandEnvironmentVariables(text)`,
`setEnvironmentVariable(name, value)`, and `commandLine()`. Use the `myvmp.`
prefix for each; `commandLine()` returns a one-based table of arguments.

## Inspecting files and architectures

File objects provide `name()`, `format()`, `size()`, `count()`, and `item(i)`.
`count()` counts architecture views, not sections. Lua collection indexes start
at **1**, including the project API's `item(i)` methods.

This complete `inspect-architectures.lua` script only reads input metadata:

```lua
local input = assert(myvmp.core():inputFile(), "No input file")
print("Format: " .. input:format())

for i = 1, input:count() do
    local arch = input:item(i)
    print("Architecture: " .. arch:name())
    print("Image base: 0x" .. tostring(arch:imageBase()))
    print("Entry point: 0x" .. tostring(arch:entryPoint()))
    local functions = arch:functions()
    if functions then
        print("Selected functions: " .. functions:count())
    end
end
```

Native PE and .NET architecture bindings share `name()`, `file()`,
`entryPoint()`, `imageBase()`, `cpuAddressSize()`, `size()`, `segments()`,
`sections()`, `functions()`, `imports()`, `exports()`, `mapFunctions()`, and
`folders()`. Their returned object types can differ. Native PE also provides
`directories()`, `resources()`, and `fixups()`; .NET has `streams()` instead.
Do not apply native-only APIs indiscriminately to a managed architecture.
A method can return `nil` when that view has no corresponding list. In
particular, the native wrapper of a managed input can have no function list;
check the returned object before calling `count()` or other list methods.

For a native PE architecture, `segments()` exposes PE sections with
`count()`, `item(i)`, `itemByName(name)`, and `itemByAddress(address)`.
Each item has `name()`, `address()`, `size()`, `physicalOffset()`,
`physicalSize()`, `flags()`, and `excludedFromPacking()`. `setName(name)` mutates
the name; there is no corresponding exposed `setExcludedFromPacking` method.

Architecture objects also expose `addressSeek(imageVA)`, `seek(fileOffset)`,
`tell()`, `read(byteCount)`, and `write(binaryString, ...)`.
`addressSeek` takes an image virtual address, not an RVA, and returns whether
the address could be mapped. `read` returns a binary Lua string. Reading and
writing advance the shared file cursor; restore its position when inspecting
data. Writing or renaming sections can invalidate a build, so the examples
above deliberately inspect metadata only.

## Selecting functions

`arch:functions()` is the protection function list, not a list of every function
in the executable. `arch:mapFunctions()` exposes functions known from the
input's map/symbol information.

| Function-list method | Purpose |
| --- | --- |
| `count()` / `item(i)` | Iterate current selections. |
| `itemByName(name)` / `itemByAddress(address)` | Find a selection; check for `nil`. |
| `addByAddress(address, compilationType, needCompile)` | Add a selection. The last two arguments default to `CompilationType.Virtualization` and `true`. |
| `delete(i)` / `clear()` | Remove one/all selections. Existing userdata for removed objects must not be reused. |

Compilation modes are `CompilationType.Virtualization`, `Mutation`, `Ultra`,
and `None`, each with the `CompilationType.` prefix. Function objects expose
`address()`, `name()`, `compilationType()`, `setCompilationType(mode)`,
`needCompile()`, and `setNeedCompile(boolean)`.

For example, this callback requires a named selection already present in the
profile or the input's protection markers, then changes its compilation mode:

```lua
function OnBeforeCompilation()
    local arch = assert(myvmp.core():outputArchitecture(), "No output architecture")
    local fn = assert(arch:functions():itemByName("MyProtectedFunction"),
                      "MyProtectedFunction is not selected in this architecture")
    fn:setCompilationType(CompilationType.Ultra)
    fn:setNeedCompile(true)
end
```

Replace the name with a real selection. For inputs with several architecture
views, narrow the callback to the relevant view before requiring the selection.
To add a native selection from available map information, use the same callback
stage and resolve its address first:

```lua
-- Inside OnBeforeCompilation(), with the intended native architecture in arch:
local mapped = assert(arch:mapFunctions():itemByName("MyProtectedFunction"),
                      "Function is absent from map information")
local functions = arch:functions()
local selected = functions:itemByAddress(mapped:address())
if selected == nil then
    selected = functions:addByAddress(mapped:address(), CompilationType.Ultra, true)
end
assert(selected, "Could not add function")
```

The map lookup is not a source-code search: stripped binaries may not have the
name. Do not pass an RVA or arbitrary offset to `addByAddress`, and do not
assume that every function is safe to virtualize.

## 64-bit addresses and binary strings

Address-returning APIs use a custom unsigned 64-bit **userdata**. Keep it in that
form and pass it back to API calls. It supports arithmetic such as `address + 4`
and comparisons with compatible values. `tostring(address)` emits 16 uppercase
hexadecimal digits without a prefix:

```lua
local arch = myvmp.core():inputFile():item(1)
local entry = arch:entryPoint()
print("Entry point: 0x" .. tostring(entry))
local next_address = entry + 4
```

Do not use `string.format("%x", entry)` on that userdata. Also avoid converting
addresses through `tonumber`: even though Lua 5.3 has integer values, this
binding converts numerical address arguments through a floating-point number,
which cannot represent every integer above `2^53` exactly.

A **string address argument is raw little-endian bytes**, not decimal or hex
text. For example, when an API requires the literal VA `0x140001000`:

```lua
local image_va = "\x00\x10\x00\x40\x01\x00\x00\x00"
-- Pass image_va directly to an address-taking API.
```

`"0x140001000"` is not an accepted textual representation in these Lua bindings.
Prefer addresses returned by the API over constructing raw address strings.
This rule differs from the CFG parser, which does accept quoted numeric text.

## Logging and errors

`print(...)` writes to the protection log. It converts arguments with `tostring`
and separates them with tabs. Use `error(message)` or `assert(condition, message)`
to stop on an invalid assumption:

```lua
assert(myvmp.core():inputFile(), "Expected an input file")
```

Syntax and top-level errors report the script source location. Callback errors
are reported as `Script error: ...` and fail the protection command. Returning
`false` from a callback does **not** cancel a build. An error in
`OnAfterCompilation` can report failure even though the output has already been
finalized; keep that callback simple.

For an optional operation that should not stop protection, handle its Lua error
explicitly with `pcall` and inspect the result. Do not suppress errors from
required operations or assume that `pcall` reverses changes already made.
