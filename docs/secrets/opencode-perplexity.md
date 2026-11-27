# Perplexity API key for OpenCode

OpenCode on the desktop hosts (`navi` and `oryx`) reads the Perplexity API key from:

```text
/run/secrets/perplexity_api_key
```

## Add the secret

1. Create a Perplexity API key in the Perplexity API portal.
2. Add this plaintext entry to `secrets/common.yaml` **before encryption**:

```yaml
perplexity_api_key: pplx-replace-with-your-api-key
```

3. Encrypt and update the file with:

```bash
sops --encrypt --in-place secrets/common.yaml
```

4. Rebuild each desktop host:

```bash
sudo nixos-rebuild switch --flake .#navi
sudo nixos-rebuild switch --flake .#oryx
```

## Verify

```bash
sudo test -r /run/secrets/perplexity_api_key && echo 'secret rendered'
opencode mcp list
```

The key is owned by `aljam`, has mode `0400`, and is not stored in the Nix store or committed in plaintext.
