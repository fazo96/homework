# Homework
Schoolwork management application for students. Built using
[Meteor](http://github.com/meteor/meteor), a Web App framework on top of Node.js
and MongoDB.

I built this because I felt like the other apps didn't do it very well.
Also, I learnt a lot and had fun!

### Try it
[the app is hosted online!](http://homework.meteor.com)

### Development
Clone the repo, [install meteor](http://meteor.com), `cd` to the directory
then run `meteor`.

That's it.

If you want to send emails (necessary to confirm users) you need to set the
`MAIL_URL` environment variable, or else the emails will just be printed on
stdout. The process is
[explained on the Meteor docs](http://docs.meteor.com/#email).

In the mails sent by Homework, the website links point to the `ROOT_URL`
environment variable as
[explained on the Meteor docs](http://docs.meteor.com/#meteor_absoluteurl).

You'll probably also need [phantomjs](http://phantomjs.org/) installed
since the apps now depends on Meteor's
[spiderable](http://docs.meteor.com/#spiderable) package.

#### Twitter Authentication

Create this file: `server/settings.coffee` with this content:

```coffeescript
Meteor.startup ->
  Accounts.loginServiceConfiguration.remove service : 'twitter'
  Accounts.loginServiceConfiguration.insert
    service: 'twitter'
    consumerKey: 'Your API key'
    secret: 'Your API secret'
```

### License
The MIT License (MIT)

Copyright (c) 2014 Enrico Fasoli

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
