mkdir -p dist

# External packages
cp node_modules/jquery/dist/jquery.min.js dist/

mkdir -p dist/codemirror
cp node_modules/codemirror/lib/codemirror.* \
   node_modules/codemirror/mode/stex/stex.js dist/codemirror/

cp node_modules/split.js/dist/split.js dist/

cp node_modules/pdfjs-dist/build/*.min.js dist/

# Sources
cp src/browser.bundle.js `find src -name *.css` dist/
