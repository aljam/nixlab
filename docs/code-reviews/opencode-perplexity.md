# Code review: OpenCode + Perplexity MCP

## Scope
Adds nixpkgs `opencode` (CLI) to the shared Home Manager profile so every host gets it, plus a declarative `opencode.json` with the Perplexity MCP server.

## KISS / DRY
- One module, imported once in `home.nix`; no per-host duplication.
- Config generated with `pkgs.formats.json`.

## Security
- No secret in the repo or Nix store. A wrapper reads `/run/secrets/perplexity_api_key` at launch and exports it only to the process.
- If the file is absent the wrapper does nothing, so this PR is safe to merge before the secret exists.
- The MCP server runs via `npx` (fetches `@perplexity-ai/mcp-server` at first run). Pinning it in Nix is a possible follow-up.

## Not included
- OpenCode Desktop (not in nixpkgs; needs a flake input, separate PR).
- sops secret declaration (draft PR).

## Test
`nixos-rebuild build --flake .#navi` and `.#oryx`, then `opencode mcp list`.
