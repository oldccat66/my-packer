# VMProtectCon Windows CLI

VMProtectCon is a Windows x64 command-line protector for PE executables. It
reads an input executable and writes a protected copy. This repository contains
the public binary releases; source code and build credentials are kept in a
separate private repository.

## Download

Open the [Releases](../../releases) page and download the ZIP for Windows x64.
Extract `VMProtectCon.exe` to a directory of your choice. No installer is
required.

The release package contains only the CLI executable. It does not install a
service, driver, debugger, or system-wide component.

## Requirements

- Windows 10 or Windows 11, 64-bit;
- a PE executable that you are authorized to modify;
- a VMProtect project/profile file when project-specific protection options are
  required.

This release is a CLI tool only. It does not include the GUI, SDK, runtime
development files, or private licensing material.

## Quick start

Run the CLI from PowerShell or `cmd.exe`:

```powershell
.\VMProtectCon.exe input.exe protected.exe
```

To apply a project/profile file:

```powershell
.\VMProtectCon.exe input.exe protected.exe -pf .\profile.vmp
```

Choose an output path different from the input path. Keep an untouched backup
and test `protected.exe` in a staging environment before deployment.

## Command-line syntax

```text
VMProtectCon.exe input.exe output.exe [-pf project.vmp] [-sf script.lua]
                         [-wm watermark] [--compression lzma|zstd] [-we]
```

| Option | Description |
| --- | --- |
| `input.exe` | Input Windows PE executable. |
| `output.exe` | Destination path for the protected executable. |
| `-pf FILE` | Load a VMProtect project/profile file. |
| `-sf FILE` | Load an additional Lua script. |
| `-wm NAME` | Set the output watermark name. |
| `--compression lzma` | Use LZMA resource compression; this is the default. |
| `--compression zstd` | Use the embedded Zstandard resource compressor. |
| `-we` | Treat warnings as errors. |

If the program is started without the required input and output arguments, it
prints a usage summary. This CLI does not currently provide a separate `--help`
switch.

Paths may be absolute or relative to the current working directory. Quote paths
that contain spaces.

## Compression example

```powershell
.\VMProtectCon.exe `
  .\input.exe .\protected.exe `
  -pf .\profile.vmp `
  --compression zstd
```

Compression affects embedded resources only. It does not by itself enable
anti-debugging, import protection, virtualization, or any other profile option.

## Exit codes and troubleshooting

A zero exit code means that the output file was written successfully. A non-zero
exit code means that the input/profile could not be opened, compilation failed,
or the output could not be saved.

When a protected program does not start:

1. Confirm that the original executable starts on the same machine.
2. Use a minimal profile and add protection options incrementally.
3. Check that every referenced DLL, script, and profile path is available.
4. Re-run the CLI from a terminal so warnings and errors remain visible.
5. Test the protected output on a disposable VM before shipping it.

Do not use a profile intended to bootstrap the internal runtime as a general
application profile. Keep backups of both the input executable and profile.

## Security and support boundary

Only protect software for which you have permission. The tool modifies PE files;
it cannot guarantee compatibility with every packer, loader, runtime, driver,
or endpoint-security product. Anti-debugging and import protection are profile
features and may have compatibility costs.

Issues should include the release version, Windows version and architecture, the
exact command with secrets and private paths removed, and the CLI output. Do not
upload proprietary executables, license files, access tokens, or private profiles
to a public issue.

## License and notices

Use and redistribution are subject to the license terms provided by the
publisher. Third-party components retain their respective licenses; see the
notices included with a release where applicable.
