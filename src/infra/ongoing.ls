
class OngoingTasks
  -> @promises = []

  add: (promise) ->
    @promises.push promise
    promise.finally ~> @remove promise

  remove: (promise) ->
    @promises.indexOf promise
      if .. >= 0 then @promises.splice .., 1
  
  wait: -> Promise.all(@promises)


global-tasks = new OngoingTasks
window <<< {global-tasks}

export OngoingTasks, global-tasks