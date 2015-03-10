notes = share.notes = new Mongo.Collection 'notes'

if !Meteor.settings.public?.enableAPI? then return

console.log 'RESTful HTTP API enabled'

apiKeyToUser = (key) ->
  if key? and key != "" then Meteor.users.findOne apiKey: key
respond = (res, code, obj) ->
  res.writeHead code, 'Content-Type': 'application/json'
  res.end JSON.stringify obj

Router.route '/api/:key', where: 'server'
  # GET NOTES
  .get ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      respond @response, 200, notes.find(
        { userId: user._id, archived: no },
        { fields: { archived: 0, userId: 0 }, sort: { date: 1 }}).fetch()
  # POST - inserts new note
  .post ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      if @request.body.date? and @request.body.date isnt false
        @request.body.date = moment(@request.body.date, @request.body.dateformat || user.dateformat).unix()
      else @request.body.date = no
      toInsert =
        userId: user._id
        title: @request.body.title
        date: @request.body.date
        content: @request.body.content || ""
        archived: @request.body.archived || no
      if @request.body.title? then notes.insert toInsert, (e,i) =>
        respond @response, (if e then 500 else 200), if e then { error: e } else { inserted: i }
      else respond @response, 400, { error: '"title" field required to insert note into database' }

# GET archive
Router.route '/api/:key/archived', where: 'server'
  .get ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      respond @response, 200, notes.find(
        { userId: user._id, archived: yes },
        { fields: { archived: 0, userId: 0 }, sort: { date: 1 }}).fetch()

# BACKUP
Router.route '/api/:key/backup', where: 'server'
  .get ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      respond @response, 200, notes.find(userId: user._id).fetch()

# RESTORE to be implemented

Router.route '/api/:key/:id', where: 'server'
  # DELETE NOTE
  .delete ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      notes.remove @params.id, (e,d) =>
        if e then respond @response, 400, { error: e }
        else respond @response, 200, { deleted: d }
