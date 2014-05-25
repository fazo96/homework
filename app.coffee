todos = new Meteor.Collection "todos"

if Meteor.isServer
  #todos.insert { content: "Example" } unless todos.find().fetch().length > 0
  Meteor.publish "todos", -> todos.find()

if Meteor.isClient
  Meteor.subscribe "todos"
  Template.notes.notes = ->
    todos.find().fetch()
  Template.notes.events {
    'click .delete': ->
      todos.remove @_id
  }
  Template.adder.events {
    'keypress #newNote': (e,template) ->
      if e.keyCode is 13
        todos.insert { content: template.find('#newNote').value }
        template.find('#newNote').value = ""
  }
