
assert = (cond, msg) ->
  if !cond
    throw Error (if msg? then "Assertion failed; #msg" else "Assertion failed.")


export assert
