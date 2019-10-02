node_require = global.require ? (->)
  child-process-promise = .. 'child-process-promise'
  fs = .. 'fs'
require! {
    path,
    events: {EventEmitter}
    '../infra/fs-watch.ls': {FileWatcher}
    '../infra/non-reentrant.ls': non-reentrant
}


job = (f) -> ->
  f.apply @, &
    @emit 'job:start' ..


class LatexmkBuild extends EventEmitter
  (@main-tex-fn, @base-dir) ->
    super!
    @base-dir ?= path.dirname(@main-tex-fn)
    if @main-tex-fn.startsWith('/')
      @main-tex-fn = path.relative(@base-dir, @main-tex-fn)
    
    @out-dir = 'out'

    @latexmk = 'latexmk'
    @latexmk-flags = <[ -pdf -f ]>
    @pdflatex-flags = <[ -interaction=nonstopmode -synctex=1 ]>
    @envvars = {'max_print_line': '9999'}

    @_watch = new FileWatcher
      ..on 'change' @~remake

  make: job non-reentrant ->>
    console.log "%cmake #{@base-dir} #{@main-tex-fn}", 'color: green'
    try
      rc = await \
        child-process-promise.spawn @latexmk, @_args!, \
          shell: true, cwd: @base-dir, env: @_env!, capture: <[ stdout stderr ]>
      console.log 'build complete', rc
    catch
      rc = {e.code, e.stdout, e.stderr}
      console.warn 'build failed', rc
    rc
  
  _args: -> @latexmk-flags ++ @pdflatex-flags ++ ["-outdir='#{@out-dir}'", @main-tex-fn]
  _env:  -> ^^global.process.env <<< @envvars

  remake: ->> await @make! ; @watch!

  watch: ->>
    fns = @get-input-filenames!
    if !fns?
      await @make! ; fns = @get-input-filenames! ? []
    @_watch.multiple (``[...fns]``).map(~> path.join(@base-dir, it))

  /**
   * Reads the names of the input files from the .fls file produced by latexmk
   */
  get-input-filenames: ->
    fls-fn = path.join(@base-dir, @out-dir, path.basename(@main-tex-fn).replace(/[.]tex/, '.fls'))
    if exists-file(fls-fn)
      input = new Set ; output = new Set
      for line in fs.readFileSync(fls-fn, 'utf-8').split(/[\n\r]+/)
        if (mo = /^INPUT ([^\/].*)/.exec(line))?  then input.add mo.1
        if (mo = /^OUTPUT ([^\/].*)/.exec(line))? then output.add mo.1
      input = set-filter input, -> !it.endsWith('.bbl')  # hack
      set-remove-all input, output



exists-file = (filename) ->
  try fs.statSync(filename).isFile!
  catch => false

set-filter = (s, p) ->
  ns = new Set
  ``for (let x of s) if (p(x)) ns.add(x)``
  ns

set-remove-all = (a, b) ->
  ``for (let x of b) a.delete(x)``
  a



export LatexmkBuild