node_require = global.require ? (->)
  fs = .. 'fs'
  util = .. 'util'
  spawn = util.promisify(..('child_process').spawn)
  execFile = util.promisify(..('child_process').execFile)
  promisify-child-process = .. 'promisify-child-process'
require! {
    path,
    events: { EventEmitter }
    '../infra/fs-watch.ls': { FileWatcher }
    '../infra/non-reentrant.ls': non-reentrant
    '../infra/ongoing.ls': { global-tasks }
    './build': { CompiledAsset }
    './error-reporting': { BuildError }
}


job = (f) -> ->
  f.apply @, &
    @emit 'job:start' ..


class LatexmkBuild extends EventEmitter
  (@main-tex-file, @base-dir) ->
    super!
    @set-main @main-tex-file
    
    @out-dir = 'out'

    @latexmk = 'latexmk'
    @latexmk-flags = <[ -pdf -f ]>
    @pdflatex-flags = <[ -interaction=nonstopmode -synctex=1 -file-line-error ]>
    @envvars = {'TEXINPUTS': "#{@src-dir}/:./:",  \
                'BIBINPUTS': "#{path.join(@base-dir, @src-dir)}/:", \
                'max_print_line': '9999'}

    @on 'job:start' global-tasks~add

    @_watch = new FileWatcher
      ..on 'change' @~make-watch

  set-main: (@main-tex-file) ->
    @main-tex-fn = @main-tex-file.filename
    @base-dir ?= path.dirname(@main-tex-fn)
    if @main-tex-fn.startsWith('/')
      @main-tex-fn = path.relative(@base-dir, @main-tex-fn)
    @src-dir = path.dirname(@main-tex-fn)

  make: job non-reentrant ->>
    console.log "%cmake #{@base-dir} #{@main-tex-fn}", 'color: green'
    @emit 'started'
    await @_yield! # @hmm this is needed because child_process delays Vue updates somehow?
    try
      rc = await execFile @latexmk, @_args!, \
          shell: true, cwd: @base-dir, env: @_env!, encoding: 'utf-8'
      console.log 'build complete', rc
      @emit 'finished', {outcome: 'ok'}
    catch
      console.warn 'build failed', e
      if e.code?
        e = new BuildError('latexmk', e.code).withLog(@read-log!)
      @emit 'finished', {outcome: 'error', error: e}
    rc
  
  get-output: (ext) ->
    bn = path.basename(@main-tex-fn).replace(/[.]tex$/, '')
    path.join(@base-dir, @out-dir, bn + ext)

  read-log: ->
    try new CompiledAsset(fs.readFileSync(@get-output('.log')))
    catch

  clean: ->
    fs.unlinkSync @get-output('.fdb_latexmk')

  _args: -> @latexmk-flags ++ @pdflatex-flags ++ ["-outdir='#{@out-dir}'", @main-tex-fn]
  _env:  -> ^^global.process.env <<< @envvars

  _yield: -> new Promise -> setTimeout it, 1

  remake: ->> @clean! ; await @make!

  watch: ->>
    fns = @get-input-filenames!
    if !fns?
      await @make! ; fns = @get-input-filenames! ? []
    @_watch.multiple (``[...fns]``).map(~> path.join(@base-dir, it))

  unwatch: -> @_watch.clear!

  make-watch: ->> await @make! ; @watch!
  remake-watch: ->> await @remake! ; @watch!

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
      input = set-filter input, -> !it.endsWith('.bbl')  # @oops hack
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
      @flags.biblatex = !!log.match(/Package biblatex Info:/)
    | 'bibtex' =>
      @bib =
        used: egrep(/\nDatabase file #\d+: (.+)/g).map(-> it.1)
    console.log @bbl

  need-bibtex: ->
    if @flags.biblatex then return false  /** @todo need to implement a `need-biblatex` as well */
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