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
    Config.register Config::StringValue.new('ptwatch.url',:default => "https://www.pivotaltracker.com/projects/344511/activities/d5a0f1e5f569ad6926a8ba1ae8f8d629", :desc => 'RSS Feed of the pivotal tracker page')
    Config.register Config::StringValue.new('ptwatch.channel',:default => "#ctp", :desc => 'Channel to report updates')
    Config.register Config::IntegerValue.new('ptwatch.seconds', :default => 600, :desc => 'number of seconds to check (5 minutes is the default)')

    @last_updated = Time.now - 86400
    @timer = nil
  end

  def watchfeed(m, params)
    if @timer.nil?
      check_feed
    else
      @bot.say @bot.config['ptwatch.channel'], "I'm already watching your project. I'll check again in #{time_til}."
    end
  end

  def debug(m, params)
    m.reply "the current timer is: #{@timer.to_s} - lastupdated = #{@last_updated.to_s} - next check #{time_til}"
  end

  def time_til
    @timer.respond_to?(:in) ? @timer.in : 'unknown'
  end

  def dontwatchfeed(m, params)
    if @timer
      @bot.timer.remove(@timer)
      m.reply "no longer watching PT, stopping timer #{@timer.to_s}"
    end
  end

  def check_feed
    begin
      rss = SimpleRSS.parse open(@bot.config['ptwatch.url'])
      new = rss.items.collect { |item| item if item[:updated] > @last_updated }.compact
      new.each do |item| 
        @bot.say @bot.config['ptwatch.channel'], "#{HTMLEntities.new.decode(item.title)} :: #{item.link}"
      end
      @last_updated = rss.updated
    rescue Exception => e
      @bot.say @bot.config['ptwatch.channel'], "the plugin PTWatchPlugin failed #{e.to_s}"
      cleanup
    end

    set_timer
  end

  def cleanup
    @bot.timer.remove(@timer)
    @timer = nil
  end

  def set_timer
    @timer = @bot.timer.add(@bot.config['ptwatch.seconds']) { check_feed }
  end

end

# Begin Plugin Instantiation.
plugin = PTWatchPlugin.new
plugin.map 'ptwatch start', :action => 'watchfeed'
plugin.map 'ptwatch stop', :action => 'dontwatchfeed'
plugin.map 'ptwatch help', :action => 'debug'
