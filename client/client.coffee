# Homework - Client Side
homework_version = "1.0"
# Utilities
notes = new Meteor.Collection "notes"
getUser = -> Meteor.user()
deleteAccount = ->
  Meteor.call 'deleteMe', (r) -> if r is yes then Router.go 'home'
amIValid = ->
  return no unless getUser()
  return yes for mail in getUser().emails when mail.verified is yes; no
daysUntil = (time) ->
  date = new Date time; now = new Date() #console.log date+" "+now
  now.setHours(0); now.setMinutes(0); now.setSeconds(0)
  (Math.floor ((date.getTime() - now.getTime()) / 1000 / 60 / 60) + 1) / 24

# Common Helpers for the Templates
UI.registerHelper "loggingIn", -> Meteor.loggingIn()
UI.registerHelper "email", ->
  if getUser() then return getUser().emails[0].address
UI.registerHelper "verified", -> amIValid()

# Router
###
Important: 'home' dispatches the user to the correct landing page.
Routes are client side, but even if by hacking the client you can access pages
without being logged in, it's impossible to inteact with data because
the server doesn't let the user if he doesn't have permission. It's still safe.
###
Router.configure
  layoutTemplate: 'layout'
  loadingTemplate: 'loading'
  notFoundTemplate: '404'
Router.map ->
  @route 'home',
    path: '/'
    template: 'homepage'
    action: -> @render 'homepage', to: 'outside'
    onBeforeAction: ->
      # Dispatch user to the right landing page based on his account status
      if getUser()
        if amIValid() is yes then Router.go 'notes' else Router.go 'verifyEmail'
  @route 'login',
    onBeforeAction: -> Router.go 'home' if getUser()
  @route 'register',
    onBeforeAction: -> Router.go 'home' if getUser()
  @route 'account',
    onBeforeAction: -> if not getUser() then Router.go 'home'
  @route 'notes',
    path: '/notes/:_id?'
    waitOn: -> Meteor.subscribe "my-notes"
    data: -> notes.findOne _id: @params._id
    onBeforeAction: -> if not getUser() then Router.go 'home'
  @route 'archive',
    path: '/archive/:_id?'
    waitOn: -> Meteor.subscribe "archive"
    onBeforeAction: -> if not getUser() then Router.go 'home'
  @route 'verifyEmail',
    path: '/verify/:token?'
    template: 'verifyEmail'
    onBeforeAction: ->
      if @params.token? and @params.token isnt ""
        Accounts.verifyEmail @params.token, (err) ->
          if err
            errCallback err; Router.go 'verifyEmail'
          else Router.go 'home'
  @route 'homepage', action: -> @render '404'
  @route '404', path: '*'

# You can't set a callback for when the user logs in using a cookie so...
# Cheap ass work around for routing the user after he logs in with a token
Deps.autorun ->
  t = Router.current(); return unless getUser() and t and t.lookupTemplate
  temp = t.lookupTemplate()
  if temp is 'login' or temp is 'homepage' or temp is 'try'
    Router.go 'home'

# Client Templates

# Some utility callbacks
logoutCallback = (err) ->
  if err then errCallback err
  else Router.go 'home'; Meteor.unsubscribe "my-notes"
errCallback = (err) ->
  if err.reason
    showError msg: err.reason
  else showErrror msg: err

# 3 Buttons navigation Menu
Template.menu.events
  'click .go-home': -> Router.go 'home'
  'click .go-account': -> Router.go 'account'
  'click .go-archive': -> Router.go 'archive'

# Account Page
Template.account.events
  'click #btn-logout': (e,template) -> Meteor.logout logoutCallback
  'click #btn-delete-me': -> deleteAccount()

# Notes list
Template.notelist.active = ->
  return no unless Router.current() and Router.current().data()
  return @_id is Router.current().data()._id
Template.notelist.empty = -> Template.notelist.notelist().length is 0
Template.notelist.getDate = ->
  return unless @date; diff = daysUntil @date
  if diff <= 0 then return msg:"You missed it!", color: "danger"
  if diff is 1 then return msg:"Today", color: "warning"
  if diff is 2 then return msg:"Tomorrow", color: "info"
  msg: "due in "+diff+" days", color: "primary"
Template.notelist.notelist = ->
  notes.find({ archived: no },{ sort: date: 1}).fetch()
###
  return [] unless getUser() and Router.current and Router.current().path
  path = Router.current().path
  if path.startsWith '/note'
    return notes.find({ archived: no },{ sort: date: 1}).fetch()
  else if path.startsWith '/archive'
    return notes.find({ archived: yes },{ sort: date: 1}).fetch()
  else return []
###
Template.notelist.events
  'click .close-note': -> notes.update @_id, $set: archived: yes
  'click .edit-note': -> Router.go 'notes'
  'keypress #newNote': (e,template) ->
    if e.keyCode is 13 and template.find('#newNote').value isnt ""
      notes.insert
        title: template.find('#newNote').value
        content: "", date: no, archived: no, userId: Meteor.userId()
      template.find('#newNote').value = ""

# Archive
Template.archivedlist.empty = -> Template.archivedlist.archived().length is 0
Template.archivedlist.archived = ->
  notes.find({ archived: yes },{ sort: date: 1}).fetch()
Template.archivedlist.events =
  'click .close-note': -> notes.remove @_id
  'click .note': -> notes.update @_id, $set: archived: no
  'click .clear': ->
    notes.remove item._id for item in Template.archivedlist.archived()

# Note Editor
Template.editor.note = -> Router.current().data()
Template.editor.rendered = -> $('.date').datepicker
  weekStart: 1
  startDate: "today"
  todayBtn: "linked"
saveCurrentNote = (t,e) ->
  if e and e.keyCode isnt 13 then return
  notes.update Router.current().data()._id,
    $set:
      title: t.find('.editor-title').value
      content: t.find('.area').value
      date: t.find('.date').value
Template.editor.events
  'click .close-editor': -> Router.go 'notes'
  'click .save-editor': (e,t) -> saveCurrentNote t
  'keypress .title': (e,t) -> saveCurrentNote t, e

# Notifications (not used yet)
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

# Verify Email page
Template.verifyEmail.events
  'click #btn-verify': (e,template) ->
    t = template.find('#token-field').value; t = t.split("/")
    t = t[t.length-1] # Remove all the part before the last "/"
    console.log "Email ver. using token: "+template.find('#token-field').value
    Accounts.verifyEmail t, (err) ->
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
    if err then errCallback err else Router.go 'notes'

Template.login.events
  'keypress .login': (e,template) -> loginRequest e,template
  'click #login-btn': (e,template) -> loginRequest null,template

# New Account page
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
