require! {
  fs, path,
  minimatch
}


class MultiMatch
  (@regexes) ->
  exec: (s) -> @regexes.some((.exec(s)))

  @from-patterns = (globs-and-regexes) ->
    promote = (pat) ->
      if typeof pat == 'string' then minimatch.makeRe(pat) else pat
    new MultiMatch([promote(..) for globs-and-regexes])

  @promote = (mm-or-patterns) ->
    if mm-or-patterns instanceof MultiMatch then mm-or-patterns
    else MultiMatch.from-patterns(mm-or-patterns)

MultiMatch.NONE = new MultiMatch([])


dir-tree-core = (fs, path, dir, prune, relpath=[]) ->
  fs.readdirSync(dir).filter(-> !prune.exec(it)).map (file) ->
    {name: file, path: path.join(dir, file), relpath: [...relpath, file]}
      if fs.statSync(..path).isDirectory!
        ..files = dir-tree-core(fs, path, ..path, prune, ..relpath)

dir-tree-sync = (dir, opts) ->
  opts = {exclude: [], fs, ...opts}
  if !opts.path then opts.path = opts.fs.path ? path

  prune = MultiMatch.promote(opts.exclude)
  dir-tree-core(opts.fs, opts.path, dir, prune)

traverse-core = (fs, path, dir, prune=MultiMatch.NONE) !->*
  for file in fs.readdirSync(dir).filter(-> !prune.exec(it))
    subpath = path.join(dir, file)
    substat = fs.statSync(subpath)
    yield {path: subpath, stat: substat}
    if substat.isDirectory!
      yield from traverse-core(fs, path, subpath, prune)

glob-all = (patterns, opts={}) !->*
  opts = {exclude: [], cwd: '', fs, ...opts}
  if !opts.path then opts.path = opts.fs.path ? path

  mm = MultiMatch.promote(patterns)
  prune = MultiMatch.promote(opts.exclude)
  check-type = switch opts.type
    | undefined, '*' => (-> true)
    | 'file' => (-> !it.stat.isDirectory!)
    | 'dir' => (-> it.stat.isDirectory!)
  ii = traverse-core(opts.fs, opts.path, opts.cwd, prune)
  while !(cur = ii.next!).done
    entry = cur.value
    if check-type(entry) && mm.exec(entry.path) then yield entry.path


export dir-tree-sync, glob-all, MultiMatch