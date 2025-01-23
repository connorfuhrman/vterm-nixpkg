{
  description = "Nix Flake for libvterm - A C99 terminal emulator library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem ["aarch64-darwin" "x86_64-darwin"] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        libvtermSrc = pkgs.fetchurl {
          url = "https://launchpad.net/libvterm/trunk/v0.3/+download/libvterm-0.3.3.tar.gz";
          sha256 = "09156f43dd2128bd347cbeebe50d9a571d32c64e0cf18d211197946aff7226e0";
        };
        
        libvterm = pkgs.stdenv.mkDerivation {
          pname = "libvterm";
          version = "0.3.3";

          src = libvtermSrc;

          nativeBuildInputs = [ pkgs.glibtool ];

          buildPhase = ''
            make -j
          '';
          
          installPhase = ''
            make install PREFIX=$out
            install_name_tool -id $out/lib/libvterm.0.dylib $out/lib/libvterm.dylib  # <-- Darwin specific
          '' ;

          meta = with pkgs.lib; {
            description = "C99 library which implements a VT220 or xterm terminal emulator";
            homepage = "https://www.leonerd.org.uk/code/libvterm/";
            license = licenses.mit;
            platforms = platforms.unix;
            maintainers = with maintainers; [ "connorfuhrman" ];
          };
        };

        libvtermCheckFile = pkgs.writeTextFile {
          name = "libvterm-test.c";
          text = ''
            #include <vterm.h>
            int main() {
              vterm_free(vterm_new(1, 1));
              return 0;
            }
          '';
        };

        libvtermCheck = pkgs.runCommand "test-libvterm" { } ''
          export PKG_CONFIG_PATH=${libvterm}/lib/pkgconfig

          # Compile with verbose output
          ${pkgs.gcc}/bin/gcc ${libvtermCheckFile} \
            `${pkgs.pkg-config}/bin/pkg-config --cflags --libs vterm` \
            -o test

          # Try running with debug output
          ./test
          echo "Test passed!"
          touch $out
        '';
        
      in
      {

        packages = {
          inherit libvterm;
          default = libvterm;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ libvterm ];
          packages = with pkgs; [
            pkg-config
            gcc
          ];


          shellHook = ''
            ${pkgs.coreutils}/bin/cat ${libvtermCheckFile} > libvterm-test.c
            ${pkgs.gnutar}/bin/tar -xzf ${libvtermSrc}
          '';
        };

        checks.default = libvtermCheck;
      });
}
