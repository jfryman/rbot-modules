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
    Config.register Config::StringValue.new('ptwatch.url',:default => "https://www.pivotaltracker.com/projects/344511/activities/d5a0f1e5f569ad6926a8ba1ae8f8d629", desc => 'RSS Feed of the pivotal tracker page')
    Config.register Config::StringValue.new('ptwatch.channel',:default => "#ctp", desc => 'Channel to report updates')
    Config.register Config::IntegerValue.new('ptwatch.seconds', :default => 300, :desc => 'number of seconds to check (5 minutes is the default)')

    @last_updated = Time.now
  end

  def start
    check_feed
  end

  def stop
    if @timer
      @bot.timer.remove(@timer)
      @bot.say(@bot.config['ptwatch.channel'], "no longer watching PT")
    end
  end

  def output(event)
    @bot.say(@bot.config['ptwatch.channel'], "#{HTMLEntities.new.decode(event.title)} :: #{event.link}")
  end

  def check_feed
    begin
      rss = SimpleRSS.parse open(@bot.config['ptwatch.url'])
      new = rss.items.collect { |item| item if item[:updated] > @last_updated }
      new.each { output(item) }
    rescue
      @bot.say(@bot.config['ptwatch.channel'], "the plugin PTWatchPlugin failed")
      cleanup
      set_timer
    end
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
plugin.map 'ptwatch start', :action => 'start'
plugin.map 'ptwatch stop', :action => 'remove'
