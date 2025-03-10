{ stdenv, fetchurl, makeWrapper, pkg-config, gtk2, gtk2-x11
, gtkspell2, aspell
, gst_all_1, startupnotification, gettext
, perlPackages, libxml2, nss, nspr, farstream
, libXScrnSaver, avahi, dbus, dbus-glib, intltool, libidn
, lib, python3, libICE, libXext, libSM
, libgnt, ncurses
, cyrus_sasl ? null
, openssl ? null
, gnutls ? null
, libgcrypt ? null
, plugins, symlinkJoin
, cacert
}:

# FIXME: clean the mess around choosing the SSL library (nss by default)

let unwrapped = stdenv.mkDerivation rec {
  pname = "pidgin";
  majorVersion = "2";
  version = "${majorVersion}.14.8";

  src = fetchurl {
    url = "mirror://sourceforge/pidgin/${pname}-${version}.tar.bz2";
    sha256 = "1jjc15pfyw3012q5ffv7q4r88wv07ndqh0wakyxa2k0w4708b01z";
  };

  nativeBuildInputs = [ makeWrapper ];

  NIX_CFLAGS_COMPILE = "-I${gst_all_1.gst-plugins-base.dev}/include/gstreamer-1.0";

  buildInputs = let
    python-with-dbus = python3.withPackages (pp: with pp; [ dbus-python ]);
  in [
    aspell startupnotification
    gst_all_1.gstreamer gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good
    libxml2 nss nspr
    libXScrnSaver python-with-dbus
    avahi dbus dbus-glib intltool libidn
    libICE libXext libSM cyrus_sasl
    libgnt ncurses # optional: build finch - the console UI
  ]
  ++ (lib.optional (openssl != null) openssl)
  ++ (lib.optional (gnutls != null) gnutls)
  ++ (lib.optional (libgcrypt != null) libgcrypt)
  ++ (lib.optionals (stdenv.isLinux) [gtk2 gtkspell2 farstream])
  ++ (lib.optional (stdenv.isDarwin) gtk2-x11);


  propagatedBuildInputs = [ pkg-config gettext ]
    ++ (with perlPackages; [ perl XMLParser ])
    ++ (lib.optional (stdenv.isLinux) gtk2)
    ++ (lib.optional (stdenv.isDarwin) gtk2-x11);

  patches = [ ./pidgin-makefile.patch ./add-search-path.patch ];

  configureFlags = [
    "--with-nspr-includes=${nspr.dev}/include/nspr"
    "--with-nspr-libs=${nspr.out}/lib"
    "--with-nss-includes=${nss.dev}/include/nss"
    "--with-nss-libs=${nss.out}/lib"
    "--with-ncurses-headers=${ncurses.dev}/include"
    "--with-system-ssl-certs=${cacert}/etc/ssl/certs"
    "--disable-meanwhile"
    "--disable-nm"
    "--disable-tcl"
    "--disable-gevolution"
  ]
  ++ (lib.optionals (cyrus_sasl != null) [ "--enable-cyrus-sasl=yes" ])
  ++ (lib.optionals (gnutls != null) ["--enable-gnutls=yes" "--enable-nss=no"])
  ++ (lib.optionals (stdenv.isDarwin) ["--disable-gtkspell" "--disable-vv"]);

  enableParallelBuilding = true;

  postInstall = ''
    wrapProgram $out/bin/pidgin \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "$GST_PLUGIN_SYSTEM_PATH_1_0"
  '';

  doInstallCheck = stdenv.hostPlatform == stdenv.buildPlatform;
  # In particular, this detects missing python imports in some of the tools.
  postFixup = let
    # TODO: python is a script, so it doesn't work as interpreter on darwin
    binsToTest = lib.optionalString stdenv.isLinux "purple-remote," + "pidgin,finch";
  in lib.optionalString doInstallCheck ''
    for f in "''${!outputBin}"/bin/{${binsToTest}}; do
      echo "Testing: $f --help"
      "$f" --help
    done
  '';

  passthru = {
    makePluginPath = lib.makeSearchPathOutput "lib" "lib/purple-${majorVersion}";
  };

  meta = with lib; {
    description = "Multi-protocol instant messaging client";
    homepage = "http://pidgin.im";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
    maintainers = [ maintainers.vcunat ];
  };
};

in if plugins == [] then unwrapped
    else import ./wrapper.nix {
      inherit makeWrapper symlinkJoin plugins;
      pidgin = unwrapped;
    }
