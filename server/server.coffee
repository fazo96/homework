# Homework - Server Side
notes = new Meteor.Collection "notes"

validateEmail = (email) ->
  expr = /^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/
  expr.test email

Accounts.config {
  sendVerificationEmail: false
  loginExpirationInDays: 1
}

Meteor.publish "my-notes", ->
  notes.find( { userId: @userId } ) unless not @userId

# Authentication
Accounts.validateNewUser (user) ->
  mail = user.emails[0].address
  if Match.test(mail,String) is no or validateEmail(mail) is no
    throw new Meteor.Error 403, "Invalid Email"
  return yes
