# Homework - Server Side
notes = new Meteor.Collection "notes"

Accounts.config {
  sendVerificationEmail: true
  loginExpirationInDays: 1
}

Meteor.publish "my-notes", ->
  notes.find( { userId: @userId } ) unless not @userId

# Authentication
Accounts.validateNewUser (user) ->
  if Match.test(user.email, String) and validateEmail user.email is yes
    if user.password and Match.test(user.password,String) is yes and user.password.length > 7
      return yes
    else throw new Meteor.Error 403, "Invalid Password"
  else throw new Meteor.Error 403, "Invalid Email"
