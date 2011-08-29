# :title: Public RSS Announcer Plugin for rBot
# slightly modified from tweeter.rb code for rBot
#
# Licensed under the terms of the GNU General Public License v2 or higher\
# https://api.twitter.com/1/statuses/user_timeline.json?screen_name=jfryman
#
require 'rubygems'
require 'simple-rss'
require 'open-uri'

class PTWatchPlugin < Plugin
  def initialize
    super
    Config.register Config::StringValue.new('ptwatch.url',:default => "https://www.pivotaltracker.com/projects/344511/activities/d5a0f1e5f569ad6926a8ba1ae8f8d629", :desc => 'RSS Feed of the pivotal tracker page')
    Config.register Config::StringValue.new('ptwatch.channel',:default => "#ctp", :desc => 'Channel to report updates')
    Config.register Config::IntegerValue.new('ptwatch.seconds', :default => 300, :desc => 'number of seconds to check (5 minutes is the default)')

    @last_updated = Time.now
  end

  def watchfeed
    check_feed
  end

  def debug(m, params)
    m.reply "the current timer is: #{@timer.to_s} - lastupdated = #{@last_updated.to_s}"
  end

  def dontwatchfeed(m,params)
    if @timer
      @bot.timer.remove(@timer)
      m.reply "no longer watching PT, stopping timer #{@timer.to_s}"
    end
  end

  def check_feed
    @bot.say '#ctp', 'i checked the rss feed for ya buddy'
    begin
      rss = SimpleRSS.parse open(@bot.config['ptwatch.url'])
      new = rss.items.collect { |item| item if item[:updated] > @last_updated }
      new.each do |item| 
        @bot.say '#ctp', "#{HTMLEntities.new.decode(item.title)} :: #{event.link}"
      end
      @last_updated = Time.now
    rescue
      @bot.say '#ctp', "the plugin PTWatchPlugin failed"
      cleanup
    end

    set_timer
  end

  def cleanup
    @bot.timer.remove(@timer)
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
