{consume-next} = Traversal


commands =
  C: -> $ '<code>' .add-class 'code' .append consume-next it
  Sk: -> $ '<span>' .add-class 'Sketch'

  flagdoc: ->
    $ '<dl>' .add-class 'flagdoc'
      $ '<dt>' .add-class 'parameter' .append consume-next(it) .append-to ..
      $ '<dd>' .append consume-next(it) .append-to ..



@commands <<< commands
