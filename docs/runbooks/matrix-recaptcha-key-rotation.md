# Matrix reCAPTCHA key rotation

This runbook rotates the Matrix Synapse reCAPTCHA site and secret keys.

The credentials are stored in `secrets/matrix.yaml` as:

- `matrix-recaptcha-site-key`
- `matrix-recaptcha-secret-key`

Do not commit plaintext reCAPTCHA credentials.

## Rotation procedure

1. Create a new reCAPTCHA site key for `matrix.derezzed.info` in the Google
   reCAPTCHA console.
2. Copy the new site key and secret key.
3. Run:

   ```bash
   sops secrets/matrix.yaml
   ```

4. Replace the values for `matrix-recaptcha-site-key` and
   `matrix-recaptcha-secret-key` with the new credentials.
5. Save and close the editor so SOPS re-encrypts the values.
6. Confirm the diff contains only the two encrypted SOPS values:

   ```bash
   git diff -- secrets/matrix.yaml
   ```

7. Run:

   ```bash
   nix flake check --show-trace
   ```

8. Commit and push the updated SOPS file to this branch.
9. Merge the pull request and deploy the affected Matrix host.
10. Verify that Matrix registration CAPTCHA validation works.
11. Delete the prior reCAPTCHA key in the Google reCAPTCHA console.

## Safety boundary

Delete the old reCAPTCHA key only after the replacement keys have been
merged, deployed, and verified. Deleting the old key before deployment can
break Matrix registration CAPTCHA validation.
