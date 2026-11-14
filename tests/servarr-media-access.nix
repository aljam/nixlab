# Servarr shared-media access test.
#
# Verifies that Servarr service users can create and read files through the
# shared `media` group, while an unrelated user cannot access the media tree.
{
  lib,
  ...
}:

let
  mediaRoot = "/srv/media-test";

  makeUser = name: {
    isNormalUser = true;
    extraGroups = [ "media" ];
  };

  unrelatedUser = {
    isNormalUser = true;
  };
in
{
  name = "servarr-media-access";

  nodes = {
    media = { pkgs, ... }: {
      users.groups.media = { };

      users.users = {
        radarr = makeUser "radarr";
        sonarr = makeUser "sonarr";
        unrelated = unrelatedUser;
      };

      systemd.tmpfiles.rules = [
        "d ${mediaRoot} 2775 root media -"
      ];

      environment.systemPackages = [ pkgs.coreutils ];
    };
  };

  testScript = ''
    start_all()

    media.wait_for_unit("multi-user.target", timeout=120)

    with subtest("the shared media directory has the intended group policy"):
        media.succeed(
            "test -d ${mediaRoot}"
        )
        media.succeed(
            "stat -c '%a %U %G' ${mediaRoot} | grep -q '2775 root media'"
        )

    with subtest("a Servarr service user can create media"):
        media.succeed(
            "sudo -u radarr install -m 0660 /dev/null ${mediaRoot}/radarr-created"
        )

    with subtest("another Servarr service user can read media created by the first"):
        media.succeed(
            "sudo -u sonarr test -r ${mediaRoot}/radarr-created"
        )

    with subtest("an unrelated user cannot read shared media"):
        media.fail(
            "sudo -u unrelated test -r ${mediaRoot}/radarr-created"
        )

    with subtest("an unrelated user cannot create media"):
        media.fail(
            "sudo -u unrelated install -m 0660 /dev/null ${mediaRoot}/unrelated-created"
        )
  '';
}
