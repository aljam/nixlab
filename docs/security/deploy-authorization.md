# Deployment authorization boundary

Deployment is pull-based. A deployment client asks a host to rebuild itself
from an explicitly selected revision of the repository’s `main` branch; it
does not push configuration or arbitrary commands to the host.

The dedicated `deploy` user is intentionally constrained:

- It authenticates with SSH keys only.
- Its SSH key uses `restrict`, preventing PTY allocation and forwarding.
- SSH forces the deployment wrapper as the only permitted command.
- The wrapper accepts exactly one command form.
- The wrapper delegates to a narrowly scoped `sudo` rule.
- The deploy user has no general-purpose root access.

## Permitted command

The only command accepted over SSH is:

```text
deploy-rebuild switch <full 40-character lowercase hexadecimal commit hash>
```

Example:

```text
deploy-rebuild switch 0123456789abcdef0123456789abcdef01234567
```

The SSH wrapper rejects every other command, including shell access, option
flags, additional arguments, and alternative deployment actions.

## Validation layers

| Layer | Enforcement |
|---|---|
| SSH authentication | Key-only authentication; password authentication is disabled. |
| SSH key options | `restrict` prevents PTY allocation and forwarding. |
| Forced command | SSH may invoke only `deploy-rebuild-ssh`. |
| SSH wrapper | Accepts only `deploy-rebuild switch <40-character commit hash>`. |
| Sudo rule | Permits only `/run/current-system/sw/bin/deploy-rebuild switch *`. |
| Rebuild wrapper | Requires `switch` and a full 40-character commit hash. |
| Source revision | Requires the supplied revision to be the current tip of `refs/heads/main` on the configured remote. |
| Flake target | Rebuilds only the host’s configuration from the selected revision. |

## Why arbitrary commands are rejected

The deployment identity is not an administrative shell account. Allowing
arbitrary SSH commands would turn a deployment credential into a general
remote-execution capability.

The narrow boundary ensures that a leaked or misused deployment key can, at
most, trigger a rebuild from an authorized revision of `main`. It cannot open
an interactive shell, forward ports, run arbitrary commands, or select an
unreviewed local configuration.

## Revision selection

The wrapper queries only `refs/heads/main` on the configured remote. It then
requires the requested commit to appear as the current tip of that exact ref.

This prevents:

- Deploying an arbitrary historical commit.
- Deploying a commit from a pull-request ref.
- Deploying an unpushed local revision.
- Deploying a revision that is not currently the tip of `main`.

## Intended workflow

Run the deployment from a clean, pushed checkout:

```bash
nix run .#deploy -- <host>
```

The local deployment command enforces the same branch rule before connecting
to the target host.

## Change policy

Do not add an SSH command, sudo rule, or wrapper action unless:

- It is required by the deployment workflow.
- Its security boundary is understood.
- It cannot bypass the intended rebuild or administrative policy.
- It is documented alongside the authorization model.

Keep validation centralized in the deployment wrappers. Do not replace the
central validation expression with scattered ad hoc checks.

## Related documentation

- [Security overview](../SECURITY.md)
- [Security review checklist](../SECURITY-REVIEW.md)
- [Authentication](../AUTHENTICATION.md)
