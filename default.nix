{ pkgs, ... } @ args:

let

  kernel = pkgs.linux;
  initrd = import ./strap.nix args;

in

  # Builds a tarball containing a disk image that can be imported into Google Cloud Platform.
  (pkgs.runCommandNoCC "nixstrap.tar.gz" {
    inherit (pkgs) dosfstools mtools syslinux systemd utillinux;
    binutils = pkgs.binutils-unwrapped;
    inherit initrd kernel;
  }
  ''
    mkdir -p esp/efi/boot/

    echo 'console=ttyS0,115200' > cmdline.txt
    $binutils/bin/objcopy \
      --add-section .cmdline="cmdline.txt" --change-section-vma .cmdline=0x30000 \
      --add-section .linux="$kernel/bzImage" --change-section-vma .linux=0x2000000 \
      --add-section .initrd="$initrd/initrd" --change-section-vma .initrd=0x3000000 \
      "$systemd/lib/systemd/boot/efi/linuxx64.efi.stub" esp/efi/boot/bootx64.efi

    # a 200MB ESP oughta be enough.
    truncate -s 200M esp.raw
    $dosfstools/bin/mkfs.vfat esp.raw

    # Use mtools, so we do not need to require kvm to build this image.
    $mtools/bin/mcopy -i esp.raw -s esp/efi ::

    # GCP disks have to be a multiple of 1GB.
    truncate -s 1G disk.raw
    $utillinux/bin/sfdisk disk.raw << EOF
    label: gpt
    label-id: C972B21D-9681-7345-824D-4FFD470ADF81

    start=2048, size=409600, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=D9CB2631-85EC-3442-BAFC-96B20E615A23, name=boot
    EOF

    dd if=esp.raw of=disk.raw seek=2048 bs=512 conv=notrunc

    # Google Cloud requires that the disk image is compresed using format=oldgnu.
    # https://cloud.google.com/compute/docs/import/import-existing-image#requirements_for_the_image_file
    tar --format=oldgnu -czf $out disk.raw
  '') // { deploy = import ./deploy.nix args; }