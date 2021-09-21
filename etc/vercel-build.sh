#!/bin/bash -e

BASE_TAG='<base href="build\/kremlin\/index.html">'

TLNET=https://ctan.math.illinois.edu/systems/texlive/tlnet
DL=bin/tlnet
DLCACHE=node_modules/vendor-cache

sed "s/<!-- base .* -->/$BASE_TAG/" build/kremlin/index.html > index.html

[ -e dist/vendor.tar.gz ] && tar xzvf dist/vendor.tar.gz

mkdir -p $DL

# Check for downloaded packages in build cache
if [ -d $DLCACHE/ ] ; then
    echo Vendor cache found:
    du -hs $DLCACHE
    cp -r $DLCACHE/* $DL/
else
    echo Vendor cache not found.
fi

# Download packages from tlnet
for pkg in `cat etc/tlnet-deploy.list`; do
    echo "$TLNET/archive/$pkg.tar.xz"
    [ -e "$DL/$pkg.tar.xz" ] || curl "$TLNET/archive/$pkg.tar.xz" > "$DL/$pkg.tar.xz"
done

# Update build cache
mkdir -p $DLCACHE
cp -r $DL/* $DLCACHE/

# These packages are too large to be unpacked on the client :/
for pkg in amsfonts lm; do
    ./dist/xzminidec < "$DL/$pkg.tar.xz" > "$DL/$pkg.tar"
done