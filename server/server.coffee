# Homework - Server Side
notes = new Meteor.Collection "notes"

validateEmail = (email) ->
  expr = /^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/
  expr.test email

Accounts.config {
  sendVerificationEmail: false
  loginExpirationInDays: 1
}

# Returns true if the user has verified at least one email address
userValidated = (user) ->
  return yes for mail in user.emails when mail.verified is yes; no

Meteor.publish "my-notes", ->
  # TODO: Don't publish unless user is validated
  notes.find( { userId: @userId } ) unless not @userId

# Authentication
Accounts.validateNewUser (user) ->
  mail = user.emails[0].address
  if Match.test(mail,String) is no or validateEmail(mail) is no
    throw new Meteor.Error 403, "Invalid Email"
  return yes

# Methods that the clients can invoke
Meteor.methods
  amIValidated: ->
    user = Meteor.users.findOne { _id: @userId }
    return no unless user?
    userValidated user
