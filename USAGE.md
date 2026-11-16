# Usage

my-vmp is a Windows x64 command-line protector. It accepts supported Windows
user-mode native x86/x64 PE and .NET inputs. The CLI itself is x64; input
compatibility depends on the executable and selected features. Kernel drivers
and other native-subsystem images are not supported.

Run the downloaded executable from PowerShell or `cmd.exe`. For Lua syntax,
callbacks, and the scripting API, see [LUA.md](LUA.md).

A runnable CFG and Lua example is included under [examples](LUA.md#included-example).

## Quick start

Save this as `pack.cfg` beside your executable:

```toml
version = 2

[project]
input = 'input.exe'
output = 'protected.exe'

[protection]
pack = true
anti_debug = false
anti_vm = false
import_protection = false
memory_protection = false
resource_protection = false
strip_fixups = false
strip_debug_info = false
virtualization = false
mutation = false
compression = 'lzma'
use_xor = 'fast'
use_xor_layer2 = false
cpu_hash_slots = 32
vm_entry_compatibility_buffer = 0

[files]
enable = false
```

Then pack it. The input and output are read from `[project]` when they are
present, so no positional paths are needed:

```powershell
.\my-vmp.exe -pf .\pack.cfg
if ($LASTEXITCODE -ne 0) { throw 'Protection failed.' }
```

The same profile can be overridden for a one-off input/output:

```powershell
.\my-vmp.exe .\input.exe .\protected.exe -pf .\pack.cfg
```

`pack = true` enables packing. This profile compresses and encrypts the packed
payload; it does not select application functions for virtualization.
Choose a different output path, retain the original, and run the protected
application separately to verify its behavior.

A command without a profile is also accepted:

```powershell
.\my-vmp.exe .\input.exe .\protected.exe
```

However, project-less defaults do not enable packing. Use an explicit profile
when testing compression or packed-payload encryption.

## Command line

Put the input and output paths first, followed by options:

```text
my-vmp.exe [input.exe output.exe] [-pf project.cfg] [-sf script.lua]
           [-lf licensing-parameters] [-bd YYYY-MM-DD] [-wm watermark] [-we]
```

| Option | Description |
| --- | --- |
| `input.exe` | Optional positional input. If omitted, `[project].input` is required. |
| `output.exe` | Optional positional output. If omitted, `[project].output` or the default is used. |
| `-pf FILE` | Load a TOML `.cfg` profile. Legacy XML `.vmp` projects remain readable. |
| `-sf FILE` | Replace the embedded Lua source and enable the external script. |
| `-lf FILE` | Load licensing parameters. |
| `-bd YYYY-MM-DD` | Set the build date used by licensing. |
| `-wm NAME` | Select an existing watermark by name. |
| `-we` | Treat warnings as errors. |

The compression algorithm and XOR profile are intentionally configuration-only;
they cannot be changed from the CLI. Lua top-level code runs after the profile
is loaded and can still change exposed project settings.

Command-line paths resolve against the current working directory. Paths stored
inside a profile resolve against the profile directory. Quote paths containing
spaces:

```powershell
.\my-vmp.exe '.\My App\input.exe' '.\My App\protected.exe' -pf .\pack.cfg
```

## Profiles

Profiles use UTF-8 TOML and the `.cfg` suffix. The root `version = 2` is the
configuration format version, not the program's release version.

Without `-pf`, an input named `input.exe` is checked for sidecars in this order:

1. `input.exe.cfg`
2. `input.cfg`
3. `input.exe.vmp`
4. `input.vmp`

An existing malformed sidecar or an explicitly selected missing/invalid profile
is an error. The CLI does not silently replace it with defaults. Legacy XML
projects can be read for compatibility; new project saves use CFG, and there
is no XML-to-CFG conversion command.

### Protection settings

| Key in `[protection]` | Meaning |
| --- | --- |
| `pack` | Boolean or `0`/`1`. Compress and protect native packed regions and resources. |
| `anti_debug` | Boolean or `0`/`1`. Enable user-mode debugger checks. |
| `anti_vm` | Boolean or `0`/`1`. Enable virtual-machine checks. |
| `import_protection` | Boolean or `0`/`1`. Protect imports. |
| `memory_protection` | Boolean or `0`/`1`. Enable runtime memory protection. |
| `resource_protection` | Boolean or `0`/`1`. Protect resources. |
| `strip_fixups` | Boolean or `0`/`1`. Strip relocation fixups where supported. |
| `strip_debug_info` | Boolean or `0`/`1`. Remove debug information where supported. |
| `virtualization` | `false`/`0` disables it, `"full"` virtualizes every recognized code function, `"part"` uses only `[[procedures]]` and SDK markers, and `true`/`1` is an alias for `"full"`. |
| `mutation` | Boolean or `0`/`1`. In `full` mode it combines with virtualization as Ultra; in `part`/procedure mode it changes selected functions to mutation. |
| `vm_options` | Low-level VM option mask; leave at `0` unless your profile requires it. |
| `compression` | `lzma` or `zstd`; default: `lzma`. Managed inputs currently support LZMA only. |
| `use_xor` | `none`, `fast`, `balance`, or `secure`; default: `fast`. Configuration-only packed-payload transform. |
| `use_xor_layer2` | Boolean second-pass switch; default: `false`. Configuration-only. |
| `cpu_hash_slots` | User-mode CPU-hash slot count, from `1` to `32`; default: `32`. |
| `vm_entry_compatibility_buffer` | Native VM-entry padding instruction count. `0` disables it; values above `4096` are clamped. |
| `vm_section` | VM section-name setting. Native generated sections normally use `.fdata`, `.sdata`, `.tdata`, then `.zdata`, `.ydata`, and so on; managed output uses a separate naming path. |

The VM-entry buffer applies to generated native VM entries. It is not an
anti-VM switch and has no effect on a function that has no generated VM entry.
Generated native section-name collisions produce a warning and use a suffixed
name instead of silently reusing an existing name.

`virtualization = "part"` does not invent a function list. Add `[[procedures]]`
entries or use the input's `ProtectBegin...ProtectEnd` markers. In `full` mode,
those markers and per-function modes are deliberately overridden.

### Functions and embedded scripts

This example adds a function selection and build-time logging to the packing
profile. Append it to `pack.cfg`, replacing `MyProtectedFunction` with an actual
function name available from your executable's markers or symbol information:

```toml
[[procedures]]
name = 'MyProtectedFunction'
mode = 'ultra'
enable = true

[script]
enable = true
source = '''
function OnBeforeCompilation()
    print("Compiling application")
end
'''
```

Procedure modes are `virtualization`, `mutation`, and `ultra`. Function names
must match the input; an arbitrary source function name may not survive symbol
stripping. A procedure can alternatively be selected by its image address.

Triple-single-quoted TOML strings preserve Lua text literally. The standard
same-line `source = '''` form is recommended. A newline between `source =` and
the opening triple quote is also accepted as a my-vmp extension for this field.
If the Lua source contains `'''`, use an escaped TOML basic string instead.

A present script defaults to enabled when `enable` is omitted. Set
`enable = false` to retain source without executing it. Parsing the profile
does not run Lua; execution happens when protection starts. `-sf FILE` replaces
the embedded source and enables the external script. See [LUA.md](LUA.md) for
callback timing and complete examples.

### Configuration reference

| Section | Keys |
| --- | --- |
| `[project]` | `input`, `output`, `watermark`, `hwid`, `license_data` |
| `[protection]` | `pack`, `anti_debug`, `anti_vm`, `import_protection`, `memory_protection`, `resource_protection`, `strip_fixups`, `strip_debug_info`, `virtualization`, `mutation`, `vm_options`, `vm_section`, `vm_entry_compatibility_buffer`, `cpu_hash_slots`, `compression`, `use_xor`, `use_xor_layer2` |
| `[[messages]]` | `id`, `text` |
| `[[folders]]` | `name`, `parent`, `position` |
| `[[procedures]]` | `name` or `address`, `architecture`, `mode`, `enable`, `options`, `folder`, `index`, `break_offset`, `ext_offsets` |
| `[[objects]]` | `type`, `name`, `architecture`, `exclude_packing`, `exclude_memory_protection`, `exclude_import_protection` |
| `[files]` | `enable` |
| `[[files.folders]]` | `name`, `parent` |
| `[[files.items]]` | `name`, `path`, `folder`, `options`, `load_at_start` |
| `[script]` | `enable`, `source` |
| `[license_manager]` | `product_code`, `algorithm`, `bits`, `public_exp`, `private_exp`, `modulus`, `activation_server`, `black_list` |
| `[[license_manager.licenses]]` | `date`, `customer_name`, `customer_email`, `order_ref`, `serial_number`, `blocked`, `comments` |

Legacy `options`, `packer_cipher`, `packer_cipher_layer2`, `check_kernel_debugger`, `compression_mode`, and `vm_executor_count`
protection keys are still recognized for compatibility. They do not add kernel
driver support. New profiles should use the named boolean settings above.

Boolean fields accept `true` or `false`. Option masks, offsets, and indexes are
nonnegative 32-bit integers. Addresses accept nonnegative TOML integers; quote
decimal or `0x` hexadecimal addresses above the signed 64-bit range. Folder
references use zero-based indexes, unlike the one-based Lua collection API.
Object `type` is `segment`, `resource`, or `import`. Licensing dates are quoted
strings. Use literal strings such as `'C:\Apps\input.exe'` for Windows paths.

## Compression and packed-payload encryption

With packing enabled, native PE regions and resources use the selected
compressor. Managed inputs currently support LZMA only. Selecting compression
or a cipher does not enable packing, function virtualization, or other flags.

For a native executable, edit the packing profile before running:

```powershell
.\my-vmp.exe -pf .\pack.cfg
```

| Cipher profile | Work per 16-byte mask |
| --- | --- |
| `none` | No additional packed-payload cipher. |
| `fast` | 4 mixing rounds. |
| `balance` | 8 mixing rounds. |
| `secure` | 12 mixing rounds. |

These are work factors of a custom stateful transform, not audited security
levels. Encryption uses a fresh build key and per-region nonces; the offline
loader contains the material needed to decrypt the payload. No network service
is required. CRC32 checks decoded compressed data before decompression; it
detects corruption, not deliberate forgery.

The optional second pass defaults to off and is ignored when the cipher is
`none`. Enable it for a build with:

```powershell
.\my-vmp.exe -pf .\pack.cfg
```

Set `use_xor_layer2 = false` to disable a profile that enables it. More rounds
or a second pass add startup work; measure your application instead of assuming
a fixed performance cost. These settings apply to packed payloads, not every
existing string, resource, licensing, or VM-bytecode transform. They do not
guarantee prevention of static unpacking.

## Errors and troubleshooting

The CLI returns a non-zero exit code when it cannot open the input/profile,
compile the project, execute a script, or save the output. Malformed TOML,
unknown keys, duplicate definitions, and invalid field types include the
configuration filename and line number in the error.

A successful protection exit code only confirms that the output was generated.
It does not confirm that the resulting application starts or behaves correctly.

When a protected program fails:

1. Confirm that the original runs on the same machine with its dependencies.
2. Start with the minimal packing profile above and add options incrementally.
3. Keep `lzma` for managed inputs and test your exact .NET runtime/application.
4. Check profile-relative paths and Lua errors; run from a terminal to retain logs.
5. Run the generated application and its normal workload before deployment.

Modern .NET applications and arbitrary protection combinations are not
universally supported. Keep the original executable, profile, and any scripts
together so a working build can be reproduced.
