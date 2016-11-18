request = require 'request'
{ type } = Core.db

danbooru = require('request-promise').defaults {
  baseUrl: 'https://danbooru.donmai.us/'
  auth:
    user: process.env.DANBOORU_LOGIN
    pass: process.env.DANBOORU_API_KEY
  simple: true
}

Waifu = Core.db.createModel 'Waifu', {
  id: type.string()
  user: type.string()
  waifu: type.string()
}

class DanbooruModule extends BotModule
  init: =>
    {@prefix} = @engine

    @registerCommand 'danbooru', {
      allowDM: true
      aliases: ['d']
    }, (msg, tags, d)=>
      tags = 'rating:safe ' + tags if not d.data.allowNSFW
      qs = {
        random: true
        limit: 1
        tags
      }
      danbooru.get '/posts.json', { json: true, qs }
      .then (r)=>
        url = "https://danbooru.donmai.us#{r[0].file_url}"
        msg.channel.uploadFile request(url), @getFileName(url)
      .catch (e)=>
        msg.reply 'Something went wrong.'

    @registerCommand 'setwaifu', {
      aliases: ['setHusbando'],
      includeCommandNameInArgs: true
      allowDM: true
    }, (msg, args, d)=>
      waifu = (args[1].match(/\w+/) or [''])[0]
      return msg.reply "Usage: ```#{@prefix}#{args[0]} <danbooru_tag>```" if not waifu
      # Do a dummy search
      qs = {
        limit: 1
        tags: 'rating:safe ' + waifu
      }
      danbooru.get '/posts.json', { json: true, qs }
      .then (r)=>
        return Promise.reject { msg: 'Invalid danbooru tag.' } if not r.length
        Waifu.filter({ user: msg.author.id }).run()
      .then (results)=>
        return results[0] if results[0]?
        new Waifu { user: msg.author.id }
      .then (w)=>
        w.waifu = waifu
        w.save()
      .then ()=>
        msg.reply 'Success.'
      .catch (e)=>
        return msg.reply e.msg if e.msg
        msg.reply 'Something went wrong.'

    @registerCommand 'waifu', {
      aliases: ['husbando', 'w', 'h'],
      allowDM: true
    }, (msg)=>
      Waifu.filter({ user: msg.author.id }).run()
      .then (results)=>
        return Promise.reject { msg: "Run the #{@prefix}setWaifu command first." } if not results[0]?
        qs = {
          limit: 1
          random: true
          tags: 'rating:safe ' + results[0].waifu
        }
        danbooru.get '/posts.json', { json: true, qs }
      .then (r)=>
        url = "https://danbooru.donmai.us#{r[0].file_url}"
        msg.channel.uploadFile request(url), @getFileName(url)
      .catch (e)=>
        return msg.reply e.msg if e.msg
        msg.reply 'Something went wrong.'
  
  getFileName: (url)=> url.split('/').reverse()[0]


module.exports = DanbooruModule
