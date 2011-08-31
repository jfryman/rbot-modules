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
    
    BotConfig.register BotConfigIntegerValue.new('ptwatch.update',
      :default => 600, :validate => Proc.new{|v| v > 0},
      :desc => "Number of seconds between RSS Polling")
    
    @update_freq = @bot.config['ptwatch.update']
    @timer       = Hash.new
    
    startfeed
  end

  def startfeed
#    get_stored_feeds.each_with_index { |feed, i| 
#      set_timer(feed, (@update_freq + ((i+1)*60)))
#    } if get_stored_feeds.size > 0
  end
  
  def list(m, params)
    if get_stored_feeds.size > 0
      get_stored_feeds.each { |feed|
        m.reply "Following #{get_value("name", feed)} for channel #{get_value("channel", feed)}.  Next update at #{get_value("nextupdate", feed)}. RSS Feed: #{get_value('feed', feed)}. Timer ID: #{@timer['#{feed}']}"
      }
    else
      m.reply "I am not following any RSS feeds. Add some!"
    end
  end
  
  def add(m, params)
    begin
      feed = params[:feed]
      rss = SimpleRSS.parse open(feed)
      
      if get_value('feed', feed).nil?
        save_value('name', feed, rss.channel.title)
        save_value('feed', feed, feed)
        save_value('channel', feed, m.channel.downcase)
        save_value('lastupdate', feed, rss.updated)
        save_value('nextupdate', feed, Time.now + @update_freq)
        @timer["#{feed}"] = set_timer(@update_freq, feed)
        m.reply "I am now following #{feed}"
      else
        @bot.say m.channel, "I am already following #{feed}"
      end
    rescue Exception => e
      @bot.say m.channel, "the plugin PTWatchPlugin failed #{e.to_s}"
    end
  end
  
  def remove(m, params)
    feed = params[:feed]
    if !get_value('feed', feed).nil?
      @bot.timer.remove(@timer["#{feed}"]) unless @timer["#{feed}"].nil?
      @registry.delete("name|#{feed}")
      @registry.delete("nextupdate|#{feed}")
      @registry.delete("lastupdate|#{feed}")
      @registry.delete("channel|#{feed}")
      @registry.delete("feed|#{feed}")
      m.reply "#{feed} is no longer being followed."
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
    @timer.each { |key| @bot.timer.remove[@timer["#{key}"]] }
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

  def get_stored_feeds(feeds = Array.new)
    @registry.keys.each { |key| feeds << key.split("|")[1] if key =~ /feed\|/ }
    feeds
  end

  def set_timer(interval, feed)
    unless !@timer["#{feed}"].nil?
      @timer["#{feed}"] = @bot.timer.add(interval) { check_feed(feed) }
    else
      m.reply "I'm already watching your project with timer #{timer['#{feed}'].to_s}"
    end
  end
end

# Begin Plugin Instantiation.
plugin = PTWatchPlugin.new
plugin.map 'ptwatch add :feed',    :action => 'add'
plugin.map 'ptwatch remove :feed', :action => 'remove'
plugin.map 'ptwatch list',         :action => 'list'
plugin.map 'ptwatch help',         :action => 'help'
