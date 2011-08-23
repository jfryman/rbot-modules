# :title: Twitter Plugin for rBot
#
# Copyright James Fryman 2011, http://www.frymanet.com
#
# Licensed under the terms of the GNU General Public License v2 or higher\
# https://api.twitter.com/1/statuses/user_timeline.json?screen_name=jfryman

require 'rubygems'
require 'net/https'
require 'time'
require 'uri'
require 'json'

class TweeterPlugin < Plugin
  def initalize
    super
    class << @registry
      def store(val)
        val
      end
      def restore(val)
        val
      end
    end
    
    time_frame = 600
    @registry.keys.each { |key|
      if key =~ /username\|/
        # Get the url from our feed key
        user = user_from_key_value(key)
      
        # This does a few things:  
        #   - Creates a new timer. 
        #   - Stores the timer action_id
        save_value("action", url, add_timer(user, time_frame))
      
        # Stagger our saved feed updates, so we're not hammering twitter AND spamming IRC
        time_frame += 60
      end
    }
  end
  
  def follow(m, params)
    user = params[:user]
    feed = "https://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{user}"
    
    json = get_json(feed)
    if json.has_value?('error')
      m.reply "That is an invalid Twitter user"
    else
      save_value('username', user, user)
      save_value('channel', user, m.channel.downcase)
      save_value('lastupdate', user, Time.parse(json[0]['created_at']).strftime("%Y%m%d%H%M%S"))
      save_value('feed', user, feed)
      save_value('action', user, add_timer(user))
      m.reply "Latest tweet: #{json[0]['text']} #{json[0]['created_at']}"
      m.reply "I am now following #{user}"
    end
  end
  
  def remove(m, params)
    user = params[:user]
    action_id = get_value("action", user)
    if action_id
      @bot.timer.remove(action_id)
      @registry.delete("username|#{user}")
      @registry.delete("nextupdate|#{user}")
      @registry.delete("lastupdate|#{user}")
      @registry.delete("action|#{user}")
      @registry.delete("channel|#{user}")
      @registry.delete("feed|#{user}")
      m.reply "#{user} is no longer being followed."
    else
      m.reply "I am not following that user."
    end
  end

  def list(m, params)
    feed_count = 0
    @registry.keys.each { |key|
      if key =~ /username\|/
        user = user_from_key_value(key.to_s)
        m.reply("Following #{get_value("username", user)} for channel #{get_value("channel", user)}.  Next update in #{(get_value("nextupdate", user).to_i - Time.now.strftime("%Y%m%d%H%M%S").to_i) / 60} minutes.")
        feed_count += 1
      end
    }
    if feed_count == 0
      m.reply("I am not following any people on twitter. Add some!")
    end
    m.reply "Remaining API hits: #{check_rate_limit()}"
  end
  
  def add_timer(user, time_period=600.0)
    channel = get_value('channel', user)
    if not time_period
      time_period = 600.0
    end
    
    save_value('nextupdate', user, (Time.now + time_period).strftime("%Y%m%d%H%M%S"))
    @bot.timer.add(time_period) {
      if check_rate_limit() > 0
        json = get_json(get_value('feed', user))
        json.each { |item|
          mydate = Time.parse(item['created_at']).strftime("%Y%m%d%H%M%S")
          
          if mydate > get_value('lastupdate', user)
            @bot.say(channel, "Tweeter: #{item['text']} [#{item['created_at']}]")
          end
          
          puts "Saving Value: #{Time.parse(json[0]['created_at']).strftime("%Y%m%d%H%M%S"))}"
          #save_value('lastupdate', user, Time.parse(json[0]['created_at']).strftime("%Y%m%d%H%M%S"))
          #save_value('nextupdate', user, (Time.now + time_period).strftime("%Y%m%d%H%M%S"))
        }
      end
    }
  end

  def help(plugin, topic="")
    "tweeter follow <user>\t=> Follow Twitter user.\ntweeter remove <user>\t=> Removes a user from the list of users I'm following\ntweeter list\t=> Lists the twitter feeds I'm following"
  end
  
  def check_rate_limit
    json = get_json("https://api.twitter.com/1/account/rate_limit_status.json")
    json['remaining_hits']
  end
  
  def get_json(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    JSON.parse(response.body)
  end
  
  def save_value(prefix,identifier, val)
    @registry["#{prefix}|#{identifier}"] = val
  end
  
  def get_value(prefix,identifier)
    @registry["#{prefix}|#{identifier}"]
  end
  
  def user_from_key_value(key)
    feed.split("|")[1]
  end
end

# Begin Plugin Instantiation. 
plugin = TweeterPlugin.new
plugin.map 'tweeter follow :user', :action => 'follow'
plugin.map 'tweeter remove :user', :action => 'remove'
plugin.map 'tweeter list',         :action => 'list'
plugin.map 'tweeter'