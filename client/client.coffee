# Homework - Client Side
version = "1.1.3"
# Utilities
tick = new Deps.Dependency()
Meteor.setInterval (-> tick.changed();), 15000

notes = new Meteor.Collection "notes"
userSub = Meteor.subscribe 'user'
getUser = -> Meteor.user()
deleteAccount = ->
  Meteor.call 'deleteMe', (r) -> if r is yes then Router.go 'home'
amIValid = ->
  return no unless getUser()
  return yes for mail in getUser().emails when mail.verified is yes; no

# Common Helpers for the Templates
UI.registerHelper "version", -> version
UI.registerHelper "status", -> Meteor.status()
UI.registerHelper "loading", -> Meteor.loggingIn() or !Meteor.status().connected
UI.registerHelper "email", ->
  if getUser() then return getUser().emails[0].address
UI.registerHelper "verified", -> amIValid()

Meteor.startup ->
  console.log "Homework version "+version
  console.log "This software is Free Software (MIT License)"
  console.log "More information at http://github.com/fazo96/homework"

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
  action: ->
    if Meteor.status().connected is no
      @render 'reconnect'
    else if Meteor.loggingIn()
      @render 'loading'
    else @render()

loggedInController = RouteController.extend
  action: ->
    if Meteor.status().connected is no
      @render 'reconnect'
    else if !@ready() or Meteor.loggingIn()
      @render 'loading'
    else @render()
  onBeforeAction: ->
    if not getUser() then Router.go 'home'
    else if not amIValid() then Router.go 'verifyEmail'

guestController = RouteController.extend
  action: ->
    if Meteor.status().connected is no
      @render 'reconnect'
    else @render()
  onBeforeAction: ->
    if getUser()
      if amIValid() is no then Router.go 'verifyEmail' else Router.go 'notes'


Router.map ->
  @route 'home',
    path: '/'
    template: 'homepage'
    action: -> @render 'homepage', to: 'outside'
    onBeforeAction: ->
      # Dispatch user to the right landing page based on his account status
      if getUser()
        if amIValid() is yes then Router.go 'notes' else Router.go 'verifyEmail'
  @route 'login', controller: guestController
  @route 'register', controller: guestController
  @route 'account', controller: loggedInController
  @route 'notes',
    path: '/notes/:_id?'
    waitOn: -> Meteor.subscribe 'my-notes'
    data: -> notes.findOne _id: @params._id
    controller: loggedInController
  @route 'archive',
    path: '/archive/:_id?'
    waitOn: -> @notes = Meteor.subscribe 'archive'
    onStop: -> @notes.stop()
    controller: loggedInController
  @route 'verifyEmail',
    path: '/verify/:token?'
    template: 'verifyEmail'
    action: ->
      if Meteor.status().connected is no
        @render 'reconnect'
      else @render()
    onBeforeAction: ->
      if getUser()
        if amIValid() then Router.go 'home'
      else Router.go 'home'
      # Automatic verification
      if @params.token? and @params.token isnt ""
        @render 'loading'
        Accounts.verifyEmail @params.token, (err) ->
          if err
            errCallback err; Router.go 'verifyEmail', token: @params.token
          else
            showErr type:'success', msg:'Verification complete'
            Router.go 'home'
  @route '404', path: '*'

# Client Templates

# Some utility callbacks
logoutCallback = (err) ->
  if err then errCallback err
  else Router.go 'home'; Meteor.unsubscribe "my-notes"
errCallback = (err) ->
  if err.reason
    showError msg: err.reason
  else showErrror msg: err

Template.reconnect.time = ->
  tick.depend()
  if Meteor.status().retryTime
    '(retrying '+moment(Meteor.status().retryTime).fromNow()+')'

# 3 Buttons navigation Menu
Template.menu.events
  'click .go-home': -> Router.go 'home'
  'click .go-account': -> Router.go 'account'
  'click .go-archive': -> Router.go 'archive'

# Account Page
Template.account.dateformat = -> getUser().dateformat
Template.account.events
  'click #reset-settings': (e,t) ->
    t.find('#set-date-format').value = "MM/DD/YYYY"
  'click #save-settings': (e,t) ->
    Meteor.users.update getUser()._id,
      $set: dateformat: t.find('#set-date-format').value
    showError msg: 'Settings saved', type: 'success'
  'click #btn-logout': -> Meteor.logout logoutCallback
  'click #btn-delete-me': -> deleteAccount()

# Notes list
Template.notelist.active = ->
  return no unless Router.current() and Router.current().data()
  return @_id is Router.current().data()._id
Template.notelist.empty = -> Template.notelist.notelist().length is 0
Template.notelist.getDate = ->
  return unless @date
  tick.depend()
  #dif = moment(@date, getUser().dateformat).diff(moment(), 'days')
  dif = moment.unix(@date).diff(moment(), 'days')
  color = "primary"
  color = "info" if dif < 7
  color = "warning" if dif is 1
  color = "danger" if dif < 1
  msg: moment.unix(@date).fromNow(), color: color
Template.notelist.notelist = ->
  notes.find({ archived: no },{ sort: date: 1}).fetch()
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
Template.archivedlist.getDate = Template.notelist.getDate
Template.archivedlist.archived = ->
  notes.find({ archived: yes },{ sort: date: 1}).fetch()
Template.archivedlist.events =
  'click .close-note': -> notes.remove @_id
  'click .note': -> notes.update @_id, $set: archived: no
  'click .clear': ->
    notes.remove item._id for item in Template.archivedlist.archived()

# Note Editor
Template.editor.note = -> Router.current().data()
Template.editor.dateformat = -> getUser().dateformat
Template.editor.formattedDate = ->
  return unless @date
  moment.unix(@date).format(getUser().dateformat)
saveCurrentNote = (t,e) ->
  if e and e.keyCode isnt 13 then return
  dat = no
  if t.find('.date').value isnt ""
    dat = moment(t.find('.date').value,getUser().dateformat)
    if dat.isValid()
      dat = dat.unix()
    else
      dat = no; showError msg: 'Invalid date'
      t.find('.date').value = ""
  notes.update Router.current().data()._id,
    $set:
      title: t.find('.editor-title').value
      content: t.find('.area').value
      date: dat
Template.editor.events
  'click .close-editor': -> Router.go 'notes'
  'click .save-editor': (e,t) -> saveCurrentNote t
  'click .set-date': (e,t) ->
    t.find('.date').value = moment().add(1,'days').format(getUser().dateformat)
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
Template.verifyEmail.token = -> Router.current().params.token
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
