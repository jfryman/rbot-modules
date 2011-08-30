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

    @last_updated = Time.now - 3600
    @timer = nil
  end

  def startfeed(m, params)
    if @timer.nil?
    	set_timer(@bot.config['ptwatch.seconds'])
    else
      m.reply "I'm already watching your project with timer #{@timer.to_s}"
    end
  end

  def debug(m, params)
    m.reply "the current timer is: #{@timer.to_s} - lastupdated = #{@last_updated.to_s}"
  end

  def stopfeed(m, params)
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
    end
  end

  def cleanup
    super
    @bot.timer.remove(@timer)
  end

  def set_timer(interval)
    unless !@timer.nil?
      @timer = @bot.timer.add(interval) { check_feed }
    end
  end

end

# Begin Plugin Instantiation.
plugin = PTWatchPlugin.new
plugin.map 'ptwatch start', :action => 'startfeed'
plugin.map 'ptwatch stop',  :action => 'stopfeed'
plugin.map 'ptwatch help',  :action => 'debug'
