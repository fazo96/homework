notes = new Meteor.Collection "notes"

if Meteor.isServer
  #notes.insert { content: "Example" } unless notes.find().fetch().length > 0
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

  Meteor.publish "my-notes", ->
    notes.find( { userId: @userId } ) unless not @userId

if Meteor.isClient
  Meteor.subscribe "my-notes"
  # Notes template
  Template.notes.notes = ->
    notes.find().fetch()
  Template.notes.events {
    'click .delete': ->
      notes.remove @_id
  }

  # Auth
  Template.auth.alerts = []
  Template.auth.errCallback = (err) ->
    Template.auth.alert { msg: err.reason }

  Template.auth.alert = (add,remove) ->
    if add then Template.auth.alerts.push add;
    if remove
      Template.auth.alerts.splice Template.auth.alerts.indexOf(remove), 1
    Template.auth.alerts

  Template.auth.events {
    'click .delete': (e,template) -> Template.auth.alert null, this
    'keypress .login': (e,template) ->
      mail = template.find('#mail').value; pass = template.find('#pass').value
      if e.keyCode is 13 # Login
        Meteor.loginWithPassword mail, pass, Template.auth.errCallback
    # Login
    'click #login': (e,template) ->
      mail = template.find('#mail').value; pass = template.find('#pass').value
      Meteor.loginWithPassword mail, pass, Template.auth.errCallback
    # Register
    'click #register': (e,template) ->
      mail = template.find('#mail').value; pass = template.find('#pass').value
      Accounts.createUser { email: mail, password: pass }, Template.auth.errCallback
  }
  # User Logged In
  Template.userInfo.events {
    'click #logout': (e,template) ->
      Meteor.logout()
    'keypress #newNote': (e,template) ->
      if e.keyCode is 13
        notes.insert {
          content: template.find('#newNote').value
          userId: Meteor.userId()
        }
        template.find('#newNote').value = ""
  }
  Template.userInfo.in = -> Meteor.user().emails[0].address
