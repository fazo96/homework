describe 'validateEmail', ->
  it 'accepts valid email addresses', ->
    ['a@b.com','test@you.me'].forEach (e) ->
      expect(validateEmail(e)).toBe(true)

  it 'refuses invalid email addresses', ->
    ['ciao','test','@@.eee','...@','a@b.c'].forEach (e) ->
      expect(validateEmail(e)).toBe(false)

describe 'userValidated', ->
  it 'does not crash with null parameters', ->
    expect(userValidated()).toBe(false)
  it 'treats twitter users as valid', ->
    user = { services: twitter: {}}
    expect(userValidated(user)).toBe(true)
  it 'treats email users as valid only if they verified their email', ->
    user = { services: {}, emails: [ {address: 'a@b.com', verified: false} ] }
    expect(userValidated(user)).toBe(false)
    user.emails[0].verified = true
    expect(userValidated(user)).toBe(true)
