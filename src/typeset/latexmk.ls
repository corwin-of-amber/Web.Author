node_require = global.require ? ->
child-process-promise = node_require 'child-process-promise'
require! {
  path
}


class LatexmkBuild
  (@main-tex-fn, @base-dir) ->
    @base-dir ?= path.dirname(@main-tex-fn)
    if @main-tex-fn.startsWith('/')
      @main-tex-fn = path.relative(@base-dir, @main-tex-fn)
    
    @latexmk = 'latexmk'
    @latexmk-flags = <[ -pdf -outdir=out ]>
    @pdflatex-flags = <[ -interaction=nonstopmode -synctex=1 ]>

  make: ->
    child-process-promise.spawn @latexmk, \
      [...@latexmk-flags, ...@pdflatex-flags, @main-tex-fn], \
      shell: true, cwd: @base-dir, capture: <[ stdout stderr ]>



export LatexmkBuild