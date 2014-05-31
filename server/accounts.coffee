# Homework - Server side accounts code

validateEmail = (email) ->
  x = /^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/
  x.test email

Accounts.validateNewUser (user) ->
  mail = user.emails[0].address
  if Match.test(mail,String) is no or validateEmail(mail) is no
    throw new Meteor.Error 403, "Invalid Email"
  return yes

Accounts.config {
  sendVerificationEmail: true
  loginExpirationInDays: 1
}

Accounts.emailTemplates.siteName = "Homework App"
Accounts.emailTemplates.verifyEmail.text = (user,url) ->
  urlist = url.split('/'); token = urlist[urlist.length-1]
  '''Welcome to Homework! To activate your account, click on the \
  following link: http://homework.meteor.com/verify/'''+token
