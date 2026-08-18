# Abacus AI Nix Flake Developer & Agent Guide

This repository contains a Nix flake for packaging the Abacus AI Desktop application and the Abacus AI CLI tool. This guide provides context for human developers and future AI coding agents on how to maintain, test, update, or modify these packages.

## Repository Layout

*   **[flake.nix](file:///home/fumoctl/Projects/AbacusAI-Nix/flake.nix)**: The main entry point defining inputs, system mappings, outputs (`packages`, `devShells`), and system overlays.
*   **[pkgs/desktop.nix](file:///home/fumoctl/Projects/AbacusAI-Nix/pkgs/desktop.nix)**: Package definition for the desktop AppImage.
*   **[pkgs/cli.nix](file:///home/fumoctl/Projects/AbacusAI-Nix/pkgs/cli.nix)**: Package definition for the Bun-based CLI binary.
*   **[artifacts/versions.json](file:///home/fumoctl/Projects/AbacusAI-Nix/artifacts/versions.json)**: The lock file storing the current URLs and pre-fetched SHA256 hashes for all supported platforms.
*   **[scripts/check-version.sh](file:///home/fumoctl/Projects/AbacusAI-Nix/scripts/check-version.sh)**: Compares locked versions in `versions.json` with current upstream releases.
*   **[scripts/update-version.sh](file:///home/fumoctl/Projects/AbacusAI-Nix/scripts/update-version.sh)**: Automatically updates locked URLs and prefetches hashes for newly discovered releases.

---

## Binary Fetching & Version Locking

To guarantee reproducible builds and work with Nix's sandbox, this flake does not execute curl commands or run interactive scripts during compilation. Instead, it operates on a version locking database:
1. **Metadata Store**: URLs and hashes are locked in **[versions.json](file:///home/fumoctl/Projects/AbacusAI-Nix/artifacts/versions.json)**.
2. **Evaluation**: Inside the Nix derivations, Nix reads the lockfile using `builtins.readFile` and parses the JSON to get the current platform's URL and hash:
   ```nix
   versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
   platformInfo = versions."AbacusAI Desktop".${system};
   ```
3. **Fetch Phase**: Nix downloads the asset securely using standard `fetchurl` with the pinned sha256 hash:
   ```nix
   src = fetchurl {
     inherit (platformInfo) url;
     sha256 = platformInfo.hash;
   };
   ```
4. **Target Sources**:
   - **Desktop AppImages** are downloaded from the releases of the **[deepagent-releases GitHub repo](https://github.com/abacusai/deepagent-releases)**.
   - **CLI Binaries** are downloaded as `.tar.gz` archives from **`https://static.abacus.ai/cli/releases/`**.

---

## Critical Packaging Notes

### 1. CLI Packaging (Interpreter-Wrapper Strategy)
The Abacus AI CLI is a binary compiled using Bun's standalone builder. 
*   **The Problem**: Bun appends the Javascript application payload directly to the end of the compiled binary and tracks it using a footer offset. Standard Nix packaging techniques like `autoPatchelfHook` rewrite the ELF headers, which shifts binary sections and corrupts the footer offset. Similarly, Nix's default `strip` build phase discards the trailing JS payload entirely. Either of these operations leaves the binary behaving like a standard Bun interpreter rather than executing the Abacus AI application code.
*   **The Solution**: We bypass `patchelf` and `strip` by setting `dontStrip = true;` and `dontPatchELF = true;`. Instead of patching the binary directly, `cli.nix` copies the raw binary to `libexec` and writes a shell wrapper to `$out/bin/abacusai` which invokes the system's dynamic linker (e.g. `/lib64/ld-linux-x86-64.so.2` from glibc) directly, passing the target libraries explicitly:
    ```bash
    exec ${stdenv.cc.bintools.dynamicLinker} --library-path "${lib.makeLibraryPath [ stdenv.cc.libc stdenv.cc.cc.lib ]}" $out/libexec/abacusai "$@"
    ```
*   **Rule for future modifications**: **Do NOT** attempt to use `autoPatchelfHook` or allow `strip` to run on the CLI binary. If any new libraries are required in the future, append them to the `--library-path` list in `cli.nix`.

### 2. Desktop Packaging (extractType2 Strategy)
The Desktop app is distributed as an AppImage.
*   We use `appimageTools.wrapType2` to handle sandboxing (FHS bubblewrap) and execution.
*   To extract desktop integrations (icons and fallback pixmaps) without running into AppImage offset errors during builds, we leverage `appimageTools.extractType2`. This builds an intermediate derivation containing the unpacked SquashFS contents of the AppImage.
*   Icons are copied directly from the extracted SquashFS contents into `$out/share/icons/hicolor/...` for all available dimensions, and a desktop shortcut is registered.

---

## Update and Maintenance Workflows

### Automated CI/CD & Updates (GitHub Actions)
The repository uses GitHub Actions for automated maintenance:
* **`.github/workflows/update.yml`**: Scheduled daily at 07:00 UTC (and manual via `workflow_dispatch`). Checks upstream for new Desktop and CLI releases, updates `artifacts/versions.json`, verifies builds (`nix flake check` & `nix build`), and opens a PR with auto-merge enabled.
* **`.github/workflows/ci.yml`**: Runs on pushes and pull requests to `main` to verify flake checks and builds.
* **`.github/workflows/release.yml`**: Creates versioned GitHub releases and git tags when updates land on `main`.
* **`.github/workflows/cleanup-branches.yml`**: Cleans up merged `auto-update/*` branches weekly or upon PR merge.

Manual workflow triggers:
```bash
# Trigger the update workflow manually
gh workflow run update.yml
```

### How to Check for Updates Locally
To check if a newer version of the Desktop or CLI is available upstream:
```bash
nix shell .# -c ./scripts/check-version.sh
```

### How to Update Versions Locally
To fetch the latest versions, download their binaries, compute hashes, and update `artifacts/versions.json`:
```bash
nix shell .# -c ./scripts/update-version.sh
```

### How to Test and Build
To verify changes and compile the packages locally:
```bash
# Build the CLI tool
nix build .#abacusai-cli

# Build the Desktop app
nix build .#abacusai-desktop

# Run checks
nix flake check
```
*(Note: Because Nix ignores untracked files in git repositories, you must stage any new/modified files using `git add` before Nix commands can see them.)*
