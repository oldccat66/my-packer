# Windows CLI Releases

This repository publishes the Windows x64 command-line binary built from the
private `my-vmp` source repository. Source code, licenses, and build credentials
are never committed here. Releases are created by the manual GitHub Actions
workflow in `.github/workflows/publish-windows.yml`.

## Configure the repository

Add these **Actions secrets** to this public repository:

| Secret | Required value |
| --- | --- |
| `SOURCE_REPOSITORY_URL` | HTTPS clone URL of the private source repository, for example `https://github.com/oldccat66/my-vmp.git` |
| `SOURCE_REPOSITORY_TOKEN` | Fine-grained GitHub PAT with `Contents: Read` on the private source repository only |

The token should belong to a dedicated account or bot and should not have write,
workflow, or organization permissions. Rotate it if it is ever exposed.

## Publish a release

1. Open **Actions** and select **Build and publish Windows CLI**.
2. Choose the source branch, tag, or commit in `source_ref`.
3. Optionally provide a release tag. If it is empty, the workflow uses
   `v0.0.<run number>`.
4. Run the workflow and wait for the unit tests and x64 build to finish.

The release contains:

- `VMProtectCon-windows-x64-<tag>.zip`, containing the self-contained Free CLI;
- `SHA256SUMS.txt`, containing the SHA-256 digest of the ZIP.

The workflow is intentionally `workflow_dispatch`-only. A push to this public
repository cannot automatically read the private source or start a build.

## Local verification

Extract the ZIP on a supported 64-bit Windows system and run:

```powershell
VMProtectCon.exe --help
```

The release workflow builds the `Free|x64` configuration. Professional and
Ultimate builds require private licensing/runtime material and are not published
by this repository.

## Security boundary

The workflow checks out the private repository into a temporary runner directory,
runs tests, and publishes only the CLI ZIP and its digest. It does not upload the
source tree, the PAT, license files, PDBs, or intermediate build output.
