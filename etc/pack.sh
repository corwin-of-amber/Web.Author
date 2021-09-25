#!/bin/bash -e

# for pesky macOS tar
export COPYFILE_DISABLE=1

vendor() {
    set -x
    mkdir -p dist
    tar czhf dist/vendor.tar.gz --exclude tldist.tar bin/tex bin/xzminidec.wasm
}

examples() {
    set -x
    tar cf data/examples.tar --exclude '.*' --exclude out --strip-components=1 data/examples
    tar cf data/toxin-manual.tar --exclude '.*' --exclude out --strip-components=1 data/toxin-manual
}

case $1 in
examples) examples ;;
vendor) vendor ;;
esac