# :title: Public RSS Announcer Plugin for rBot
# slightly modified from tweeter.rb code for rBot
#
# Copyright James Fryman 2011, http://www.frymanet.com
#
# Licensed under the terms of the GNU General Public License v2 or higher\
# https://api.twitter.com/1/statuses/user_timeline.json?screen_name=jfryman

require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'time'
require 'uri'
require 'htmlentities'

class RssannouncePlugin < Plugin
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
      
        # Stagger our saved feed updates, so we're not hammering RSS feeds.
        time_frame += 60
      end
    }
  end
  
  def follow(m, params)
    begin
      feed = params[:feed]
      rss  = get_rss(feed)
    
      save_value('name', feed, rss.channel.title)
      save_value('feed', feed, feed)
      save_value('channel', feed, m.channel.downcase)
      save_value('lastupdate', feed, rss.items.first.updated.strftime("%Y%m%d%H%M%S"))
      save_value('action', feed, add_timer(feed))
    
      m.reply "#{HTMLEntities.new.decode(rss.items.first.title)} :: #{rss.items.first.link}"
      m.reply "I am now following #{rss.channel.title}"
    rescue => e
      m.reply "I cannot complete that operation: #{e.message}"
      m.reply e.backtrace
    end
  end
  
  def remove(m, params)
    feed       = params[:feed]
    action_id  = get_value('action', feed)
    feed_title = get_value('name', feed)
    
    if action_id
      @bot.timer.remove(action_id)
      @registry.delete("username|#{feed}")
      @registry.delete("nextupdate|#{feed}")
      @registry.delete("lastupdate|#{feed}")
      @registry.delete("action|#{feed}")
      @registry.delete("channel|#{feed}")
      @registry.delete("feed|#{feed}")
      m.reply "#{feed_title} is no longer being followed."
    else
      m.reply "I am not following that RSS feed."
    end
  end

  def list(m, params)
    feed_count = 0
    @registry.keys.each { |key|
      if key =~ /feed\|/
        feed = feed_from_key_value(key.to_s)
        m.reply("Following #{get_value("name", feed)} for channel #{get_value("channel", feed)}.  Next update in #{(get_value("nextupdate", feed).to_i - Time.now.strftime("%Y%m%d%H%M%S").to_i) / 60} minutes. RSS Feed: #{get_value('feed', feed)}")
        feed_count += 1
      end
    }
    if feed_count == 0
      m.reply("I am not following any RSS feeds. Add some!")
    end
  end
  
  def add_timer(feed, time_period=5.0)
    channel = get_value('channel', feed)
    if not time_period
      time_period = 5.0
    end
    
    save_value('nextupdate', feed, (Time.now + time_period).strftime("%Y%m%d%H%M%S"))
    @bot.timer.add(time_period) {
      rss    = get_rss(get_value('feed', feed))
      mydate = rss.items.first.updated.strftime("%Y%m%d%H%M%S")
        
      if mydate > get_value('lastupdate', feed)
        @bot.say(channel, "#{HTMLEntities.new.decode(rss.items.first.title)} :: #{rss.items.first.link}")
      end
        
      #save_value('lastupdate', feed, rss.items.first.updated.strftime("%Y%m%d%H%M%S"))
      #save_value('nextupdate', feed, (Time.now + time_period).strftime("%Y%m%d%H%M%S"))
    }
  end

  def help(plugin, topic="")
    "rssannounce follow <feed> => Follow RSS feed.\nrssannounce remove <feed> => Removes a RSS feed from the list of RSS feeds I'm following\rssannounce list => Lists the RSS feeds I'm following"
  end
  
  def get_rss(url)
    rss = SimpleRSS.parse open(url)
  end
  
  def save_value(prefix,identifier, val)
    @registry["#{prefix}|#{identifier}"] = val
  end
  
  def get_value(prefix,identifier)
    @registry["#{prefix}|#{identifier}"]
  end
  
  def feed_from_key_value(key)
    key.split("|")[1]
  end
end

# Begin Plugin Instantiation. 
plugin = RssannouncePlugin.new
plugin.map 'rssannounce follow :feed', :action => 'follow'
plugin.map 'rssannounce remove :feed', :action => 'remove'
plugin.map 'rssannounce list',         :action => 'list'
plugin.map 'rssannounce'
