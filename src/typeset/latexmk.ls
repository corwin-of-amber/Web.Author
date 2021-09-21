node_require = global.require ? (->)
  fs = .. 'fs'
  util = .. 'util'
  child-process-promise = .. 'child-process-promise'
require! {
    path,
    events: {EventEmitter}
    '../infra/fs-watch.ls': {FileWatcher}
    '../infra/non-reentrant.ls': non-reentrant
    '../infra/ongoing.ls': {global-tasks}
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
    @src-dir = path.dirname(@main-tex-fn)

    @latexmk = 'latexmk'
    @latexmk-flags = <[ -pdf -f ]>
    @pdflatex-flags = <[ -interaction=nonstopmode -synctex=1 ]>
    @envvars = {'TEXINPUTS': "#{@src-dir}/:./:",  \
                'BIBINPUTS': "#{path.join(@base-dir, @src-dir)}/:", \
                'max_print_line': '9999'}

    @on 'job:start' global-tasks~add

    @_watch = new FileWatcher
      ..on 'change' @~make-watch

  make: job non-reentrant ->>
    console.log "%cmake #{@base-dir} #{@main-tex-fn}", 'color: green'
    @emit 'started'
    await @_yield! # this is needed because child_process locks Vue updates somehow?
    try
      rc = await \
        child-process-promise.spawn @latexmk, @_args!, \
          shell: true, cwd: @base-dir, env: @_env!, stdio: 'ignore' #, capture: <[ stderr ]>
      console.log 'build complete', rc
      @emit 'finished', {outcome: 'ok'}
    catch
      if !e.code? then throw e
      console.warn 'build failed', e
      @emit 'finished', {outcome: 'error', error: e}
    rc
  
  clean: ->
    bn = path.basename(@main-tex-fn)
    fs.unlinkSync path.join(@base-dir, @out-dir, bn.replace(/[.]tex$/, '') + '.fdb_latexmk')

  _args: -> @latexmk-flags ++ @pdflatex-flags ++ ["-outdir='#{@out-dir}'", @main-tex-fn]
  _env:  -> ^^global.process.env <<< @envvars

  _yield: -> new Promise -> setTimeout it, 1

  remake: ->> @clean! ; await @make!

  watch: ->>
    fns = @get-input-filenames!
    if !fns?
      await @make! ; fns = @get-input-filenames! ? []
    @_watch.multiple (``[...fns]``).map(~> path.join(@base-dir, it))

  make-watch: ->> await @make! ; @watch!

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


/**
 * A small utility class that mimics the most basic functionality of `latexmk`,
 * specifically detecting if `bibtex` should be run or `pdflatex` should be
 * re-run.
 */
class LatexmkClone
  ->
    @bbl = {missing: [], used: []}
    @bib = {used: []}
    @flags = {crossrefs: false}
    @timestamps = {source: {}, build: {}}

  process-log: (prog, log) ->
    if log.volume? then log = log.volume.readFileSync log.filename, 'utf-8'
    if log instanceof Uint8Array then log = new TextDecoder().decode(log)

    egrep = -> [...log.matchAll(it)]

    switch prog
    | 'pdflatex' =>
      @bbl =
        missing: egrep(/\nNo file (.+\.bbl)\.\n/g).map(-> it.1)
        used: egrep(/\(([^()]+\.bbl)\)/g).map(-> it.1)
      @flags.crossrefs = !!log.match(/Rerun to get cross-references right\./)
    | 'bibtex' =>
      @bib =
        used: egrep(/\nDatabase file #\d+: (.+)/g).map(-> it.1)
    console.log @bbl

  need-bibtex: ->
    # not 100% certain about this. what if the list of `.bib` files has changed?
    if @bbl.missing.length then true
    else if @bbl.used.length && !@bib.used.length then true
    else
      bib-latest-ms = Math.max(0,
        ...@bib.used.map(~> @timestamps.source[it]?mtimeMs ? 0))
      for u in @bbl.used
        mtime-ms = @timestamps.build[u]?mtimeMs ? 0
        if bib-latest-ms > mtime-ms then return true
      
      false

  need-latex: ->
    return @flags.crossrefs


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



export LatexmkBuild, LatexmkClone