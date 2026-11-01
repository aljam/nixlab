# Fleet update process

This repository uses controlled, reviewed updates. Do not enable unattended
upgrades on fleet hosts.

## CI coverage

Pull-request CI builds `navi` to keep routine review inexpensive. Pushes to
`main` and manual workflow runs build all five hosts: `navi`, `oryx`, `r820`,
`r730`, and `r730xd`.

For a high-risk change, run the CI workflow manually from the branch before
merging so the complete fleet is built.

## Regular update flow

1. Create an update branch.
2. Run `nix flake update`.
3. Review the changed lock-file entries, especially `nixpkgs`, `sops-nix`,
   `home-manager`, and any service-specific inputs.
4. Run `nix flake check`.
5. Build every affected host before deployment:

   ```console
   nix build .#nixosConfigurations.<host>.config.system.build.toplevel
   ```

6. Open a pull request and let CI validate the change.
7. Merge only after CI passes.
8. Deploy hosts one at a time:

   ```console
   sudo nixos-rebuild switch --flake .#<host>
   ```

9. Verify critical services after each deployment.

## Deployment order

Deploy desktop hosts and non-critical servers first. Deploy the HAProxy
gateway and media host only after their replacement builds have passed CI.

After deploying a host, check:

```console
systemctl --failed
systemctl status haproxy.service
systemctl status postgresql.service
systemctl status prometheus-node-exporter.service
```

For the media host, also verify that the Servarr services are active and that
new files under `/mnt/media` retain the shared `media` group ownership.

## Rollback

If a deployment causes a regression, roll back to the previous system
generation:

```console
sudo nixos-rebuild switch --rollback
```

Then investigate the failed generation before attempting another deployment.

## Dependency updates

The `updates` workflow opens a weekly pull request containing an updated
`flake.lock`. Review its changed inputs, run the normal validation flow, and
merge only when CI passes.

Dependabot opens weekly pull requests for GitHub Actions dependency updates.
Review each workflow change before merging.

Container images are intentionally excluded from automatic updates for now.
When floating image tags are pinned, revisit automated image-update pull
requests and image scanning.
