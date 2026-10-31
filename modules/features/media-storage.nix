# Shared media storage ownership.
#
# Service modules may add their service users to the `media` group. Media
# directories should be group-writable and setgid `media` so files created by
# one service remain accessible to the others.
{
  ...
}:

{
  users.groups.media = { };
}
