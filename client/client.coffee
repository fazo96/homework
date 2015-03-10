# Homework - Client Side
version = "1.3"
# Utilities
tick = new Tracker.Dependency()
Meteor.setInterval (-> tick.changed();), 15000

notes = new Meteor.Collection 'notes'
userSub = Meteor.subscribe 'user'
getUser = -> Meteor.user()
deleteAccount = ->
  swal {
    title: 'Are you sure?'
    text: 'Do you want to permanently delete all your data?'
    type: 'warning'
    showCancelButton: yes
    confirmButtonColor: "#DD6B55"
    confirmButtonText: "Yes!"
    }, -> Meteor.call 'deleteMe', (r) -> if r is yes then Router.go 'home'
amIValid = ->
  return no unless getUser()
  return yes if getUser().username
  return yes for mail in getUser().emails when mail.verified is yes; no

# Common Helpers for the Templates
UI.registerHelper "version", -> version
UI.registerHelper "status", -> Meteor.status()
UI.registerHelper "loading", -> Meteor.loggingIn() or !Meteor.status().connected
UI.registerHelper "APIAvailable", -> Meteor.settings.public?.enableAPI?
UI.registerHelper "facebookAvailable", ->
  Accounts.loginServicesConfigured() and ServiceConfiguration.configurations.find(service: "facebook").count() > 0
UI.registerHelper "twitterAvailable", ->
  Accounts.loginServicesConfigured() and ServiceConfiguration.configurations.find(service: "twitter").count() > 0
UI.registerHelper "email", ->
  if getUser()
    if getUser().username then return getUser().username
    else return getUser().emails[0].address
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
    if not getUser() then @redirect 'home'
    else if not amIValid() then @redirect 'verifyEmail'
    @next()

guestController = RouteController.extend
  action: ->
    if Meteor.status().connected is no
      @render 'reconnect'
    else @render()
  onBeforeAction: ->
    if getUser()
      if amIValid() is no then @redirect 'verifyEmail' else @redirect 'notes'
    @next()

# Page Routing
Router.route '/',
  name: 'home'
  template: 'homepage'
  action: ->
    @render 'homepage', to: 'outside'
    # Iron Router Workaround for a bug where content from previous renderings carries over if not overwritten
    @render 'nothing'
  onBeforeAction: ->
    # Dispatch user to the right landing page based on his account status
    if getUser()
      if amIValid() is yes then @redirect 'notes' else @redirect 'verifyEmail'
    @next()
Router.route '/login', controller: guestController
Router.route '/register', controller: guestController
Router.route '/account', controller: loggedInController
Router.route '/notes/:_id?',
  name: 'notes'
  waitOn: -> Meteor.subscribe 'notes', no
  data: -> notes.findOne _id: @params._id
  controller: loggedInController
Router.route '/verify/:token?',
  name: 'verifyEmail'
  template: 'verifyEmail'
  action: ->
    if Meteor.status().connected is no
      @render 'reconnect'
    else @render(); @render 'nothing', to: 'outside'
  onBeforeAction: ->
    if getUser()
      if amIValid()
        @redirect 'home'
        @next()
      else if @params.token? and @params.token isnt ""
        # Automatic verification
        @render 'loading'
        Accounts.verifyEmail @params.token, (err) =>
          if err
            errCallback err; Router.go 'verifyEmail', token: @params.token
          else
            showErr type:'success', msg:'Verification complete'
            Router.go 'home'
          @next()
      @next()
    else
      @redirect 'home'
      @next()
Router.route '/archive/:_id?',
  name: 'archive'
  waitOn: -> @notes = Meteor.subscribe 'notes', yes
  onStop: -> @notes.stop()
  controller: loggedInController

# Client Templates

# Some utility callbacks
logoutCallback = (err) ->
  if err then errCallback err else Router.go 'home'
errCallback = (err) ->
  if err.reason
    showError msg: err.reason
  else showError msg: err

loginCallback = (e) ->
  if e? then errCallback e
  else
    Router.go 'notes'
    swal 'Ok', 'Logged In', 'success'

Template.homepage.events
  'click #facebook': -> Meteor.loginWithFacebook loginCallback
  'click #twitter': -> Meteor.loginWithTwitter loginCallback

Template.reconnect.helpers
  time : ->
    tick.depend()
    if Meteor.status().retryTime
      '(retrying '+moment(Meteor.status().retryTime).fromNow()+')'

# 3 Buttons navigation Menu
Template.menu.events
  'click .go-home': -> Router.go 'home'
  'click .go-account': -> Router.go 'account'
  'click .go-archive': -> Router.go 'archive'

# Account Page
Template.account.helpers
  dateformat: -> if getUser() then return getUser().dateformat
  apikey: -> if getUser() then return getUser().apiKey
Template.account.events
  'click #reset-settings': (e,t) ->
    t.find('#set-date-format').value = "MM/DD/YYYY"
    t.find('#set-api-key').value = ''
  'click #save-settings': (e,t) ->
    Meteor.users.update getUser()._id,
      $set:
        dateformat: t.find('#set-date-format').value
        apiKey: t.find('#set-api-key').value
    showError msg: 'Settings saved', type: 'success'
  'click #btn-logout': -> Meteor.logout logoutCallback
  'click #btn-delete-me': -> deleteAccount()

# Notes list
formattedDate = ->
  return unless @date
  tick.depend()
  #dif = moment(@date, getUser().dateformat).diff(moment(), 'days')
  dif = moment.unix(@date).diff(moment(), 'days')
  color = "primary"
  color = "info" if dif < 7
  color = "warning" if dif is 1
  color = "danger" if dif < 1
  msg: moment.unix(@date).fromNow(), color: color
notePaginator = new Paginator(10)
notelist = ->
  notePaginator.calibrate(notes.find(archived: no).count())
  opt = notePaginator.queryOptions()
  notes.find({ archived: no },{
    sort: {date: 1}, skip: opt.skip, limit: opt.limit
  })
Template.notelist.helpers
  notelist: -> notelist().fetch()
  active: ->
    return no unless Router.current() and Router.current().data()
    return @_id is Router.current().data()._id
  empty: -> notelist().count() is 0
  getDate: formattedDate
  paginator: -> notePaginator
  pageActive: -> if @active then "btn-primary" else "btn-default"

Template.notelist.events
  'click .close-note': -> notes.update @_id, $set: archived: yes
  'click .edit-note': -> Router.go 'notes'
  'keypress #newNote': (e,template) ->
    if e.keyCode is 13 and template.find('#newNote').value isnt ""
      notes.insert
        title: template.find('#newNote').value
        content: "", date: no, archived: no, userId: Meteor.userId()
      template.find('#newNote').value = ""
  'click .btn': -> notePaginator.page @index

# Archive
archivePaginator = new Paginator(10)
archived = ->
  archivePaginator.calibrate(notes.find(archived: yes).count())
  opt = archivePaginator.queryOptions()
  notes.find({archived: yes},{
    sort: {date: 1}, limit: opt.limit, skip: opt.skip
  })
Template.archivedlist.helpers
  empty: -> archived().count() is 0
  getDate: formattedDate
  archived: -> archived().fetch()
  paginator: -> archivePaginator
  pageActive: -> if @active then "btn-primary" else "btn-default"
Template.archivedlist.events
  'click .close-note': -> notes.remove @_id
  'click .note': -> notes.update @_id, $set: archived: no
  'click .clear': ->
    notes.remove item._id for item in Template.archivedlist.archived()
  'click .btn': (e) -> archivePaginator.page @index

# Note Editor
Template.editor.helpers
  note: -> Router.current().data()
  dateformat: -> getUser().dateformat
  formattedDate: ->
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

# "Error" visualization template
showError = (err) ->
  return unless err?
  type = err.type or 'error'
  if !err.title?
    title = if type is 'error' then 'Error' else 'Ok'
  else title = err.title
  swal title, err.msg, type

# Verify Email page
Template.verifyEmail.helpers
  token: -> Router.current().params.token
Template.verifyEmail.events
  'click #btn-verify': (e,template) ->
    t = template.find('#token-field').value; t = t.split("/")
    t = t[t.length-1] # Remove all the part before the last "/"
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
