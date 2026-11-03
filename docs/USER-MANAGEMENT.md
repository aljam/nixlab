# User Management

This repository uses declarative NixOS users. Password login over SSH is disabled; SSH access uses public keys, and interactive password authentication is disabled.

## Adding a user

1. Create `users/<name>/nixos.nix`.
2. Define the user, SSH public keys, and password secret.
3. Import the user module from the appropriate host configuration.
4. Add the user's password secret to `secrets/common.yaml` using SOPS.
5. Add the user to `wheel` only if they require administrative SSH and sudo access.

Example:

```nix
{ config, pkgs, ... }:
{
  users.users.example = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA... example@laptop"
    ];
    hashedPasswordFile = config.sops.secrets.example_password.path;
  };

  sops.secrets.example_password = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
  };
}
```

## SSH access

The shared SSH configuration permits the `aljam` user and members of `wheel`.
These allowlists are OR-ed by OpenSSH, so adding a user to `wheel` intentionally grants that user SSH access.

- Add a user to `wheel` only when they need administrative access.
- Use SSH public keys; password authentication remains disabled.
- Do not add a user to both `AllowUsers` and `wheel` unless both grants are intentional.
- Prefer a dedicated non-administrative user for service or automation access.

## SSH key hygiene

Every authorized public key must include a unique `user@device` comment. This makes the key inventory understandable and makes rotation safer.

```text
ssh-ed25519 AAAA... aljam@navi-desktop
ssh-ed25519 AAAA... aljam@work-laptop
```

CI rejects keys with no comment or a comment that does not follow the `user@device` convention.

### Key inventory

| User | Device | Key comment | Status |
|---|---|---|---|
| `aljam` | `navi-desktop` | `navi-desktop` | Active; rename to `aljam@navi-desktop` on next rotation |

### Rotating a key

1. Generate a new key on the device.
2. Add its public key with a `user@device` comment.
3. Deploy the affected host.
4. Confirm the new key can authenticate.
5. Remove the old key and deploy again.
6. Update the key inventory above.

Do not reuse one key across multiple devices. If a device is lost or decommissioned, remove its key promptly and rotate the key if there is any possibility it was exposed.

## Passwords

User passwords are SOPS-encrypted and exposed through `hashedPasswordFile`.

Generate a suitable hash with:

```bash
mkpasswd -m yescrypt
```

Store only the resulting hash in SOPS, never the plaintext password.

## SOPS recipient check

Before relying on a new or rebuilt host, verify that its SSH-derived age public key matches its recipient in `.sops.yaml`. See [Secrets Management](./SECRETS.md#verify-host-age-recipients).
