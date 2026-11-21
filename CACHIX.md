# Cachix

This repository uses Cachix as a focused binary cache for complete NixOS system closures. General-purpose packages are supplied by the configured upstream and project caches; this cache is not intended to duplicate them.

## Cache policy

The GitHub Actions workflow pushes only the selected host's system closure:

```text
.#nixosConfigurations.<host>.config.system.build.toplevel
```

It does not upload:

- `nix flake check` results.
- Development shells.
- Arbitrary package attributes.
- Broad package sets or unrelated build outputs.
- Every host on every run.

The system closure may reference package paths needed by that system. Cachix stores closure dependencies as needed for substitution, but the workflow does not intentionally build and push a separate general-purpose package cache. Other configured caches remain responsible for commonly shared packages.

## Building any host

The workflow supports the configured hosts:

- `navi`
- `oryx`
- `r730`
- `r730xd`
- `r820`

Pushes to `main` build the default host, `navi`. To build another host, start the workflow manually from GitHub Actions and choose the `host` input.

The host input is evaluated as a Nix flake attribute. Keep it restricted to known `nixosConfigurations` outputs; do not pass arbitrary shell text into the workflow.

## GitHub Actions setup

The workflow requires a repository secret named `CACHIX_AUTH_TOKEN` with permission to push to the `nixlab` cache.

The workflow intentionally has no broad `watch-exec` wrapper. It first produces one explicit system-closure path and then pushes that path with `cachix push`.

## Local setup

Install the Cachix CLI and authenticate:

```bash
cachix authtoken <token>
cachix use nixlab
```

Use the cache as a substituter when building or deploying:

```bash
nix build \
  --substituters 'https://nixlab.cachix.org https://cache.nixos.org' \
  .#nixosConfigurations.navi.config.system.build.toplevel
```

## Explicit local push

Build and push only one host's system closure:

```bash
host=navi
nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" \
  --no-link \
  --print-out-paths > result
cachix push nixlab < result
```

Replace `navi` with another configured host when needed. Avoid pushing development shells, package collections, or arbitrary build results unless the cache policy is intentionally expanded.

## Troubleshooting

### Authentication fails

Confirm that `CACHIX_AUTH_TOKEN` exists, is valid, and has push permission for the `nixlab` cache.

### A host build fails

Confirm the host is a configured `nixosConfigurations` output and run the same build locally with the selected host name. Check host-specific secrets, hardware assumptions, and evaluation errors.

### `oryx` compiles the CachyOS kernel and runs out of space

`oryx` uses the [CachyOS kernel maintainer's binary cache](https://github.com/xddxdd/nix-cachyos-kernel/issues/110). On the first rebuild, the new settings are not active yet. From the updated checkout on `oryx`, pass the cache and its signing key to the build explicitly:

```bash
sudo nixos-rebuild build --flake .#oryx \
  --option extra-substituters https://cache.lantian.pub/lantian \
  --option extra-trusted-public-keys 'lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ='
```

This builds without activating. To apply the generation after the build succeeds, rerun the same command with `switch` in place of `build`. Subsequent rebuilds can use the activated daemon settings.

If a future lock update has no matching substitute, Nix may still compile the kernel. In that case, check free space and inodes on both the Nix store filesystem and the daemon's build filesystem. `/build` in the error is the sandbox path, not necessarily a host mount.

### The cache is still growing unexpectedly

Inspect workflow logs for additional `nix build`, `cachix push`, or `watch-exec` steps. The intended upload is one explicit system-closure path per run; general packages should come from the other configured caches.
