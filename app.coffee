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
  Template.notes.notes = -> notes.find().fetch()
  Template.notes.events {
    'click .close-note': -> notes.remove @_id
    'click .edit': -> Session.set 'note', this
  }

  # Note Editor
  Template.editor.show = -> Session.get 'note'
  Template.editor.events {
    'click .close': -> Session.set 'note', undefined
    'click .save': -> null
  }

  # Notifications
  alerts = []
  alertDep = new Deps.Dependency
  errCallback = (err) -> notify { msg: err.reason }
  # Show a notification
  notify = (data) ->
    alerts.push {
      title: data.title
      msg: data.msg
      id: data.id or alerts.length
      type: data.type or "danger"
    }; alertDep.changed()
  # Clear all notifications
  clearNotifications = -> alerts.clear(); alertDep.changed()
  # Get all the notifications
  Template.notifications.notification = -> alertDep.depend(); alerts
  Template.notifications.events {
    'click .close-notification': (e,template) ->
      alerts.splice alerts.indexOf(this), 1
      alertDep.changed()
  }
  pressLogin = (template) ->
    mail = template.find('#mail').value; pass = template.find('#pass').value
    Meteor.loginWithPassword mail, pass, (err) ->
      errCallback err; if Meteor.userId() then clearNotifications()
  # Login and Register
  Template.auth.events {
    'keypress .login': (e,template) ->
      if e.keyCode is 13 then pressLogin template
    # Login
    'click #login': (e,template) -> pressLogin template
    # Register
    'click #register': (e,template) ->
      mail = template.find('#mail').value; pass = template.find('#pass').value
      if not mail or mail.contains '@' is no or mail.endsWith '.' is yes or mail.endsWith '@' is yes
        notify { msg: "Invalid Email" }
      else
        try
          Accounts.createUser {
            email: mail,
            password: pass
          }, (e) -> errCallback e; if Meteor.userId() then clearNotifications()
        catch err
          notify { msg: err }
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
