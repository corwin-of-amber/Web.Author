#!/bin/bash -e

BASE_TAG='<base href="build\/kremlin\/index.html">'

[ -e dist/vendor.tar.gz ] && tar xzvf dist/vendor.tar.gz
sed "s/<!-- base -->/$BASE_TAG/" build/kremlin/index.html > index.html