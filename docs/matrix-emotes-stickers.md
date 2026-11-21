# Matrix emotes and stickers

This repository uses [MSC2545 image packs](https://github.com/matrix-org/matrix-spec-proposals/blob/main/proposals/2545-emotes.md)
for custom emotes and stickers.

MSC2545 is a client-side Matrix feature. It does not require a homeserver integration,
a separate sticker service, or a public integration manager. Pack metadata is stored in
Matrix room state, while the underlying images are uploaded to the Matrix media repository.

## Scope

This feature provides:

- Custom inline emotes.
- Custom stickers.
- Reusable image packs.
- A dedicated private room for pack management.
- An opt-in administrative workflow for creating and updating packs.

It does not provide:

- A public sticker API.
- A Telegram sticker bridge.
- An always-running bot service.
- Public access to private packs.

## Pack room

Create a dedicated private Matrix room named:

```text
Emotes and Stickers
```

Use this room as the authoritative source for all emote and sticker packs.

Recommended room settings:

| Setting | Value |
|---|---|
| Visibility | Private |
| Join rule | Invite only |
| History visibility | Shared |
| Encryption | Disabled |
| Purpose | Matrix image-pack management |

Encryption should remain disabled for the pack room. MSC2545 image-pack state must be
readable by the clients and accounts that need to use the packs.

Do not use the primary personal Matrix account as the pack-management identity.

## Management account

Create a dedicated Matrix account for pack administration, for example:

```text
stickers@<matrix-domain>
```

This account should:

- Be a member of the `Emotes and Stickers` room.
- Have permission to send messages and update room state.
- Be excluded from normal personal messaging use.
- Use a long, unique password stored in the password manager.
- Use an access token stored in SOPS.

The account does not need homeserver administrator privileges.

## SOPS secret

Store the management access token in SOPS using the existing repository secret workflow.

Recommended secret key:

```yaml
matrix_stickers_manager_access_token: <access-token>
```

Do not commit the access token, password, recovery key, or pack-room ID in plaintext.

Rotate the access token if:

- It may have been exposed.
- The management account password changes.
- The account is no longer needed.
- The token has not been rotated during routine secret rotation.

## Managing packs

`matrix-stickers-manager` is an opt-in tool for creating and maintaining MSC2545 image packs.

Install it in an isolated Python environment:

```bash
python3 -m venv .venv-matrix-stickers
source .venv-matrix-stickers/bin/activate
python3 -m pip install matrix-stickers-manager
```

Set the homeserver URL and access token from SOPS:

```bash
export MATRIX_HOMESERVER_URL="https://matrix.example.com"
export MATRIX_ACCESS_TOKEN="$(sops -d secrets/matrix.yaml | yq '.matrix_stickers_manager_access_token')"
```

The exact SOPS file and secret key must match the repository’s existing SOPS layout.

### Create a pack

```bash
matrix-stickers-manager pack create \
  --room '<pack-room-id>' \
  --name 'Homelab Emotes' \
  --image ./pack/emote.png \
  --shortcode 'homelab'
```

### List packs

```bash
matrix-stickers-manager pack list \
  --room '<pack-room-id>'
```

### Add an image

```bash
matrix-stickers-manager pack add \
  --room '<pack-room-id>' \
  --name 'Homelab Emotes' \
  --image ./pack/new-emote.png \
  --shortcode 'newemote'
```

### Remove an image

```bash
matrix-stickers-manager pack remove \
  --room '<pack-room-id>' \
  --name 'Homelab Emotes' \
  --shortcode 'newemote'
```

### Delete a pack

```bash
matrix-stickers-manager pack delete \
  --room '<pack-room-id>' \
  --name 'Homelab Emotes'
```

Use shortcodes that are unique within a pack. Avoid embedding private information,
internal hostnames, credentials, or unreleased project names in emote or sticker assets.

## Client support

MSC2545 image packs are supported by:

- Element Web and Element Desktop.
- Cinny.
- FluffyChat.
- Nheko.

Client support can vary by version and platform. A pack may be visible in one client but
not usable in another if that client has not implemented the relevant MSC2545 behavior.

## Validation

After creating or updating a pack:

1. Join the `Emotes and Stickers` room from a supported client.
2. Confirm the pack appears in the client’s emote or sticker picker.
3. Send an emote as an inline image.
4. Send a sticker.
5. Confirm the image renders correctly.
6. Confirm the pack is not visible to accounts that have not been invited.
7. Confirm the management access token remains stored only in SOPS.

## Recovery

If the management account access token is lost:

1. Revoke the old token if possible.
2. Sign in to the management account and create a replacement token.
3. Store the replacement token in SOPS.
4. Rotate the SOPS secret through the normal secret-update workflow.
5. Confirm the management tool can list packs.

If the pack room is lost:

1. Create a replacement private `Emotes and Stickers` room.
2. Invite the management account.
3. Re-upload the pack assets from the retained source files.
4. Publish the replacement image packs.
5. Update any room references that pointed to the former pack room.
6. Verify emotes and stickers in a supported client.

Keep the original emote and sticker source assets in a durable backup location. The Matrix
media repository is not a substitute for retaining the original pack source files.
