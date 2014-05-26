notes = new Meteor.Collection "notes"

if Meteor.isServer
  Accounts.config {
    sendVerificationEmail: true
    loginExpirationInDays: 1
  }

  Meteor.publish "my-notes", ->
    notes.find( { userId: @userId } ) unless not @userId

if Meteor.isClient

  Meteor.subscribe "my-notes"

  # User Interface
  Template.userInfo.events {
    'click #logout': (e,template) ->
      Meteor.logout()
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
  Template.notes.notes = ->
    d = notes.find().fetch();
    #d.splice d.indexOf(Session.get('note')), 1 ; d
  Template.notes.events {
    'click .close-note': -> notes.remove @_id
    'click .edit-note': -> Session.set 'note', this
  }

  # Note Editor
  Template.editor.note = -> Session.get 'note'
  Template.editor.events
    'click .close-editor': -> Session.set 'note', undefined
    'click .save-editor': (e,t) ->
      notes.update Session.get('note')._id,
        $set:
          title: t.find('.title').value
          content: t.find('.area').value

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
      errCallback err; if Meteor.userId() then clearNotifications()
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
