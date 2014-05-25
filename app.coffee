todos = new Meteor.Collection "todos"

if Meteor.isServer
  #todos.insert { content: "Example" } unless todos.find().fetch().length > 0
  # Accounts
  ###
  Accounts.registerLoginHandler (req) ->
    return null unless req.mail and req.password
    return null unless req.mail.length > 4 and req.pass.length >= 8
    user = Meteor.users.findOne { mail: req.mail }
    if not user
      user = Meteor.insert { mail: req.mail, password: req.password }
    { id: user._id }
  ###

  Accounts.config {
    sendVerificationEmail: true
    loginExpirationInDays: 1
  }

  Meteor.publish "todos", ->
    todos.find( { userId: @userId } )

if Meteor.isClient
  Meteor.subscribe "todos"
  # Notes template
  Template.notes.notes = ->
    todos.find().fetch()
  Template.notes.events {
    'click .delete': ->
      todos.remove @_id
  }
  # Template for new notes
  Template.adder.events {
    'keypress #newNote': (e,template) ->
      if e.keyCode is 13
        console.log Meteor.userId()
        todos.insert {
          content: template.find('#newNote').value
          userId: Meteor.userId()
        }
        template.find('#newNote').value = ""
  }
  # Auth template
  Template.auth.events {
    'keypress .login': (e,template) ->
      if e.keyCode is 13
        # Login
        mail = template.find('#mail').value; pass = template.find('#pass').value
        Accounts.loginWithPassword mail, pass, (err) ->
          if err then console.log err else console.log "OK"
    'click #login': (e,template) ->
      mail = template.find('#mail').value; pass = template.find('#pass').value
      Meteor.loginWithPassword mail, pass, (err) ->
        if err then console.log err else console.log "OK"
    'click #register': (e,template) ->
      mail = template.find('#mail').value; pass = template.find('#pass').value
      Accounts.createUser { email: mail, password: pass }, (err) ->
        if err then console.log err else console.log "OK"
  }
  # User Logged In
  Template.userInfo.events {
    'click #logout': (e,template) ->
      Meteor.logout()
  }
