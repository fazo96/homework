# Homework - Client Side
notes = new Meteor.Collection "notes"
Deps.autorun -> Meteor.subscribe "my-notes" unless not Meteor.userId()
validateEmail = (email) ->
  expr = /^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/
  expr.test email
getUser = -> Meteor.user()
amIValid = ->
  return no unless getUser()
  return yes for mail in getUser().emails when mail.verified is yes; no
# Helpers
UI.registerHelper "loggingIn", -> Meteor.loggingIn()
UI.registerHelper "mail", -> getUser().emails[0].address
UI.registerHelper "verified", -> amIValid()

# User Interface
Template.userInfo.events
  'click #logout': (e,template) -> Meteor.logout()

# Notes template
Template.notes.truncateNoteDesc = (s) -> s
  #if s.length > 52 then s.slice(0,48)+"..." else s
Template.notes.notes = ->
  d = notes.find().fetch()
Template.notes.events
  'click .close-note': ->
    if Session.get('note') and Session.get('note')._id is @_id
      Session.set 'note', undefined
    notes.remove @_id
  'click .edit-note': -> Session.set 'note', this
  'keypress #newNote': (e,template) ->
    if e.keyCode is 13 and template.find('#newNote').value isnt ""
      notes.insert
        title: template.find('#newNote').value
        content: ""
        userId: Meteor.userId()
      template.find('#newNote').value = ""

# Note Editor
Template.editor.note = -> Session.get 'note'
saveCurrentNote = (t,e) ->
  if e and e.keyCode isnt 13 then return;
  notes.update Session.get('note')._id,
    $set:
      title: t.find('.editor-title').value
      content: t.find('.area').value
Template.editor.events
  'click .close-editor': -> Session.set 'note', undefined
  'click .save-editor': (e,t) -> saveCurrentNote t
  'keypress .title': (e,t) -> saveCurrentNote t, e

# Notifications
alerts = []
alertDep = new Deps.Dependency
errCallback = (err) ->
  if err.reason
    showError msg: err.reason
  else showErrror msg: err
# Show a notification
notify = (data) ->
  alerts.push
    title: data.title
    msg: data.msg
    type: data.type or "danger"
  alertDep.changed()
# Clear all notifications
clearNotifications = -> alerts.clear(); alertDep.changed()
# Get all the notifications
Template.notifications.notification = -> alertDep.depend(); alerts
Template.notifications.events
  'click .close-notification': (e,template) ->
    alerts.splice alerts.indexOf(this), 1
    alertDep.changed()

# "Error" visualization template
errorDep = new Deps.Dependency; shownError = undefined
showError = (err) ->
  shownError = err; shownError.type = err.type or "danger"
  errorDep.changed()
clearError = -> shownError = undefined; errorDep.changed()
Template.error.error = -> errorDep.depend(); shownError
Template.error.events 'click .close': -> clearError()

# "Loading" template
Template.loading.status = -> Meteor.status()

# Verify Email
Template.verifyEmail.events
  'click #btn-verify': (e,template) ->
    Accounts.verifyEmail template.find('#token-field').value, errCallback
  'click #btn-resend': ->
    Meteor.call 'resendConfirmEmail', errCallback
  'click #btn-delete': -> Meteor.call 'deleteMe'
  'click #btn-logout': -> Meteor.logout()

# Login and Register
pressLogin = (template) ->
  mail = template.find('#mail').value; pass = template.find('#pass').value
  Meteor.loginWithPassword mail, pass, errCallback

Template.auth.events
  # Login
  'keypress .login': (e,template) -> if e.keyCode is 13 then pressLogin template
  'click #login': (e,template) -> pressLogin template
  # Register
  'click #register': (e,template) ->
    mail = template.find('#mail').value; pass = template.find('#pass').value
    if not mail
      showError msg: "Please enter an Email"
    else if not pass
      showError msg: "Please enter a password"
    else  if pass.length < 8
      showError msg: "Password too short"
    else # Sending actual registration request
      try
        Accounts.createUser {
          email: mail,
          password: pass
        }, errCallback
      catch err
        showError msg: err
