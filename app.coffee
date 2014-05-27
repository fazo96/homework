notes = new Meteor.Collection "notes"

# Server
if Meteor.isServer
  Accounts.config {
    sendVerificationEmail: false
    loginExpirationInDays: 1
  }

  Meteor.publish "my-notes", ->
    notes.find( { userId: @userId } ) unless not @userId

  # Authentication
  Accounts.validateNewUser (user) ->
    if user.email and Meteor.check(user.email,String) is yes and user.email.contains '@' is yes and user.email.endsWith '.' is no and user.email.endsWith '@' is no
      return yes
    else throw new Meteor.Error 403, "Invalid Email"
    if user.password and Meteor.check(user.password,String) is yes and user.password.length > 7
      return yes
    else throw new Meteor.Error 403, "Password invalid"

# Client
if Meteor.isClient
  Deps.autorun -> Meteor.subscribe "my-notes" unless not Meteor.userId()

  # User Interface
  Template.userInfo.events {
    'click #logout': (e,template) -> Meteor.logout()
    'keypress #newNote': (e,template) ->
      if e.keyCode is 13
        notes.insert {
          title: template.find('#newNote').value
          content: "..."
          userId: Meteor.userId()
        }
        template.find('#newNote').value = ""
  }
  Template.userInfo.in = -> Meteor.user().emails[0].address

  # Notes template
  Template.notes.truncateNoteDesc = (s) ->
    if s.length > 52 then s.slice(0,48)+"..." else s
  Template.notes.notes = ->
    d = notes.find().fetch();
    #d.splice d.indexOf(Session.get('note')), 1 ; d
  Template.notes.events {
    'click .close-note': -> notes.remove @_id
    'click .edit-note': -> Session.set 'note', this
  }

  # Note Editor
  Template.editor.note = -> Session.get 'note'
  saveCurrentNote = (t,e) ->
    if e and e.keyCode isnt 13 then return;
    notes.update Session.get('note')._id,
      $set:
        title: t.find('.title').value
        content: t.find('.area').value
  Template.editor.events
    'click .close-editor': -> Session.set 'note', undefined
    'click .save-editor': (e,t) -> saveCurrentNote t
    #'keypress .edit-note': (e,t) -> saveCurrentNote t, e # Doesnt work??
    'keypress .title': (e,t) -> saveCurrentNote t, e

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

  # Login and Register
  pressLogin = (template) ->
    mail = template.find('#mail').value; pass = template.find('#pass').value
    Meteor.loginWithPassword mail, pass, (err) ->
      errCallback err
  Template.auth.working = -> Meteor.loggingIn()
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
          }, (e) -> errCallback e
        catch err
          notify { msg: err }
  }
