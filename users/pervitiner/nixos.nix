{ config, pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.pervitiner = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBACxo+iDe4wrlplJkk154X7Lx01mYVZp0yGJiAhqs3JkxTIISNjt+aNeEd/PleZzQH4lmm3JCFvGhP3lpTdGwyQezwEagUUceJIc2ITmx5OWGalo909SkQD9Uz0n8ZR/JmJeeH6LTRCfKQmVg2KZsD8yn3qHnovWhFsJ8ibOrRUfr1ybpg== johnsmith@Johns-MacBook-Pro.local"
    ];
  };
}
