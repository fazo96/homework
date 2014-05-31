# Homework - Client Side

# Variables and utility stuff
notes = new Meteor.Collection "notes"
getUser = -> Meteor.user()
deleteAccount = ->
  Meteor.call 'deleteMe', (r) -> if r is yes then Router.go 'home'
amIValid = ->
  return no unless getUser()
  return yes for mail in getUser().emails when mail.verified is yes; no

# Common Helpers for the Templates
UI.registerHelper "loggingIn", -> Meteor.loggingIn()
UI.registerHelper "email", -> getUser().emails[0].address
UI.registerHelper "verified", -> amIValid()

# Router
###
Important: before rendering and routing, always "dispatch" the user to 'home'
if he doesn't have the permission to access the current route. 'home' then
dispatches the user to the correct landing page.
Routes are client side, but even if by hacking the client you can access pages
without being logged in, it's impossible to inteact with data because
the server checks all the things before providing the data. It's safe.
###
Router.configure
  layoutTemplate: 'layout'
  loadingTemplate: 'loading'
  notFoundTemplate: '404'
Router.map ->
  @route 'home',
    onBeforeAction: ->
      # Dispatch user to the right landing page based on his account status
      if getUser()
        if amIValid() is yes then Router.go 'notes' else Router.go 'verifyEmail'
      else Router.go 'login'
    path: '/'
  @route 'login',
    onBeforeAction: -> Router.go 'home' if getUser()
  @route 'register',
    onBeforeAction: -> Router.go 'home' if getUser()
  @route 'account',
    onBeforeAction: ->
      if not getUser() then Router.go 'home'
  @route 'notes',
    waitOn: -> Meteor.subscribe "my-notes"
    onBeforeAction: ->
      if not getUser() then Router.go 'home'
  @route 'note',
    path: '/note/:_id'
    waitOn: -> Meteor.subscribe "my-notes"
    data: -> notes.findOne _id: @params._id
    onBeforeAction: -> if not @data()? then Router.go 'home'
  @route 'verifyEmail',
    path: '/verify/:token?'
    template: 'verifyEmail'
    onBeforeAction: ->
      if @params.token?
        Accounts.verifyEmail @params.token, (err) ->
          if err then errCallback err else Router.go 'home'
  @route '404', path: '*'

# Client Templates

# Some utilities
logoutCallback = (err) -> if err then errCallback err else Router.go 'home'
errCallback = (err) ->
  if err.reason
    showError msg: err.reason
  else showErrror msg: err

# Menu
Template.menu.events
  'click .go-home': -> Router.go 'home'
  'click .go-account': -> Router.go 'account'
  'click .go-archive': -> Router.go 'archive'

# User Interface
Template.account.events
  'click #btn-logout': (e,template) -> Meteor.logout logoutCallback

# Notes template
Template.notelist.empty = -> notes.find().count() is 0
Template.notelist.notes = ->
  d = notes.find().fetch()
Template.notelist.events
  'click .close-note': -> notes.remove @_id
  'click .edit-note': -> Router.go 'note', {_id: @_id}
  'keypress #newNote': (e,template) ->
    if e.keyCode is 13 and template.find('#newNote').value isnt ""
      notes.insert
        title: template.find('#newNote').value
        content: ""
        userId: Meteor.userId()
      template.find('#newNote').value = ""

# Note Editor
Template.editor.note = -> Router.current.data() # Only when we're in /note/:_id
saveCurrentNote = (t,e) ->
  if e and e.keyCode isnt 13 then return
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
  'click #btn-delete': -> deleteAccount()
  'click #btn-logout': -> Meteor.logout logoutCallback

# Login
loginRequest = (e,template) ->
  if e and e.keyCode isnt 13 then return
  mail = template.find('#l-mail').value; pass = template.find('#l-pass').value
  Meteor.loginWithPassword mail, pass, (err) ->
    if err then errCallback err else Router.go 'home'

Template.login.events
  'keypress .login': (e,template) -> loginRequest e,template
  'click #login-btn': (e,template) -> loginRequest null,template

# Register
registerRequest = (e,template) ->
  if e and e.keyCode isnt 13 then return
  mail = template.find('#r-mail').value; pass = template.find('#r-pass').value
  pass2 = template.find('#r-pass-2').value
  if not mail
    showError msg: "Please enter an Email"
  else if not pass
    showError msg: "Please enter a password"
  else  if pass.length < 8
    showError msg: "Password too short"
  else if pass2 isnt pass
    showError msg: "The passwords don't match"
  else # Sending actual registration request
    try
      Accounts.createUser {
        email: mail,
        password: pass
      }, (err) -> if err then errCallback err else Router.go 'confirmEmail'
    catch err
      showError msg: err
Template.register.events
  'click #register-btn': (e,t) -> registerRequest null,t
  'keypress .register': (e,t) -> registerRequest e,t
