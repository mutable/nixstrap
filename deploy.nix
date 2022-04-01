{ pkgs
, platform
, ... }:

let

  inherit (builtins)
    storeDir
    stringLength
    substring
    toJSON
  ;

  inherit (pkgs)
    writeText
  ;

  self = platform.nixstrap;

  hashOfPath = substring (1 + stringLength storeDir) 32;

in

writeText "deploy.tfvars.json" (toJSON {
  nixstrap_path = self.outPath;
  nixstrap_hash = hashOfPath self.outPath;
})
