As an alternative to building perl in-tree, (see
https://github.com/dirk-dhu/freetz/tree/master/make/perl
), here are the steps to do this manually, if your
freetz distribution lacks make/perl package or have
trouble using the automated build.

To cross-compile perl and integrate it manually
into a freetz build, here is a rough guideline,
tried and tested:

  perl-5.26.2.tar.gz
  perl-cross-1.1.9.tar.gz   (unpack over perl-5.26.2 source)

compile freetz with the following line in .config to setup all the links for perl
---------------------------------------------------------------------------------
  EXTERNAL_OWN_FILES="/usr/bin/corelist /usr/bin/cpan /usr/bin/enc2xs /usr/bin/encguess /usr/bin/h2ph /usr/bin/h2xs /usr/bin/instmodsh /usr/bin/json_pp /usr/bin/libnetcfg /usr/bin/perl /usr/bin/perlbug /usr/bin/perldoc /usr/bin/perlivp /usr/bin/perlthanks /usr/bin/piconv /usr/bin/pl2pm /usr/bin/pod2html /usr/bin/pod2man /usr/bin/pod2text /usr/bin/pod2usage /usr/bin/podchecker /usr/bin/podselect /usr/bin/prove /usr/bin/ptar /usr/bin/ptardiff /usr/bin/ptargrep /usr/bin/shasum /usr/bin/splain /usr/bin/xsubpp /usr/bin/zipdetails /usr/lib/perl5"

compile perl and integrate into freetz image using
---------------------------------------------
  cd perl-src-dir

  export PATH="$PATH:$FREETZDIR/toolchain/build/mips_gcc-4.8.5_uClibc-0.9.33.2-nptl/mips-linux-uclibc/bin/"

  ./configure --target=mips-linux-uclibc --target-tools-prefix=mips-linux-uclibc
  make
  make DESTDIR=$FREETZDIR/build/modified/external

  # do not distribute man page to embedded system
  rm -rvf $FREETZDIR/build/modified/external/usr/share/man

  # repack image to reflect modified/external state
  FREETZ_FWMOD_SKIP_UNPACK=y FREETZ_FWMOD_SKIP_MODIFY=y make firmware-nocompile


The resulting firmware will work to run zimHttpServer32 on Fritz!Box
router hardware in combination with the machine-endianess-tolerant
zimHttpServer.pl in this repo-sitory.

