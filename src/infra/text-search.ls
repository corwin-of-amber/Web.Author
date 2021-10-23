
class Query
  (spec, flags = "") ->
    @re = if typeof spec == 'string' then @@_re-escape spec, "g#{flags}"
          else assert spec instanceof RegExp; spec
    @nullable = !!@re.exec('')
    if !@re.global
      @re = new RegExp(@re.source, @re.ignoreCase ? "gi" : "g");

  all: (s, start = 0) -> if @nullable then [] else [...s.matchAll(@re)]

  forward: (s, start = 0) -> if !@nullable
    @re.lastIndex = start
    @re.exec(s)

  @promote = (q, flags) -> if q instanceof @ then q else new @(q, flags)

  @_re-escape = (s, flags) ->
    new RegExp(s.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"), flags)


export Query