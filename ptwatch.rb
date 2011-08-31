# :title: Pivotal Tracker RSS feed reader for rbot
# Licensed under the terms of the GNU General Public License v2 or higher
# Copyright Aziz Shamim and James Fryman 2011
#
# TODO: Refactor out the channel config, add a per channel comm
# TODO: Refactor out the Config.register, add a per channel config

require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'htmlentities'

class PTWatchPlugin < Plugin
  def initialize
    super
    class << @registry
      def store(val)
        val
      end
      def restore(val)
        val
      end
    end
    
    Config.register Config::StringValue.new('ptwatch.url',:default => "https://www.pivotaltracker.com/projects/344511/activities/d5a0f1e5f569ad6926a8ba1ae8f8d629", :desc => 'RSS Feed of the pivotal tracker page')
    Config.register Config::StringValue.new('ptwatch.channel',:default => "#ctp", :desc => 'Channel to report updates')
    Config.register Config::IntegerValue.new('ptwatch.seconds', :default => 600, :desc => 'number of seconds to check (5 minutes is the default)')

    @last_updated = Time.now - 3600
    @timer = nil
  end

  def startfeed(m, params)
    if @timer[feed].nil?
    	set_timer(@bot.config['ptwatch.seconds'], feed)
    else
      m.reply "I'm already watching your project with timer #{@timer[feed].to_s}"
    end
  end

  def debug(m, params)
    m.reply "the current timer is: #{@timer.to_s} - lastupdated = #{@last_updated.to_s}"
  end
  
  def list(m, params)
    feed_count = 0
    @registry.keys.each { |key|
      if key =~ /feed\|/
        feed = feed_from_key_value(key.to_s)
        m.reply("Following #{get_value("name", feed)} for channel #{get_value("channel", feed)}.  Next update in #{(get_value("nextupdate", feed).to_i - Time.now.strftime("%Y%m%d%H%M%S").to_i) / 60} minutes. RSS Feed: #{get_value('feed', feed)}. Timer ID: #{get_value('timer', feed)}")
        feed_count += 1
      end
    }
    if feed_count == 0
      m.reply("I am not following any RSS feeds. Add some!")
    end
  end

  def stopfeed(m, params)
    if @timer
      @bot.timer.remove(@timer)
      m.reply "no longer watching PT, stopping timer #{@timer.to_s}"
    end
  end
  
  def follow(m, params)
    begin
      feed = params[:feed]
      rss = SimpleRSS.parse open(feed)
    
      save_value('name', feed, rss.channel.title)
      save_value('feed', feed, feed)
      save_value('channel', feed, m.channel.downcase)
      save_value('lastupdate', feed, rss.updated)
      save_value('timer', feed, set_timer(@bot.config['ptwatch.seconds'], feed))
    
      m.reply "I am now following #{rss.channel.title}"
    rescue Exception => e
      @bot.say m.channel, "the plugin PTWatchPlugin failed #{e.to_s}"
    end
  end
  
  def remove(m, params)
    feed       = params[:feed]
    action_id  = get_value('timer', feed)
    feed_title = get_value('name', feed)
    
    if action_id
      @bot.timer.remove(action_id)
      @registry.delete("name|#{feed}")
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

  def check_feed(feed)
    begin
      rss = SimpleRSS.parse open(feed)
      new = rss.items.collect { |item| item if item[:updated] > get_value(feed, 'lastupdate')}.compact
      new.each do |item| 
        @bot.say get_value(feed, 'channel'), "#{HTMLEntities.new.decode(item.title)} :: #{item.link}"
      end
      save_value(feed, 'lastupdate', rss.updated)
    rescue Exception => e
      @bot.say get_value(feed, 'channel'), "the plugin PTWatchPlugin failed #{e.to_s}"
    end
  end

  def cleanup
    super
    @bot.timer.remove(@timer)
  end
  
  def help(plugin, topic="")
    "ptwatch follow <feed> => Follow feed.\nptwatch remove <feed> => Removes a feed from the list of feeds I'm following\nptwatch list => Lists the RSS feeds I'm following"
  end
  
  def save_value(prefix,identifier, val)
    @registry["#{prefix}|#{identifier}"] = val
  end
  
  def get_value(prefix,identifier)
    @registry["#{prefix}|#{identifier}"]
  end

  def set_timer(interval, feed)
    @timer = @bot.timer.add(interval) { check_feed(feed) }
  end
end

# Begin Plugin Instantiation.
plugin = PTWatchPlugin.new
plugin.map 'ptwatch follow :feed', :action => 'follow'
plugin.map 'ptwatch remove :feed', :action => 'remove'
plugin.map 'ptwatch list',         :action => 'list'
plugin.map 'ptwatch start',        :action => 'startfeed'
plugin.map 'ptwatch stop',         :action => 'stopfeed'
plugin.map 'ptwatch help',         :action => 'debug'
