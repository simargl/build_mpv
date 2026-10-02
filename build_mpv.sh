#!/bin/bash
# 
# Author: simargl <https://github.com/simargl>
# License: GPL v3
# Static mpv 0.35.1 + FFmpeg 4.4.8 + dav1d AV1 + yt-dlp

set -e

ROOT=/tmp/mpv-build
SRC=$ROOT/src
PKG=$ROOT/pkg
BUILD=$ROOT/build
JOBS=${JOBS:-$(nproc)}

mkdir -p "$SRC" "$PKG" "$BUILD"

export PATH="$PKG/bin:$PATH"
export PKG_CONFIG_PATH="$PKG/lib/pkgconfig"
export LD_LIBRARY_PATH="$PKG/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

CONFIG="--prefix=$PKG --disable-shared --enable-static"
CMAKE="cmake -DCMAKE_INSTALL_PREFIX=$PKG -DBUILD_SHARED_LIBS=OFF"

download() {
    local url="$1"
    local file="$SRC/$(basename "$url")"

    if [ -s "$file" ]; then
        echo "==> Already have $(basename "$url")"
        return 0
    fi

    echo "==> Downloading $(basename "$url")"
    wget -O "$file" "$url"

    if [ ! -s "$file" ]; then
        echo "ERROR: download failed: $url"
        rm -f "$file"
        exit 1
    fi
}

build_auto() {
    local archive="$1" dir="$2"
    echo "==> Building $archive"
    rm -rf "$dir"
    tar -xf "$SRC/$archive" -C "$BUILD"
    cd "$dir"

    [ -f configure ] || autoreconf -fiv

    CFLAGS="${CFLAGS:-}" \
    CXXFLAGS="${CXXFLAGS:-}" \
    ./configure $CONFIG

    make -j"$JOBS"
    make install
    cd "$SRC"
}


build_cmake() {
    local archive="$1" dir="$2"
    echo "==> Building $archive"
    rm -rf "$dir"
    tar -xf "$SRC/$archive" -C "$BUILD"
    cd "$dir"
    rm -rf build
    mkdir build
    cd build
    $CMAKE ..
    make -j"$JOBS"
    make install
    cd "$SRC"
}

# ----------------------------------------------------------------------
# Sources
# ----------------------------------------------------------------------

URLS="
https://archive.debian.org/debian/pool/main/e/expat/expat_2.1.0.orig.tar.gz
https://archive.debian.org/debian/pool/main/libp/libpng/libpng_1.2.50.orig.tar.xz
https://download.savannah.gnu.org/releases/freetype/freetype-2.10.4.tar.xz
https://ijg.org/files/jpegsrc.v9c.tar.gz
https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz
https://download.videolan.org/contrib/nasm/nasm-2.13.03.tar.gz
https://archive.ubuntu.com/ubuntu/pool/main/c/cmake/cmake_2.8.12.2.orig.tar.gz
https://download.videolan.org/pub/x264/snapshots/x264-snapshot-20180817-2245-stable.tar.bz2
https://get.videolan.org/x265/x265_2.8.tar.gz
https://archive.debian.org/debian/pool/non-free/f/fdk-aac/fdk-aac_0.1.4.orig.tar.gz
https://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz
https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.2.1.tar.gz
https://download.videolan.org/contrib/vpx/libvpx-1.4.0.tar.bz2
https://archive.debian.org/debian/pool/main/f/fribidi/fribidi_1.0.5.orig.tar.bz2
https://download.videolan.org/contrib/ass/libass-0.13.0.tar.gz
https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.3.tar.gz
https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.6.tar.gz
https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.bz2
https://archive.debian.org/debian/pool/main/libs/libsoxr/libsoxr_0.1.2.orig.tar.xz
https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.3.2.tar.xz
https://ftp.osuosl.org/pub/xiph/releases/speex/speex-1.2.0.tar.gz
https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/openjpeg2/2.1.2-1.1+deb9u2build0.1/openjpeg2_2.1.2.orig.tar.gz
https://archive.debian.org/debian/pool/main/o/opencore-amr/opencore-amr_0.1.3.orig.tar.gz
https://www.wavpack.com/wavpack-5.1.0.tar.bz2
https://archive.ubuntu.com/ubuntu/pool/universe/v/vo-aacenc/vo-aacenc_0.1.3.orig.tar.gz
https://downloads.sourceforge.net/libcddb/libcddb-1.3.2.tar.bz2
https://ftp.gnu.org/gnu/libcdio/libcdio-2.0.0.tar.bz2
https://ftp.gnu.org/gnu/libcdio/libcdio-paranoia-10.2+0.94+2.tar.gz
https://download.videolan.org/pub/videolan/libdvdcss/1.4.2/libdvdcss-1.4.2.tar.bz2
https://download.videolan.org/pub/videolan/libdvdread/6.0.0/libdvdread-6.0.0.tar.bz2
https://download.videolan.org/pub/videolan/libdvdnav/6.0.0/libdvdnav-6.0.0.tar.bz2
https://macports-distfiles.mirrorservice.org/luajit/LuaJIT-2.0.5.tar.gz
https://archive.debian.org/debian/pool/main/e/enca/enca_1.19.orig.tar.gz
https://archive.debian.org/debian/pool/main/libp/libpciaccess/libpciaccess_0.14.orig.tar.gz
https://dri.freedesktop.org/libdrm/libdrm-2.4.110.tar.xz
https://github.com/openssl/openssl/releases/download/OpenSSL_1_0_2d/openssl-1.0.2d.tar.gz
https://downloads.videolan.org/testing/contrib/dav1d/dav1d-0.7.1.tar.xz
https://ffmpeg.org/releases/ffmpeg-4.4.8.tar.xz
https://deb.debian.org/debian/pool/main/m/mpv/mpv_0.35.1.orig.tar.gz
"

for url in $URLS; do
    download "$url"
done

# ----------------------------------------------------------------------
# Build tools
# ----------------------------------------------------------------------

[ -x "$PKG/bin/yasm" ] ||
    build_auto yasm-1.3.0.tar.gz "$BUILD/yasm-1.3.0"

[ -x "$PKG/bin/nasm" ] ||
    build_auto nasm-2.13.03.tar.gz "$BUILD/nasm-2.13.03"

if [ ! -x "$PKG/bin/cmake" ]; then
    rm -rf "$BUILD/cmake-2.8.12.2"
    tar -xf "$SRC/cmake_2.8.12.2.orig.tar.gz" -C "$BUILD"
    cd "$BUILD/cmake-2.8.12.2"
    ./bootstrap --prefix="$PKG"
    make -j"$JOBS"
    make install
    cd "$SRC"
fi

# ----------------------------------------------------------------------
# Basic libraries
# ----------------------------------------------------------------------

[ -f "$PKG/lib/libexpat.a" ] ||
    build_auto expat_2.1.0.orig.tar.gz "$BUILD/expat-2.1.0"

[ -f "$PKG/lib/libjpeg.a" ] ||
    build_auto jpegsrc.v9c.tar.gz "$BUILD/jpeg-9c"

[ -f "$PKG/lib/libpng.a" ] ||
    build_auto libpng_1.2.50.orig.tar.xz "$BUILD/libpng-1.2.50"

[ -f "$PKG/lib/libfreetype.a" ] ||
    build_auto freetype-2.10.4.tar.xz "$BUILD/freetype-2.10.4"

# ----------------------------------------------------------------------
# Video / audio libraries
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libx264.a" ]; then
    echo "==> Building x264 with PIC"

    rm -rf "$BUILD/x264-snapshot-20180817-2245-stable"
    tar -xf "$SRC/x264-snapshot-20180817-2245-stable.tar.bz2" -C "$BUILD"

    cd "$BUILD/x264-snapshot-20180817-2245-stable"

    ./configure \
        --prefix="$PKG" \
        --disable-shared \
        --enable-static \
        --enable-pic

    make -j"$JOBS"
    make install

    cd "$SRC"
fi

if [ ! -f "$PKG/lib/libx265.a" ]; then
    rm -rf "$BUILD/x265_2.8"
    tar -xf "$SRC/x265_2.8.tar.gz" -C "$BUILD"
    cd "$BUILD/x265_2.8/source"
    rm -rf build
    mkdir build
    cd build
    $CMAKE .. -DENABLE_SHARED=OFF -DENABLE_CLI=OFF
    make -j"$JOBS"
    make install
    cd "$SRC"
fi

if [ ! -f "$PKG/lib/libfdk-aac.a" ]; then
    echo "==> Building fdk-aac 0.1.4"

    export CFLAGS="-O2 -fPIC"
    export CXXFLAGS="-O2 -fPIC -Wno-narrowing"

    build_auto \
        fdk-aac_0.1.4.orig.tar.gz \
        "$BUILD/fdk-aac-0.1.4"

    unset CFLAGS
    unset CXXFLAGS
fi

[ -f "$PKG/lib/libmp3lame.a" ] ||
    build_auto lame_3.100.orig.tar.gz "$BUILD/lame-3.100"

[ -f "$PKG/lib/libopus.a" ] ||
    build_auto opus-1.2.1.tar.gz "$BUILD/opus-1.2.1"

if [ ! -f "$PKG/lib/libvpx.a" ]; then
    rm -rf "$BUILD/libvpx-1.4.0"
    tar -xf "$SRC/libvpx-1.4.0.tar.bz2" -C "$BUILD"
    cd "$BUILD/libvpx-1.4.0"
    ./configure \
        --prefix="$PKG" \
        --disable-shared \
        --enable-static \
        --disable-unit-tests \
        --disable-examples
    make -j"$JOBS"
    make install
    cd "$SRC"
fi

[ -f "$PKG/lib/libvorbis.a" ] || {
    build_auto libogg-1.3.3.tar.gz "$BUILD/libogg-1.3.3"
    build_auto libvorbis-1.3.6.tar.gz "$BUILD/libvorbis-1.3.6"
}

[ -f "$PKG/lib/libtheora.a" ] ||
    build_auto libtheora-1.1.1.tar.bz2 "$BUILD/libtheora-1.1.1"

[ -f "$PKG/lib/libFLAC.a" ] ||
    build_auto flac-1.3.2.tar.xz "$BUILD/flac-1.3.2"

[ -f "$PKG/lib/libspeex.a" ] ||
    build_auto speex-1.2.0.tar.gz "$BUILD/speex-1.2.0"

[ -f "$PKG/lib/libwavpack.a" ] ||
    build_auto wavpack-5.1.0.tar.bz2 "$BUILD/wavpack-5.1.0"

[ -f "$PKG/lib/libvo-aacenc.a" ] ||
    build_auto vo-aacenc_0.1.3.orig.tar.gz "$BUILD/vo-aacenc-0.1.3"

[ -f "$PKG/lib/libopencore-amrnb.a" ] ||
    build_auto opencore-amr_0.1.3.orig.tar.gz "$BUILD/opencore-amr-0.1.3"

[ -f "$PKG/lib/libfribidi.a" ] ||
    build_auto fribidi_1.0.5.orig.tar.bz2 "$BUILD/fribidi-1.0.5"

[ -f "$PKG/lib/libsoxr.a" ] ||
    build_cmake libsoxr_0.1.2.orig.tar.xz "$BUILD/soxr-0.1.2-Source"

if [ ! -f "$PKG/lib/libass.a" ]; then
    echo "==> Building libass 0.13.0"

    rm -rf "$BUILD/libass-0.13.0"
    tar -xf "$SRC/libass-0.13.0.tar.gz" -C "$BUILD"

    cd "$BUILD/libass-0.13.0"

    if [ ! -f configure ]; then
        autoreconf -fiv
    fi

    CFLAGS="-O2 -fPIC" \
    CXXFLAGS="-O2 -fPIC" \
    ./configure \
        --prefix="$PKG" \
        --disable-shared \
        --enable-static

    make -j"$JOBS"
    make install

    cd "$SRC"
fi


# ----------------------------------------------------------------------
# OpenJPEG
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libopenjp2.a" ]; then
    rm -rf "$BUILD/openjpeg-2.1.2"
    tar -xf "$SRC/openjpeg2_2.1.2.orig.tar.gz" -C "$BUILD"
    cd "$BUILD/openjpeg-2.1.2"
    sed -i 's/VERSION 2.8.2/VERSION 2.8.0/g' CMakeLists.txt
    mkdir build
    cd build
    $CMAKE .. \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_CODEC=OFF \
        -DBUILD_TESTING=OFF
    make -j"$JOBS"
    make install
    cd "$SRC"
fi

# ----------------------------------------------------------------------
# CD/DVD
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libcdio.a" ]; then
    build_auto libcddb-1.3.2.tar.bz2 "$BUILD/libcddb-1.3.2"
    build_auto libcdio-2.0.0.tar.bz2 "$BUILD/libcdio-2.0.0"
    build_auto libcdio-paranoia-10.2+0.94+2.tar.gz \
        "$BUILD/libcdio-paranoia-10.2+0.94+2"
fi

if [ ! -f "$PKG/lib/libdvdnav.a" ]; then
    build_auto libdvdcss-1.4.2.tar.bz2 "$BUILD/libdvdcss-1.4.2"
    build_auto libdvdread-6.0.0.tar.bz2 "$BUILD/libdvdread-6.0.0"
    build_auto libdvdnav-6.0.0.tar.bz2 "$BUILD/libdvdnav-6.0.0"
fi

# ----------------------------------------------------------------------
# LuaJIT
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libluajit-5.1.a" ]; then
    rm -rf "$BUILD/LuaJIT-2.0.5"
    tar -xf "$SRC/LuaJIT-2.0.5.tar.gz" -C "$BUILD"
    cd "$BUILD/LuaJIT-2.0.5"
    make -j"$JOBS" PREFIX="$PKG"
    make install PREFIX="$PKG"
    cd "$SRC"
fi

# ----------------------------------------------------------------------
# libpciaccess 
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libpciaccess.a" ]; then
    echo "==> Building libpciaccess 0.14"

    rm -rf "$BUILD/libpciaccess-0.14"
    tar -xf "$SRC/libpciaccess_0.14.orig.tar.gz" -C "$BUILD"

    cd "$BUILD/libpciaccess-0.14"

    if [ ! -f configure ]; then
        autoreconf -fiv
    fi

    CFLAGS="-O2 -fPIC" \
    ./configure \
        --prefix="$PKG" \
        --disable-shared \
        --enable-static

    make -j"$JOBS"
    make install

    cd "$SRC"
fi

# ----------------------------------------------------------------------
# ENCA / libdrm
# ----------------------------------------------------------------------

[ -f "$PKG/lib/libenca.a" ] ||
    build_auto enca_1.19.orig.tar.gz "$BUILD/enca-1.19"

if [ ! -f "$PKG/lib/libdrm.a" ]; then
    echo "==> Building libdrm 2.4.110"

    rm -rf "$BUILD/libdrm-2.4.110"
    tar -xf "$SRC/libdrm-2.4.110.tar.xz" -C "$BUILD"

    cd "$BUILD/libdrm-2.4.110"

    rm -rf build

    meson setup build \
        --prefix="$PKG" \
        --libdir=lib \
        --default-library=static \
        -Dudev=false \
        -Dtests=false \
        -Dvalgrind=false \
        -Dcairo-tests=false

    meson compile -C build
    meson install -C build

    cd "$SRC"
fi

# ----------------------------------------------------------------------
# OpenSSL
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libssl.a" ]; then
    rm -rf "$BUILD/openssl-1.0.2d"
    tar -xf "$SRC/openssl-1.0.2d.tar.gz" -C "$BUILD"
    cd "$BUILD/openssl-1.0.2d"
    ./config \
        --prefix="$PKG" \
        no-shared \
        no-ssl3 \
        no-comp
    make -j"$JOBS"
    make install_sw
    cd "$SRC"
fi

# ----------------------------------------------------------------------
# dav1d - AV1 decoder
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libdav1d.a" ]; then
    echo "==> Building dav1d 0.7.1"

    rm -rf "$BUILD/dav1d-0.7.1"
    tar -xf "$SRC/dav1d-0.7.1.tar.xz" -C "$BUILD"

    cd "$BUILD/dav1d-0.7.1"

    meson setup build \
        --prefix="$PKG" \
        --libdir=lib \
        --default-library=static \
        -Denable_tools=false \
        -Denable_tests=false \
        -Denable_examples=false \
        -Denable_avx512=false

    meson compile -C build
    meson install -C build

    cd "$SRC"

    test -f "$PKG/lib/libdav1d.a"
fi


# ----------------------------------------------------------------------
# FFmpeg 4.4.8
# ----------------------------------------------------------------------

if [ ! -f "$PKG/lib/libavformat.a" ]; then
    echo "==> Building FFmpeg 4.4.8"

    rm -rf "$BUILD/ffmpeg-4.4.8"
    tar -xf "$SRC/ffmpeg-4.4.8.tar.xz" -C "$BUILD"

    cd "$BUILD/ffmpeg-4.4.8"

    ./configure \
        --prefix="$PKG" \
        --bindir="$PKG/bin" \
        --pkg-config-flags="--static" \
        --extra-cflags="-I$PKG/include" \
        --extra-ldflags="-L$PKG/lib" \
        --extra-libs="-lpthread -lm -ldl" \
        --disable-shared \
        --enable-static \
        --disable-doc \
        --disable-manpages \
        --disable-debug \
        --disable-ffprobe \
        --disable-ffplay \
        --disable-sdl2 \
        --disable-xlib \
        --disable-libxcb \
        --disable-libxcb-shm \
        --disable-libxcb-xfixes \
        --disable-libxcb-shape \
        --enable-gpl \
        --enable-version3 \
        --enable-nonfree \
        --enable-openssl \
        --enable-pthreads \
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
        --enable-encoders \
        --ignore-tests

    make -j"$JOBS"
    make install

    cd "$SRC"
fi

# ----------------------------------------------------------------------
# Remove shared libraries
# ----------------------------------------------------------------------

find "$PKG/lib" -type f \( -name '*.so' -o -name '*.so.*' \) -delete 2>/dev/null || true

# ----------------------------------------------------------------------
# mpv 0.35.1
# ----------------------------------------------------------------------

if [ ! -x "$PKG/bin/mpv" ]; then
    echo "==> Building mpv 0.35.1"

    rm -rf "$BUILD/mpv-0.35.1"
    tar -xf "$SRC/mpv_0.35.1.orig.tar.gz" -C "$BUILD"

    cd "$BUILD/mpv-0.35.1"

    if [ ! -f waf ]; then
        wget -q --show-progress \
            https://waf.io/waf-2.0.25 -O waf
        chmod 755 waf
    fi

    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    PATH="$PKG/bin:$PATH" \
    python3 ./waf configure \
        --prefix="$PKG" \
        --disable-manpage-build

    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    PATH="$PKG/bin:$PATH" \
    python3 ./waf build -j"$JOBS"

    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    PATH="$PKG/bin:$PATH" \
    python3 ./waf install

    cd "$SRC"
fi

test -x "$PKG/bin/mpv"

# ----------------------------------------------------------------------
# yt-dlp
# ----------------------------------------------------------------------

ROOTFS="$ROOT/squashfs-root"

if [ ! -f "$SRC/yt-dlp" ]; then
    echo "==> Downloading yt-dlp"
    wget -q --show-progress \
        https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux \
        -O "$SRC/yt-dlp"
    chmod 755 "$SRC/yt-dlp"
fi

# ----------------------------------------------------------------------
# AppImage-style squashfs bundle
# ----------------------------------------------------------------------

rm -rf "$ROOTFS"

mkdir -p \
    "$ROOTFS/usr/bin" \
    "$ROOTFS/usr/share/applications"

cp "$PKG/bin/mpv" "$ROOTFS/usr/bin/mpv"
cp "$PKG/bin/ffmpeg" "$ROOTFS/usr/bin/ffmpeg"
install -m755 "$SRC/yt-dlp" "$ROOTFS/usr/bin/yt-dlp"

strip "$ROOTFS/usr/bin/mpv" || true
strip "$ROOTFS/usr/bin/ffmpeg" || true

if [ -f "$PKG/share/applications/mpv.desktop" ]; then
    cp "$PKG/share/applications/mpv.desktop" \
       "$ROOTFS/usr/share/applications/mpv.desktop"

    echo "NoDisplay=true" \
        >> "$ROOTFS/usr/share/applications/mpv.desktop"
fi

# Useful sanity check: confirm dav1d is linked into FFmpeg/mpv.
echo
echo "=================================================="
echo " Build information"
echo "=================================================="

echo "mpv:"
"$ROOTFS/usr/bin/mpv" --version | head -n 5 || true

test -x "$PKG/bin/ffmpeg"

echo
echo "ffmpeg:"
"$ROOTFS/usr/bin/ffmpeg" -version | head -n 3 || true

echo
echo "Static libraries:"
ls -lh \
    "$PKG/lib/libdav1d.a" \
    "$PKG/lib/libavcodec.a" \
    "$PKG/lib/libavformat.a" \
    "$PKG/lib/libavutil.a"

echo
echo "=================================================="
echo " Creating mpv.sb"
echo "=================================================="

rm -f "$ROOT/mpv.sb"

mksquashfs "$ROOTFS" "$ROOT/mpv.sb" \
    -comp gzip \
    -noappend

echo
echo "=================================================="
echo " DONE"
echo "=================================================="

ls -lh "$ROOT/mpv.sb"
file "$ROOT/mpv.sb"
