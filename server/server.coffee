# Homework - Server Side

validateEmail = (email) ->
  expr = /^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/
  expr.test email

console.log "Started Homework server!"
if process.env.MAIL_URL
  console.log "Sending emails using "+process.env.MAIL_URL
else
  console.log "Not Sending Emails, please set the MAIL_URL environment variable"

notes = new Meteor.Collection "notes"

getUser = (id) -> Meteor.users.findOne { _id: id }

Accounts.config {
  sendVerificationEmail: true
  loginExpirationInDays: 1
}

Accounts.emailTemplates.siteName = "Homework App";
Accounts.emailTemplates.verifyEmail.text = (user,url) ->
  token = url.split('/'); token = token[token.length-1]
  '''Welcome to Homework! To activate your account, log in then provide the \
  following token: '''+token

# Returns true if the user has verified at least one email address
userValidated = (user) ->
  if not user?
    console.log "Impossible! Trying to validate null user"
    return no
  return yes for mail in user.emails when mail.verified is yes; no

# Publish user's notes to each user.
Meteor.publish "my-notes", ->
  if userValidated getUser(@userId)
    notes.find userId: @userId

# Authentication
Accounts.validateNewUser (user) ->
  mail = user.emails[0].address
  if Match.test(mail,String) is no or validateEmail(mail) is no
    throw new Meteor.Error 403, "Invalid Email"
  return yes

# Methods that the clients can invoke
Meteor.methods
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
  deleteMe: ->
    if @userId
      Meteor.users.remove @userId
      # Automagically log out the user by invalidating every token he has
      Meteor.users.update {_id: @userId},
      {$set : { "resume.loginTokens" : [] } }, { multi: yes }
      return yes
    else no
