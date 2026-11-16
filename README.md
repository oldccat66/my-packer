# my-vmp

my-vmp is a Windows x64 command-line protector for supported Windows PE
executables. It uses TOML-based `.cfg` profiles and supports optional Lua
build scripts.

Download the latest Windows x64 package from [Releases](../../releases). Each
release includes the CLI, a `CI_BUILDINFO` file describing the build, and a
SHA-256 checksum file.

Start with [USAGE.md](USAGE.md) for installation, CLI commands, profile
configuration, and compatibility notes. See [LUA.md](LUA.md) for Lua syntax,
callbacks, and the scripting API.

## Release Build Information

The private source repository's root `CI_BUILDINFO` file controls each
published build:

```text
TYPE:release
MSG:Windows x64 CLI build of my-vmp. See USAGE.md for setup and limitations.
```

`TYPE` must be `release`, `dev`, or `beta`; it selects the corresponding build
configuration. `MSG` is used verbatim as the GitHub Release description and is
included in the downloaded package. Keep it on one line. The workflow builds
from the private repository's latest `main` branch, runs the unit tests, and
does not generate or attach a full changelog.
