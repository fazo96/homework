###
describe 'user creation', ->
  it 'requires a valid email and a password', (done) ->
    Accounts.createUser {
      email: 'a@b.com',
      password: 'somepassword'
    }, (err) -> expect(err).toBeUndefined(); done()

  it "doesn't work without a password", ->
    id = Accounts.createUser {
      email: 'a@b.c'
    }
    expect(id).toBeUndefined()

  it "doesn't work with an invalid email", ->
    id = Accounts.createUser {
      email: 'abbbbb.c',
      password: 'somepassword'
    }
    expect(id).toBeUndefined()

  it "adds the user's date format if it's not specified", ->
    id = Accounts.createUser {
      email: 'a@b.c',
      password: 'somepassword'
    }
    expect(Meteor.users.findOne(id).dateformat).toBe(jasmine.any('String'))

  it "records the user's date format", ->
    id = Accounts.createUser {
      email: 'a@b.c',
      password: 'somepassword'
      dateformat: 'DD/MM/YYYY'
    }
    expect(Meteor.users.findOne(id).dateformat).toBe('DD/MM/YYYY')
###
