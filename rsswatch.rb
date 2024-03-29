# :title: Pivotal Tracker RSS feed reader for rbot
# Licensed under the terms of the GNU General Public License v2 or higher
# Copyright Aziz Shamim and James Fryman 2011

require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'htmlentities'
require 'time'

class RSSWatchPlugin < Plugin
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

    BotConfig.register BotConfigIntegerValue.new('rsswatch.update',
      :default => 600, :validate => Proc.new{|v| v > 0},
      :desc => "Number of seconds between RSS Polling")

    @update_freq = @bot.config['rsswatch.update']
    @timer       = Hash.new

    startfeed
  end

  def debug(m, params)
    if @timer.size > 0 && @registry.size > 0 
      m.reply "Local Timer Data:\n"
      @timer.each { |key, value| m.reply "#{key} => #{value}\n" }
      m.reply "Registry Data:\n"
      @registry.each { |key, value| m.reply "#{key} => #{value}\n"}
    else
      m.reply "There has been no data stored for RSSWatchPlugin yet"
    end
  end

  def startfeed
    if get_stored_feeds.size > 0
      get_stored_feeds.each_with_index do |feed, i|
        random_update = @update_freq + rand(300)
        set_timer(random_update, feed)
        save_value('nextupdate', feed, Time.now + random_update)
        save_value('updatefreq', feed, random_update)
      end
    end
  end

  def list(m, params)
    if get_stored_feeds.size > 0
      get_stored_feeds.each do |feed|
        reply = "#{get_value('name', feed)} :: "
        reply << "Next check at #{get_value('nextupdate', feed)} :: "
        reply << "RSS Feed: #{get_value('feed', feed)}. :: "
        reply << "Timer ID: #{@timer[feed]}"
        m.reply reply 
      end
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
        @timer[feed] = set_timer(@update_freq, feed)
        @bot.say m.channel, "I am now following #{get_value('name', feed)}"
      else
        @bot.say m.channel, "I am already following #{get_value('name', feed)}"
      end
    rescue Exception => e
      @bot.say m.channel, "ADD: the plugin RSSWatchPlugin failed #{e.to_s}"
    end
  end

  def remove(m, params)
    feed = params[:feed]
    if !get_value('feed', feed).nil?
      @bot.say m.channel, "#{get_value('name', feed)} is no longer being followed."
      @bot.timer.remove(@timer[feed]) unless @timer[feed].nil?
      @registry.delete("name|#{feed}")
      @registry.delete("nextupdate|#{feed}")
      @registry.delete("lastupdate|#{feed}")
      @registry.delete("channel|#{feed}")
      @registry.delete("feed|#{feed}")
      @timer[feed] = nil
    else
      @bot.say m.channel, "I am not following that RSS feed."
    end
  end

  def check_feed(feed)
    begin
      rss = SimpleRSS.parse open(feed)
      new = rss.items.collect { |item| item if item[:updated] > Time.parse(get_value('lastupdate', feed))}.compact.reverse
      new.each do |item|
        @bot.say get_value('channel', feed), "#{HTMLEntities.new.decode(item.title)} :: #{item.link}"
      end
      save_value('lastupdate', feed, rss.updated)
      save_value('nextupdate', feed, Time.now + get_value('updatefreq', feed).to_i)
    rescue Exception => e
      @bot.say get_value('channel', feed), "CHECK_FEED: the plugin RSSWatchPlugin failed #{e.to_s}"
    end
  end

  def cleanup
    super
    @timer.each { |feed| @bot.timer.remove[@timer[feed]] }
  end

  def help(plugin, topic="")
    message = "rsswatch follow <feed> => Follow feed.\n"
    message << "rsswatch remove <feed> => Removes a feed from the list of feeds I'm following\n"
    message << "rsswatch list => Lists the RSS feeds I'm following"
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
    unless !@timer[feed].nil?
      @timer[feed] = @bot.timer.add(interval) { check_feed(feed) }
    else
      @bot.say get_value('channel', feed), "I'm already watching your project with timer #{timer[feed]}"
    end
  end
end

# Begin Plugin Instantiation.
plugin = RSSWatchPlugin.new
plugin.map 'rsswatch add :feed',    :action => 'add'
plugin.map 'rsswatch remove :feed', :action => 'remove'
plugin.map 'rsswatch list',         :action => 'list'
plugin.map 'rsswatch help',         :action => 'help'
plugin.map 'rsswatch debug',        :action => 'debug'
