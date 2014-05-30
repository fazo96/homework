# Homework - Client Side
notes = new Meteor.Collection "notes"
Deps.autorun -> Meteor.subscribe "my-notes" unless not Meteor.userId()

getUser = -> Meteor.user()
amIValid = ->
  return no unless getUser()
  return yes for mail in getUser().emails when mail.verified is yes; no
logoutCallback = (err) -> if err then errCallback err else Router.go 'home'
loginCallback = (err) -> if err then errCallback err else Router.go 'notes'

# Common Helpers
UI.registerHelper "loggingIn", -> Meteor.loggingIn()
UI.registerHelper "email", -> getUser().emails[0].address
UI.registerHelper "verified", -> amIValid()

# Router
Router.configure
  layoutTemplate: 'layout'
  loadingTemplate: 'loading'
Router.map ->
  @route 'home',
    onBeforeAction: -> if getUser() then Router.go 'notes'
    path: '/'
    template: 'auth'
  @route 'notes',
    onBeforeAction: ->
      if not getUser() then Router.go 'home'
      if amIValid() is no then Router.go 'verifyEmail'
  @route 'note',
    path: '/note/:_id'
    data: -> notes.findOne _id: @params._id
    onBeforeAction: ->
      if not getUser() then Router.go 'home'
      if amIValid() is no then Router.go 'verifyEmail'
      if not @data() then Router.go 'notes'
  @route 'verifyEmail',
    template: 'verifyEmail'
    onBeforeAction: ->
      if not getUser() then Router.go 'home'
      if amIValid() is yes then Router.go 'notes'

# Client Templates

# User Interface
Template.account.events
  'click #logout': (e,template) -> Meteor.logout logoutCallback

# Notes template
Template.notelist.empty = -> notes.find().count() is 0
Template.notelist.notes = ->
  d = notes.find().fetch()
Template.notelist.events
  'click .close-note': ->
    notes.remove @_id
  'click .edit-note': ->
    Router.go 'note', {_id: @_id}
  'keypress #newNote': (e,template) ->
    if e.keyCode is 13 and template.find('#newNote').value isnt ""
      notes.insert
        title: template.find('#newNote').value
        content: ""
        userId: Meteor.userId()
      template.find('#newNote').value = ""

# Note Editor
Template.editor.note = -> Router.current.data()
saveCurrentNote = (t,e) ->
  if e and e.keyCode isnt 13 then return;
  notes.update Router.current().data()._id,
    $set:
      title: t.find('.editor-title').value
      content: t.find('.area').value
Template.editor.events
  'click .close-editor': -> Router.go 'notes'
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

# Verify Email
Template.verifyEmail.events
  'click #btn-verify': (e,template) ->
    Accounts.verifyEmail template.find('#token-field').value, (err) ->
      if err then errCallback err else Router.go 'notes'
  'click #btn-resend': ->
    Meteor.call 'resendConfirmEmail', (err) ->
      if err
        errCallback err
      else showError { type:"success", msg: "Confirmation email sent" }
  'click #btn-delete': ->
    Meteor.call 'deleteMe', (r) -> if r is yes then Router.go 'home'
  'click #btn-logout': -> Meteor.logout logoutCallback

# Login and Register
pressLogin = (template) ->
  mail = template.find('#mail').value; pass = template.find('#pass').value
  Meteor.loginWithPassword mail, pass, loginCallback

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
        }, (err) -> if err then errCallback err else Router.go 'confirmEmail'
      catch err
        showError msg: err
