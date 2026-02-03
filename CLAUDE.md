# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository Overview

This is a NixOS desktop configuration using:
- **Flake-based** system configuration
- **Home Manager** for user environment
- **Niri Wayland** compositor + Noctalia Shell
- **tmpfs root** + Btrfs subvolumes + LUKS encryption
- **preservation** module for persistent storage
- **Zero compilation** strategy (100% binary cache)

---

## Essential Commands

### Daily Operations

Use `just` for all common tasks:

```bash
just              # List all commands
just switch       # Apply configuration
just quick        # Check + apply
just clean        # Clean old generations
just upgrade      # Update flake.lock + apply
```

### Manual NixOS Rebuild

```bash
# Apply and switch immediately
sudo nixos-rebuild switch --flake .#nixos-config

# Test without committing (revert on reboot)
sudo nixos-rebuild test --flake .#nixos-config

# Check syntax only
sudo nixos-rebuild dry-build --flake .#nixos-config

# With prettier output
sudo nixos-rebuild switch --flake .#nixos-config |& nom
```

### Code Quality

```bash
# Format Nix code
nixpkgs-fmt .

# Check with linter
statix check .

# Find dead code
deadnix .

# Verify flake
nix flake check
```

### Development Environment

```bash
# Enter dev shell (provides nil, nixpkgs-fmt, statix, deadnix, nix-tree)
nix develop

# Build ISO
nix build .#nixos-config-iso
```

---

## Architecture Overview

### Flake Structure

- **flake.nix**: Entry point, imports `outputs.nix`
- **outputs.nix**: Defines nixosConfiguration, devShell, formatter
  - Reads `myvars` from `nix/vars/default.nix`
  - Supports `NIXOS_USER` env override for username
  - Main user flows through `mainUser` special arg to all modules

### Module Organization

```
nix/
├── hosts/                          # Per-host configuration
│   ├── nixos-config.nix           # Main host config (imports modules)
│   └── nixos-config-hardware.nix  # Hardware config (auto-generated)
├── modules/                        # Core system modules
│   ├── system.nix                 # System-level config (bootloader, desktop, packages)
│   └── hardware.nix               # GPU drivers + auto-detection
├── hardening/                      # Security hardening
│   └── apparmor.nix
├── home/                           # Home Manager config
│   ├── default.nix                # User environment setup
│   └── configs/                   # Config files (niri, ghostty, shell, etc.)
└── vars/                           # Global variables
    ├── default.nix                # User/hostname/paths
    └── detected-gpu.txt           # GPU detection result (generated)
```

### Key Design Patterns

1. **Variable System**
   - `nix/vars/default.nix` defines `username`, `hostname`, `configRoot`
   - `outputs.nix` imports as `myvars`, passes to all modules via `specialArgs`
   - Runtime override: `NIXOS_USER` env var > `myvars.username`

2. **GPU Configuration**
   - Auto-detect in install script → writes `nix/vars/detected-gpu.txt`
   - `nix/modules/hardware.nix` reads file (fallback priority chain)
   - Runtime override: `NIXOS_GPU` env var (requires `--impure`)
   - Specialisation (boot menu switching) disabled by default to reduce ISO size

3. **Persistent Storage**
   - Root = tmpfs (cleared on reboot)
   - `/persistent` = Btrfs subvolume with `preservation` module
   - Home Manager configs read from `repoRoot` (env `NIXOS_CONFIG_PATH` > `~/nixos-config` > `myvars.configRoot`)

4. **Path Constants Pattern**
   - Extract repeated `config.home.homeDirectory` to `homeDir`
   - Extract common paths (`localBinDir`, `localShareDir`) to avoid duplication
   - See `nix/home/default.nix` let bindings

5. **Binary Cache Strategy**
   - All packages use official caches (no local compilation)
   - Removed packages that trigger builds (wine stagingFull → stable, nixpaks)
   - See `nix.settings.substituters` in `nix/modules/system.nix`

---

## Critical Configuration Rules

### When Modifying Files

1. **nix/vars/default.nix**
   - Changing `username` breaks Home Manager unless you also update:
     - `users.users.${mainUser}` in system.nix
     - `/persistent/home/${username}` permissions
   - Changing `configRoot` requires users to update `NIXOS_CONFIG_PATH` or move repo

2. **nix/modules/hardware.nix**
   - GPU detection uses `findFirstExistingPath` helper (don't revert to nested if-else)
   - Driver constants: `driverNvidia`, `driverAmdgpu`, `driverModesetting`
   - Always test both NVIDIA and AMD configs when modifying

3. **nix/home/default.nix**
   - Use `homeDir` / `localBinDir` / `localShareDir` constants (never raw `config.home.homeDirectory`)
   - `repoRoot` calculation has env override fallback chain
   - `mkSymlink` requires repo to exist at calculated path

4. **Binary Cache Violations**
   - Never add packages that trigger compilation:
     - Check with: `nix build --dry-run .#nixosConfigurations.nixos-config.config.system.build.toplevel`
     - Look for "will be built" vs "will be fetched"
   - Exceptions documented in comments (e.g., `wineWowPackages.stable` not stagingFull)

### File Generation (Don't Edit)

These files are auto-generated by `scripts/auto-install.sh`:
- `nix/hosts/nixos-config-hardware.nix` (from `nixos-generate-config`)
- `nix/vars/detected-gpu.txt` (from GPU detection)

Regenerate instead of manual editing.

---

## Common Workflows

### Adding New Package

1. System package: add to `environment.systemPackages` in `nix/modules/system.nix`
2. User package: add to `home.packages` in `nix/home/default.nix`
3. Check if binary cache exists: `nix path-info --store https://cache.nixos.org nixpkgs#<package>`

### Changing GPU Driver

```bash
# Option 1: Modify detected result
echo "amd" > nix/vars/detected-gpu.txt
sudo nixos-rebuild switch --flake .#nixos-config

# Option 2: Environment variable (requires --impure)
NIXOS_GPU=nvidia sudo nixos-rebuild switch --impure --flake .#nixos-config
```

### Adding Home Manager Config

1. Place config files in `nix/home/configs/<app>/`
2. Add symlink in `xdg.configFile` or `home.file` using `mkSymlink "${repoRoot}/..."`
3. Use relative paths from `repoRoot` (already includes repo location logic)

### Updating Dependencies

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# View dependency tree
nix-melt
```

---

## Testing Strategy

### Before Committing

```bash
just check-all    # Format + lint + deadnix
nix flake check   # Verify flake structure
```

### Safe Testing

```bash
# Test config without affecting current system
sudo nixos-rebuild test --flake .#nixos-config

# Check what would be built
sudo nixos-rebuild dry-build --flake .#nixos-config

# View build plan
nix build --dry-run .#nixosConfigurations.nixos-config.config.system.build.toplevel
```

### Rollback

```bash
# View generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Specific generation (at boot menu)
# Select "NixOS - Configuration X" in systemd-boot
```

---

## Troubleshooting

### Build Issues

**Problem**: "will be built" instead of "will be fetched"
- **Cause**: Package not in binary cache or overridden incorrectly
- **Fix**: Check `nix/modules/system.nix` for custom overlays, remove or fix

**Problem**: GPU driver not loading
- **Cause**: Wrong driver in `detected-gpu.txt` or missing specialisation
- **Fix**: Manually set `NIXOS_GPU=<nvidia|amd|none>` and rebuild with `--impure`

**Problem**: Home Manager can't find configs
- **Cause**: `repoRoot` calculation pointing to wrong path
- **Fix**: Set `NIXOS_CONFIG_PATH` env var or update `nix/vars/default.nix`

### Permission Issues

**Problem**: `/persistent/home/<user>` owned by wrong UID
- **Cause**: Install script hardcoded UID, then user UID changed
- **Fix**: System auto-fixes on boot (see `system.activationScripts.fixPersistentHomePerms`)

---

## Environment Variables

**Build time**: `NIXOS_USER`, `NIXOS_GPU`, `NIXOS_CONFIG_PATH` (require `--impure`)
**Install time**: See README.md environment variables table

Key patterns:
- `NIXOS_*` vars flow through `outputs.nix` via `builtins.getEnv`
- Home Manager reads `NIXOS_CONFIG_PATH` for `repoRoot` calculation
- GPU override: `NIXOS_GPU=<nvidia|amd|none>` with `--impure` flag

---

## Performance Notes

- **Build time**: ~0 (everything from cache)
- **ISO size**: 1.2GB (optimized, removed fonts/wine duplication)
- **Cache hit rate**: 96%+
- **Install time**: 15-20 minutes (network download only)

Maintain this by:
- Never adding packages without cache check
- Preferring official packages over overlays
- Using stable versions (not unstable/master unless cached)
