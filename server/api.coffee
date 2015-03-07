notes = share.notes = new Mongo.Collection 'notes'

if !Meteor.settings.enableAPI? then return

console.log 'RESTful HTTP API enabled'

apiKeyToUser = (key) -> Meteor.users.findOne apiKey: key
respond = (res, code, obj) ->
  res.writeHead code, 'Content-Type': 'application/json'
  res.end JSON.stringify obj

# GET NOTES
Router.route '/api/:key', where: 'server'
  .get ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      respond @response, 200, notes.find(
        { userId: user._id, archived: no },
        { fields: { archived: 0, userId: 0 }, sort: { date: 1 }}).fetch()

# GET ARCHIVE
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

# INSERT NOTE
Router.route '/api/:key/:title/:desc', where: 'server'
  .post ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      notes.insert {
        userId: user._id
        title: @params.title
        content: @params.desc
        date: no
        archived: no
      }, (e) => respond @response, (if e then 500 else 200), e or {}

# DELETE NOTE
Router.route '/api/:id', where: 'server'
  .delete ->
    user = apiKeyToUser @params.key
    if !user
      respond @response, 400, error: 'invalid api key'
    else
      notes.remove @params.id, (e) => respond @response, (if e then 500 else 200), e or {}
