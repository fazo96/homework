# Homework - Server Side
console.log "Started Homework server!"
if process.env.MAIL_URL
  console.log "Sending emails using "+process.env.MAIL_URL
else
  console.log "Not Sending Emails, please set the MAIL_URL environment variable"

notes = share.notes
getUser = (id) -> Meteor.users.findOne { _id: id }
isUsers = (u,doc) -> u and doc.userId is u

# Returns true if the user has verified at least one email address
userValidated = (user) ->
  return no unless user?
  return yes if user.services.twitter or user.services.facebook
  return yes for mail in user.emails when mail.verified is yes; no

Meteor.publish 'user', ->
  Meteor.users.find @userId, fields: {dateformat: 1, username: 1, apiKey: 1}
# Publish user's notes to each user.
Meteor.publish "notes", (archived) ->
  if userValidated getUser(@userId)
    notes.find userId: @userId, archived: archived

# Custom new account default settings
Accounts.onCreateUser (options, user) ->
  user.dateformat = options.dateformat or "MM/DD/YYYY"
  return user

# Database Permissions
# Allow all users to insert, update and remove their notes.
notes.allow insert: isUsers, update: isUsers, remove: isUsers

# Methods that the clients can invoke
Meteor.methods
  # Request another confirmation email.
  resendConfirmEmail: ->
    u = getUser(@userId)
    if not u
      console.log "Validating nonexisting user!"; return no
    if userValidated(u) is no
      Accounts.sendVerificationEmail @userId
      console.log "Sent verification email to "+u.emails[0].address
      return yes
    else
      console.log "User "+u.emails[0].address+" already validated."
      return no
  # Request user's account to be deleted
  deleteMe: ->
    if @userId
      Meteor.users.remove @userId
      # Automagically log out the user by invalidating every token he has
      Meteor.users.update {_id: @userId},
      {$set : { "resume.loginTokens" : [] } }, { multi: yes }
      return yes
    no

# Allow users to change their date format
Meteor.users.allow
  update: (id,doc,fields,mod) -> 
    for i,f of fields
      console.log f
      unless f in ['dateformat','apiKey']
        return no
    yes
  fetch: ['dateformat','apiKey']
