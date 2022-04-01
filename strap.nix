File 5 of 5
Prev
Up
Next
Base
 browse → 
Patchset 5
 browse
Diff view:
{ lib, pkgs, ... }:
let
  inherit (pkgs)
    cacert
    curl
    makeInitrd
    makeModulesClosure
    nix
    writeText
  ;
  modulesClosure = pkgs.makeModulesClosure {
    kernel = pkgs.linux;
    firmware = pkgs.linux;
    rootModules = [
      "af_packet" "ext4" "sd_mod" "virtio_blk" "virtio_net"
      "virtio_pci" "virtio_rng" "virtio_scsi"
      "vfat" "nls_cp437" "nls_iso8859_1" "efivarfs"
    ];
    allowMissing = false;
  };
  # systemd is an optional dependency of iputils, override it ourselves
  dhcp = pkgs.dhcp.override {
    iputils = pkgs.iputils.override { systemd = null; };
    openldap = null;
  };
  # Nix complains when there is no /etc/passwd
  passwd = writeText "passwd" ''
    root:x:0:0:System administrator:/:/
  '';
  nixosenter = pkgs.substituteAll {
    src = ../third_party/nixpkgs/nixos/modules/installer/tools/nixos-enter.sh;
    inherit (pkgs) runtimeShell;
    isExecutable = true;
  };
  # Build a path containing all packages that are used in nixstrap.
  path = lib.concatStringsSep ":" [
    "${pkgs.execline}/bin"
    # Used for insmod.
    "${pkgs.kmod}/bin"
    # Used to format the disk.
    "${pkgs.e2fsprogs}/bin"
    # echo, touch, mkdir, dd, mount, umount, etc.
    "${pkgs.busybox}/bin"
    # GPT fdisk.
    "${pkgs.gptfdisk}/bin"
    # DHCP client, too lazy to write a udhcpc script.
    "${dhcp}/bin"
    # Using non-musl curl because Nix depends on it either way.
    "${curl}/bin"
    # Nix, obviously. Cannot be compiled with musl for Reasons.
    "${nix}/bin"
  ];
  init = pkgs.substituteAll {
    src = ./init.execline;
    isExecutable = true;
    execline = pkgs.execline;
    inherit cacert nixosenter path modulesClosure;
  };
  # Builds an initrd containing the nixstrap script.
  initrd = pkgs.makeInitrd {
    contents = [
      { object = init; symlink = "/init"; }
      { object = passwd; symlink = "/etc/passwd"; }
    ];
  };
in initrd