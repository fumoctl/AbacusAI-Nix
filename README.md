# AbacusAI-Nix

A Nix Flake packaging the [Abacus AI Desktop application](https://github.com/abacusai/deepagent-releases) and the [Abacus AI CLI tool](https://static.abacus.ai/cli/install.sh) for NixOS and Linux systems. 

Supports both `x86_64-linux` (amd64) and `aarch64-linux` (arm64) architectures with automated daily updates via GitHub Actions.

---

## Quick Start

You can try the applications immediately without installing them system-wide:

*   **Run the CLI Agent**:
    ```bash
    nix run github:fumoctl/AbacusAI-Nix#abacusai-cli
    ```
*   **Run the Desktop GUI**:
    ```bash
    nix run github:fumoctl/AbacusAI-Nix
    ```

---

## Installation

### 1. NixOS Configuration
To add these packages to your NixOS configuration, include this flake in your inputs and reference the packages in your modules:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    abacusai-nix = {
      url = "github:fumoctl/AbacusAI-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, abacusai-nix, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # Or "aarch64-linux"
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            abacusai-nix.packages.${pkgs.system}.abacusai-desktop
            abacusai-nix.packages.${pkgs.system}.abacusai-cli
          ];
        })
      ];
    };
  };
}
```

### 2. Home Manager Configuration
To install for a specific user using Home Manager:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    abacusai-nix = {
      url = "github:fumoctl/AbacusAI-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, abacusai-nix, ... }: {
    homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ({ pkgs, ... }: {
          home.packages = [
            abacusai-nix.packages.${pkgs.system}.abacusai-desktop
            abacusai-nix.packages.${pkgs.system}.abacusai-cli
          ];
        })
      ];
    };
  };
}
```

### 3. Overlay Integration
You can use the default overlay to merge these packages directly into your main `pkgs` namespace:

```nix
{
  nixpkgs.overlays = [
    inputs.abacusai-nix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    abacusai-desktop
    abacusai-cli
  ];
}
```

---

## Maintenance & Development

A guide for updating locked versions, testing changes, or modifying package derivations can be found in the **[Developer & Agent Guide (AGENTS.md)](file:///home/fumoctl/Projects/AbacusAI-Nix/AGENTS.md)**.
