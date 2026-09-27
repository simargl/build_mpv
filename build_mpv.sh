#!/bin/bash
#
# Build static mpv 0.32.0 + FFmpeg 4.3
# with AV1 playback through dav1d.
#
# Creates:
#   /tmp/mpv-build/mpv.sb
#
# Also bundles:
#   mpv
#   yt-dlp
#
# Original author: simargl
# License: GPL v3
#

set -e

###############################################################################
# VARIABLES
###############################################################################

HOMEDIR="${HOMEDIR:-/tmp/mpv-build}"
SRCDIR="$HOMEDIR/src"
PKGDIR="$HOMEDIR/pkg"
BUILDDIR="$HOMEDIR/build"

CONFIGURE_ARGS="\
--prefix=$PKGDIR \
--disable-shared \
--enable-static \
--disable-examples \
--disable-unit-tests"

CMAKE_ARGS="\
-DCMAKE_INSTALL_PREFIX=$PKGDIR \
-DCMAKE_INSTALL_LIBDIR=lib \
-DBUILD_SHARED_LIBS=OFF"

export PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig"
export PATH="$PKGDIR/bin:$PATH"
export LD_LIBRARY_PATH="$PKGDIR/lib:${LD_LIBRARY_PATH:-}"

###############################################################################
# SOURCE ARCHIVES
###############################################################################

SOURCESURL="\
http://deb.debian.org/debian/pool/main/e/expat/expat_2.1.0.orig.tar.gz \
http://deb.debian.org/debian/pool/main/libp/libpng/libpng_1.2.50.orig.tar.xz \
http://ijg.org/files/jpegsrc.v9c.tar.gz \
http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz \
https://download.videolan.org/contrib/nasm/nasm-2.13.03.tar.gz \
http://archive.ubuntu.com/ubuntu/pool/main/c/cmake/cmake_2.8.12.2.orig.tar.gz \
http://download.videolan.org/pub/x264/snapshots/x264-snapshot-20180817-2245-stable.tar.bz2 \
http://ftp.videolan.org/pub/videolan/x265/x265_2.8.tar.gz \
http://deb.debian.org/debian/pool/non-free/f/fdk-aac/fdk-aac_0.1.4.orig.tar.gz \
http://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz \
http://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.2.1.tar.gz \
https://download.videolan.org/contrib/vpx/libvpx-1.4.0.tar.bz2 \
http://cdn-fastly.deb.debian.org/debian/pool/main/f/fribidi/fribidi_1.0.5.orig.tar.bz2 \
http://download.videolan.org/contrib/ass/libass-0.13.0.tar.gz \
http://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.3.tar.gz \
http://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.6.tar.gz \
http://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.bz2 \
http://cdn-fastly.deb.debian.org/debian/pool/main/libs/libsoxr/libsoxr_0.1.2.orig.tar.xz \
http://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.3.2.tar.xz \
http://ftp.osuosl.org/pub/xiph/releases/speex/speex-1.2.0.tar.gz \
https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/openjpeg2/2.1.2-1.1+deb9u2build0.1/openjpeg2_2.1.2.orig.tar.gz \
http://cdn-fastly.deb.debian.org/debian/pool/main/o/opencore-amr/opencore-amr_0.1.3.orig.tar.gz \
http://www.wavpack.com/wavpack-5.1.0.tar.bz2 \
http://archive.ubuntu.com/ubuntu/pool/universe/v/vo-aacenc/vo-aacenc_0.1.3.orig.tar.gz \
http://prdownloads.sourceforge.net/libcddb/libcddb-1.3.2.tar.bz2 \
http://ftp.gnu.org/gnu/libcdio/libcdio-2.0.0.tar.bz2 \
http://ftp.gnu.org/gnu/libcdio/libcdio-paranoia-10.2+0.94+2.tar.gz \
http://download.videolan.org/pub/videolan/libdvdcss/1.4.2/libdvdcss-1.4.2.tar.bz2 \
http://download.videolan.org/pub/videolan/libdvdread/6.0.0/libdvdread-6.0.0.tar.bz2 \
http://download.videolan.org/pub/videolan/libdvdnav/6.0.0/libdvdnav-6.0.0.tar.bz2 \
http://luajit.org/download/LuaJIT-2.0.5.tar.gz \
http://ftp.debian.org/debian/pool/main/e/enca/enca_1.19.orig.tar.gz \
https://dri.freedesktop.org/libdrm/libdrm-2.4.89.tar.bz2 \
https://downloads.videolan.org/pub/videolan/dav1d/0.7.1/dav1d-0.7.1.tar.xz \
https://ffmpeg.org/releases/ffmpeg-4.3.tar.xz \
http://deb.debian.org/debian/pool/main/m/mpv/mpv_0.32.0.orig.tar.gz"

###############################################################################
# PREPARE
###############################################################################

mkdir -p \
    "$SRCDIR" \
    "$PKGDIR" \
    "$BUILDDIR"

###############################################################################
# DOWNLOAD
###############################################################################

download_file()
{
    URL="$1"
    FILE="$2"

    if [ -s "$FILE" ]; then
        echo "Already downloaded: $(basename "$FILE")"
        return
    fi

    echo
    echo "Downloading:"
    echo "  $URL"

    wget \
        --no-check-certificate \
        --continue \
        --show-progress \
        -O "$FILE" \
        "$URL"

    if [ ! -s "$FILE" ]; then
        echo "ERROR: download failed:"
        echo "$URL"
        exit 1
    fi
}

cd "$SRCDIR"

for URL in $SOURCESURL; do
    FILE="$SRCDIR/$(basename "$URL")"
    download_file "$URL" "$FILE"
done

###############################################################################
# GENERIC AUTOTOOLS BUILD
###############################################################################

compile_autoconf()
{
    ARCHIVE="$1"
    SOURCE_DIR="$2"

    echo
    echo "=================================================="
    echo "Compiling $ARCHIVE"
    echo "=================================================="

    rm -rf "$SOURCE_DIR"

    tar -xf "$SRCDIR/$ARCHIVE" -C "$BUILDDIR"

    cd "$SOURCE_DIR"

    if [ ! -f configure ]; then
        autoreconf -vfi
    fi

    ./configure $CONFIGURE_ARGS

    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
}

###############################################################################
# GENERIC CMAKE BUILD
###############################################################################

compile_cmake()
{
    ARCHIVE="$1"
    SOURCE_DIR="$2"

    echo
    echo "=================================================="
    echo "Compiling $ARCHIVE"
    echo "=================================================="

    rm -rf "$SOURCE_DIR"

    tar -xf "$SRCDIR/$ARCHIVE" -C "$BUILDDIR"

    cd "$SOURCE_DIR"

    rm -rf build
    mkdir build
    cd build

    cmake .. $CMAKE_ARGS

    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
}

###############################################################################
# BASIC LIBRARIES
###############################################################################

if [ ! -f "$PKGDIR/lib/libexpat.a" ]; then
    compile_autoconf \
        expat_2.1.0.orig.tar.gz \
        "$BUILDDIR/expat-2.1.0"
fi

if [ ! -f "$PKGDIR/lib/libjpeg.a" ]; then

    rm -rf "$BUILDDIR/jpeg-9c"
    tar -xf "$SRCDIR/jpegsrc.v9c.tar.gz" -C "$BUILDDIR"

    cd "$BUILDDIR/jpeg-9c"

    ./configure $CONFIGURE_ARGS
    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
fi

if [ ! -f "$PKGDIR/lib/libpng.a" ]; then
    compile_autoconf \
        libpng_1.2.50.orig.tar.xz \
        "$BUILDDIR/libpng-1.2.50"
fi

###############################################################################
# YASM
###############################################################################

if [ ! -f "$PKGDIR/bin/yasm" ]; then
    compile_autoconf \
        yasm-1.3.0.tar.gz \
        "$BUILDDIR/yasm-1.3.0"
fi

###############################################################################
# NASM
###############################################################################

if [ ! -f "$PKGDIR/bin/nasm" ]; then
    compile_autoconf \
        nasm-2.13.03.tar.gz \
        "$BUILDDIR/nasm-2.13.03"
fi

###############################################################################
# CMAKE
###############################################################################

if [ ! -x "$PKGDIR/bin/cmake" ]; then

    echo
    echo "=================================================="
    echo "Compiling CMake 2.8.12.2"
    echo "=================================================="

    rm -rf "$BUILDDIR/cmake-2.8.12.2"

    tar -xf "$SRCDIR/cmake_2.8.12.2.orig.tar.gz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/cmake-2.8.12.2"

    ./bootstrap --prefix="$PKGDIR"

    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
fi

###############################################################################
# X264
###############################################################################

if [ ! -f "$PKGDIR/lib/libx264.a" ]; then
    compile_autoconf \
        x264-snapshot-20180817-2245-stable.tar.bz2 \
        "$BUILDDIR/x264-snapshot-20180817-2245-stable"
fi

###############################################################################
# X265
###############################################################################

if [ ! -f "$PKGDIR/lib/libx265.a" ]; then

    rm -rf "$BUILDDIR/x265_2.8"

    tar -xf "$SRCDIR/x265_2.8.tar.gz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/x265_2.8/source"

    rm -rf build
    mkdir build
    cd build

    cmake .. $CMAKE_ARGS

    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
fi

###############################################################################
# FDK AAC
###############################################################################

if [ ! -f "$PKGDIR/lib/libfdk-aac.a" ]; then
    compile_autoconf \
        fdk-aac_0.1.4.orig.tar.gz \
        "$BUILDDIR/fdk-aac-0.1.4"
fi

###############################################################################
# LAME
###############################################################################

if [ ! -f "$PKGDIR/lib/libmp3lame.a" ]; then
    compile_autoconf \
        lame_3.100.orig.tar.gz \
        "$BUILDDIR/lame-3.100"
fi

###############################################################################
# OPUS
###############################################################################

if [ ! -f "$PKGDIR/lib/libopus.a" ]; then
    compile_autoconf \
        opus-1.2.1.tar.gz \
        "$BUILDDIR/opus-1.2.1"
fi

###############################################################################
# VPX
###############################################################################

if [ ! -f "$PKGDIR/lib/libvpx.a" ]; then

    echo
    echo "=================================================="
    echo "Compiling libvpx 1.4.0"
    echo "=================================================="

    rm -rf "$BUILDDIR/libvpx-1.4.0"

    tar -xf "$SRCDIR/libvpx-1.4.0.tar.bz2" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/libvpx-1.4.0"

    ./configure \
        --prefix="$PKGDIR" \
        --disable-shared \
        --enable-static \
        --disable-unit-tests

    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
fi

###############################################################################
# FRIBIDI
###############################################################################

if [ ! -f "$PKGDIR/lib/libfribidi.a" ]; then
    compile_autoconf \
        fribidi_1.0.5.orig.tar.bz2 \
        "$BUILDDIR/fribidi-1.0.5"
fi

###############################################################################
# LIBASS
###############################################################################

if [ ! -f "$PKGDIR/lib/libass.a" ]; then
    compile_autoconf \
        libass-0.13.0.tar.gz \
        "$BUILDDIR/libass-0.13.0"
fi

###############################################################################
# OGG / VORBIS
###############################################################################

if [ ! -f "$PKGDIR/lib/libvorbis.a" ]; then

    compile_autoconf \
        libogg-1.3.3.tar.gz \
        "$BUILDDIR/libogg-1.3.3"

    compile_autoconf \
        libvorbis-1.3.6.tar.gz \
        "$BUILDDIR/libvorbis-1.3.6"
fi

###############################################################################
# THEORA
###############################################################################

if [ ! -f "$PKGDIR/lib/libtheora.a" ]; then
    compile_autoconf \
        libtheora-1.1.1.tar.bz2 \
        "$BUILDDIR/libtheora-1.1.1"
fi

###############################################################################
# SOXR
###############################################################################

if [ ! -f "$PKGDIR/lib/libsoxr.a" ]; then
    compile_cmake \
        libsoxr_0.1.2.orig.tar.xz \
        "$BUILDDIR/soxr-0.1.2-Source"
fi

###############################################################################
# FLAC
###############################################################################

if [ ! -f "$PKGDIR/lib/libFLAC.a" ]; then
    compile_autoconf \
        flac-1.3.2.tar.xz \
        "$BUILDDIR/flac-1.3.2"
fi

###############################################################################
# SPEEX
###############################################################################

if [ ! -f "$PKGDIR/lib/libspeex.a" ]; then
    compile_autoconf \
        speex-1.2.0.tar.gz \
        "$BUILDDIR/speex-1.2.0"
fi

###############################################################################
# OPENJPEG
###############################################################################

if [ ! -f "$PKGDIR/lib/libopenjp2.a" ]; then

    echo
    echo "=================================================="
    echo "Compiling OpenJPEG"
    echo "=================================================="

    rm -rf "$BUILDDIR/openjpeg-2.1.2"

    tar -xf "$SRCDIR/openjpeg2_2.1.2.orig.tar.gz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/openjpeg-2.1.2"

    mkdir build
    cd build

    sed \
        's/VERSION 2.8.2/VERSION 2.8.0/g' \
        -i ../CMakeLists.txt

    cmake .. $CMAKE_ARGS

    make -j"$(nproc)"
    make install

    cp \
        bin/libopenjp2.a \
        "$PKGDIR/lib/libopenjp2.a"

    cd "$SRCDIR"
fi

###############################################################################
# OPENCORE AMR
###############################################################################

if [ ! -f "$PKGDIR/lib/libopencore-amrnb.a" ]; then
    compile_autoconf \
        opencore-amr_0.1.3.orig.tar.gz \
        "$BUILDDIR/opencore-amr-0.1.3"
fi

###############################################################################
# WAVPACK
###############################################################################

if [ ! -f "$PKGDIR/lib/libwavpack.a" ]; then
    compile_autoconf \
        wavpack-5.1.0.tar.bz2 \
        "$BUILDDIR/wavpack-5.1.0"
fi

###############################################################################
# VO-AACENC
###############################################################################

if [ ! -f "$PKGDIR/lib/libvo-aacenc.a" ]; then
    compile_autoconf \
        vo-aacenc_0.1.3.orig.tar.gz \
        "$BUILDDIR/vo-aacenc-0.1.3"
fi

###############################################################################
# CDIO
###############################################################################

if [ ! -f "$PKGDIR/lib/libcdio.a" ]; then

    compile_autoconf \
        libcddb-1.3.2.tar.bz2 \
        "$BUILDDIR/libcddb-1.3.2"

    compile_autoconf \
        libcdio-2.0.0.tar.bz2 \
        "$BUILDDIR/libcdio-2.0.0"

    compile_autoconf \
        libcdio-paranoia-10.2+0.94+2.tar.gz \
        "$BUILDDIR/libcdio-paranoia-10.2+0.94+2"
fi

###############################################################################
# DVD
###############################################################################

if [ ! -f "$PKGDIR/lib/libdvdnav.a" ]; then

    compile_autoconf \
        libdvdcss-1.4.2.tar.bz2 \
        "$BUILDDIR/libdvdcss-1.4.2"

    compile_autoconf \
        libdvdread-6.0.0.tar.bz2 \
        "$BUILDDIR/libdvdread-6.0.0"

    compile_autoconf \
        libdvdnav-6.0.0.tar.bz2 \
        "$BUILDDIR/libdvdnav-6.0.0"
fi

###############################################################################
# LUAJIT
###############################################################################

if [ ! -f "$PKGDIR/lib/libluajit-5.1.a" ]; then

    echo
    echo "=================================================="
    echo "Compiling LuaJIT"
    echo "=================================================="

    rm -rf "$BUILDDIR/LuaJIT-2.0.5"

    tar -xf "$SRCDIR/LuaJIT-2.0.5.tar.gz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/LuaJIT-2.0.5"

    sed \
        -i "s| PREFIX=.*| PREFIX=$PKGDIR|" \
        Makefile

    PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig" \
        make -j"$(nproc)"

    make install

    cd "$SRCDIR"
fi

###############################################################################
# ENCA
###############################################################################

if [ ! -f "$PKGDIR/lib/libenca.a" ]; then
    compile_autoconf \
        enca_1.19.orig.tar.gz \
        "$BUILDDIR/enca-1.19"
fi

###############################################################################
# LIBDRM
###############################################################################

if [ ! -f "$PKGDIR/lib/libdrm.a" ]; then
    compile_autoconf \
        libdrm-2.4.89.tar.bz2 \
        "$BUILDDIR/libdrm-2.4.89"
fi

###############################################################################
# DAV1D - AV1 DECODER
###############################################################################

if [ ! -f "$PKGDIR/lib/libdav1d.a" ]; then

    echo
    echo "=================================================="
    echo "Compiling dav1d 0.7.1 - AV1 decoder"
    echo "=================================================="

    rm -rf "$BUILDDIR/dav1d-0.7.1"

    tar -xf "$SRCDIR/dav1d-0.7.1.tar.xz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/dav1d-0.7.1"

    #
    # dav1d uses Meson/Ninja.
    #
    # The GitHub Actions environment will provide these tools.
    #
    meson setup build \
        --prefix="$PKGDIR" \
        --libdir=lib \
        --buildtype=release \
        -Denable_tools=false \
        -Denable_tests=false

    ninja -C build -j"$(nproc)"
    ninja -C build install

    cd "$SRCDIR"

    if [ ! -f "$PKGDIR/lib/libdav1d.a" ]; then
        echo "ERROR: libdav1d.a was not produced."
        exit 1
    fi
fi

###############################################################################
# OPENSSL
###############################################################################

if [ ! -f "$PKGDIR/lib/libssl.a" ]; then

    echo
    echo "=================================================="
    echo "Compiling OpenSSL 1.0.2d"
    echo "=================================================="

    rm -rf "$BUILDDIR/openssl-1.0.2d"

    tar -xzf "$SRCDIR/openssl-1.0.2d.tar.gz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/openssl-1.0.2d"

    ./config \
        --prefix="$PKGDIR" \
        no-shared

    make -j"$(nproc)"
    make install

    cd "$SRCDIR"
fi

###############################################################################
# REMOVE SHARED LIBRARIES
###############################################################################

rm -f "$PKGDIR"/lib/*.so*
rm -f "$PKGDIR"/lib/*.so.* 2>/dev/null || true

###############################################################################
# FFMPEG
###############################################################################

if [ ! -f "$PKGDIR/lib/libavformat.a" ]; then

    echo
    echo "=================================================="
    echo "Compiling FFmpeg 4.3"
    echo "AV1 decoder: dav1d"
    echo "=================================================="

    rm -rf "$BUILDDIR/ffmpeg-4.3"

    tar -xf "$SRCDIR/ffmpeg-4.3.tar.xz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/ffmpeg-4.3"

    ./configure --help > "$BUILDDIR/ffmpeg.help"

    PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig" \
    PATH="$PKGDIR/bin:$PATH" \
    ./configure \
        --prefix="$PKGDIR" \
        --disable-libxcb \
        --disable-libxcb-shm \
        --disable-libxcb-xfixes \
        --disable-libxcb-shape \
        --disable-xlib \
        --disable-doc \
        --disable-manpages \
        --pkg-config-flags="--static" \
        --disable-shared \
        --enable-static \
        --extra-cflags="-I${PKGDIR}/include" \
        --extra-ldflags="-L${PKGDIR}/lib" \
        --bindir="${PKGDIR}/bin" \
        --enable-gpl \
        --enable-version3 \
        --enable-nonfree \
        --enable-libdav1d \
        --enable-libass \
        --enable-libfreetype \
        --enable-libfdk-aac \
        --enable-libmp3lame \
        --enable-libvpx \
        --enable-libvorbis \
        --enable-libspeex \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-libopus \
        --enable-libtheora \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libxvid \
        --enable-openssl \
        --enable-pthreads \
        --extra-libs=-lpthread \
        --disable-programs \
        --disable-ffprobe \
        --disable-ffplay \
        --disable-sdl2 \
        --disable-encoders \
        --ignore-tests

    #
    # IMPORTANT:
    #
    # --disable-encoders does NOT disable decoders.
    #
    # FFmpeg therefore keeps its built-in AV1 decoder as well,
    # while dav1d provides the optimized external AV1 decoder.
    #

    PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig" \
    PATH="$PKGDIR/bin:$PATH" \
        make -j"$(nproc)"

    make install

    cd "$SRCDIR"
fi

###############################################################################
# MPV
###############################################################################

if [ -f "$PKGDIR/lib/libavformat.a" ] && \
   [ ! -f "$PKGDIR/bin/mpv" ]; then

    echo
    echo "=================================================="
    echo "Compiling mpv 0.32.0"
    echo "=================================================="

    rm -rf "$BUILDDIR/mpv-0.32.0"

    tar -xf "$SRCDIR/mpv_0.32.0.orig.tar.gz" \
        -C "$BUILDDIR"

    cd "$BUILDDIR/mpv-0.32.0"

    if [ ! -f waf ]; then

        wget \
            --no-check-certificate \
            https://www.freehackers.org/~tnagy/release/waf-2.0.20 \
            -O waf

        chmod +x waf
    fi

    PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig" \
    PATH="$PKGDIR/bin:$PATH" \
        ./waf configure \
        --prefix="$PKGDIR"

    PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig" \
    PATH="$PKGDIR/bin:$PATH" \
        ./waf build \
        -j"$(nproc)"

    PKG_CONFIG_PATH="$PKGDIR/lib/pkgconfig" \
    PATH="$PKGDIR/bin:$PATH" \
        ./waf install

    cd "$SRCDIR"
fi

###############################################################################
# VERIFY AV1 SUPPORT
###############################################################################

echo
echo "=================================================="
echo "Checking FFmpeg AV1 support"
echo "=================================================="

if [ -x "$PKGDIR/bin/ffmpeg" ]; then

    "$PKGDIR/bin/ffmpeg" -decoders 2>/dev/null | \
        grep -E 'av1|dav1d' || true

fi

if [ -f "$PKGDIR/lib/libdav1d.a" ]; then
    echo "OK: libdav1d.a found"
else
    echo "ERROR: libdav1d.a missing"
    exit 1
fi

###############################################################################
# YT-DLP
###############################################################################

echo
echo "=================================================="
echo "Installing yt-dlp"
echo "=================================================="

if [ ! -f "$SRCDIR/yt-dlp" ]; then

    wget \
        --no-check-certificate \
        https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux \
        -O "$SRCDIR/yt-dlp"

fi

chmod 755 "$SRCDIR/yt-dlp"

###############################################################################
# CREATE SQUASHFS BUNDLE
###############################################################################

if [ -f "$PKGDIR/bin/mpv" ] && \
   [ ! -d "$HOMEDIR/squashfs-root" ]; then

    echo
    echo "=================================================="
    echo "Making mpv-player bundle"
    echo "=================================================="

    mkdir -p \
        "$HOMEDIR/squashfs-root/usr/bin" \
        "$HOMEDIR/squashfs-root/usr/share/applications"

    ###########################################################################
    # MPV
    ###########################################################################

    cp \
        "$PKGDIR/bin/mpv" \
        "$HOMEDIR/squashfs-root/usr/bin/mpv"

    chmod 755 \
        "$HOMEDIR/squashfs-root/usr/bin/mpv"

    strip \
        "$HOMEDIR/squashfs-root/usr/bin/mpv" || true

    ###########################################################################
    # DESKTOP FILE
    ###########################################################################

    if [ -f "$PKGDIR/share/applications/mpv.desktop" ]; then

        cp \
            "$PKGDIR/share/applications/mpv.desktop" \
            "$HOMEDIR/squashfs-root/usr/share/applications/mpv.desktop"

        echo "NoDisplay=true" >> \
            "$HOMEDIR/squashfs-root/usr/share/applications/mpv.desktop"
    fi

    ###########################################################################
    # YT-DLP
    ###########################################################################

    install -m755 \
        "$SRCDIR/yt-dlp" \
        "$HOMEDIR/squashfs-root/usr/bin/yt-dlp"

    #
    # Compatibility for applications that still call youtube-dl.
    #
    ln -sf \
        yt-dlp \
        "$HOMEDIR/squashfs-root/usr/bin/youtube-dl"

    ###########################################################################
    # SQUASHFS
    ###########################################################################

    cd "$HOMEDIR"

    rm -f "$HOMEDIR/mpv.sb"

    mksquashfs \
        squashfs-root \
        mpv.sb \
        -comp gzip \
        -noappend

    ###########################################################################
    # RESULT
    ###########################################################################

    echo
    echo "=================================================="
    echo "BUILD COMPLETE"
    echo "=================================================="
    echo
    echo "Bundle:"
    echo
    echo "  $HOMEDIR/mpv.sb"
    echo

    ls -lh "$HOMEDIR/mpv.sb"
fi
