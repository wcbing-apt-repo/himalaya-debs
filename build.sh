#!/bin/sh
set -e

# Check and extract version number
[ $# != 1 ] && echo "Usage:  $0 <latest_releases_tag>" && exit 1
VERSION=$(echo "$1" | sed -n 's|[^0-9]*\([^_]*\).*|\1|p') && test "$VERSION"

PACKAGE=himalaya
REPO=pimalaya/himalaya

ARCH_LIST="amd64 arm64"
AMD64_FILENAME=himalaya.x86_64-linux.tgz
ARM64_FILENAME=himalaya.aarch64-linux.tgz

prepare() {
    mkdir -p output tmp
    curl -fs https://api.github.com/repos/$REPO/releases/latest | jq -r '.body' | gzip > tmp/changelog.gz
}

build() {
    BASE_DIR="$PACKAGE"_"$ARCH" && rm -rf "$BASE_DIR"
    install -D templates/copyright -t "$BASE_DIR/usr/share/doc/$PACKAGE"
    install -D tmp/changelog.gz -t "$BASE_DIR/usr/share/doc/$PACKAGE"

    # Download and move file
    curl -fsLo "tmp/$PACKAGE-$ARCH.tgz" "$(get_url_by_arch "$ARCH")"
    tar -xzf "tmp/$PACKAGE-$ARCH.tgz"
    install -D -m 755 -t "$BASE_DIR/usr/bin" himalaya && rm himalaya

    mkdir -p "$BASE_DIR"/usr/share/man && mv share/man "$BASE_DIR"/usr/share/man/man1
    install -D share/completions/himalaya.bash -t "$BASE_DIR"/usr/share/bash-completion/completions
    install -D share/completions/himalaya.fish -t "$BASE_DIR"/usr/share/fish/completions
    install -D share/completions/himalaya.elv -t "$BASE_DIR"/usr/share/elvish/lib/himalaya.elv
    rm -rf share

    # Package deb
    mkdir -p "$BASE_DIR/DEBIAN"
    SIZE=$(du -sk "$BASE_DIR"/usr | cut -f1)
    echo "Package: $PACKAGE
Version: $VERSION+1
Architecture: $ARCH
Installed-Size: $SIZE
Maintainer: wcbing <i@wcbing.top>
Section: mail
Priority: optional
Homepage: https://github.com/$REPO
Description: CLI to manage emails, based on email-lib
" > "$BASE_DIR/DEBIAN/control"

    dpkg-deb -b --root-owner-group -Z xz "$BASE_DIR" output
}

get_url_by_arch() {
    DOWNLOAD_PREFIX="https://github.com/$REPO/releases/latest/download"
    case $1 in
    "amd64") echo "$DOWNLOAD_PREFIX/$AMD64_FILENAME" ;;
    "arm64") echo "$DOWNLOAD_PREFIX/$ARM64_FILENAME" ;;
    esac
}

prepare

for ARCH in $ARCH_LIST; do
    echo "Building $ARCH package..."
    build
done

# Create repo files
cd output && apt-ftparchive packages . > Packages && apt-ftparchive release . > Release
