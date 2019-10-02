
non-reentrant = (f) ->
  active = null
  ->>
    active || do
      active := f.apply @, &
        ..finally -> active := false


module.exports = non-reentrant