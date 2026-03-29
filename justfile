prettify-bash file:
  nix shell nixpkgs#shfmt -c shfmt -i 4 -ci -sr -w {{file}}

