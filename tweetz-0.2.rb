require 'rubygems'
require 'rss'
require 'xmlsimple'

class TweetzPlugin < Plugin

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

    # Start our timers at five minutes
    time_frame = 600
    @registry.keys.each { |key|
      if key =~ /feed\|/
        # Get the url from our feed key
        url = url_from_feed_key(key)
      
        # This does a few things:  
        # Creates a new timer. 
        # Stores the timer action_id
        save_value("action", url, add_timer(url, time_frame))
      
        # Stagger our saved feed updates, so we're not hammering twitter AND spamming IRC
        time_frame += 60
      end
    }
  end
  
  def check_rate_limit
    xml = @bot.httputil.get("http://twitter.com/account/rate_limit_status.xml") 
    data = XmlSimple.xml_in(xml)
    return data["remaining-hits"][0]["content"]
  end
  
  def url_from_feed_key(feed)
    feed.split("|")[1]
  end
  
  def save_value(prefix,identifier,val)
    @registry["#{prefix}|#{identifier}"] = val
  end
  
  def get_value(prefix,identifier)
    @registry["#{prefix}|#{identifier}"]
  end
  
  def help(plugin, topic="")
    "tweetz follow <url> => Follow Twitter RSS feed.\ntweetz list => Lists the twitter feeds I'm following\ntweetz remove <url> => Removes a URL from the list of feeds I'm following"
  end
 
  def follow(m, params)
    feed_url = params[:url]
    if feed_url =~ /http:\/\/twitter\.com\/statuses\/user_timeline\//
      rss = RSS::Parser.parse(@bot.httputil.get(feed_url), nil)      
      
      twitter_name = rss.channel.title.split(" / ")[1]
      save_value("username",feed_url,twitter_name)
      save_value("channel",feed_url,m.channel.downcase)
      
      m.reply "Latest tweet: #{rss.items[0].title} [#{rss.items[0].date}]"
      last_time = get_value("feed",feed_url)
      if not last_time
        m.reply "I will now follow #{twitter_name}."
      end
      save_value("feed",feed_url,rss.items[0].date.strftime("%Y%m%d%H%M%S"))
      save_value("action",feed_url,add_timer(feed_url))
    else
      m.reply "That does not look like a twitter rss feed."
    end
  end
  
  def add_timer(feed_url, time_period = 600.0)
    channel = get_value("channel",feed_url)
    if not time_period
      time_period = 600.0
    end
    save_value("nextupdate",feed_url,(Time.now + time_period).strftime("%Y%m%d%H%M%S"))
    @bot.timer.add(time_period) {
      rate_limit = check_rate_limit()
      if rate_limit.to_i > 0
        twitter = RSS::Parser.parse(@bot.httputil.get(feed_url), nil)
        for item in twitter.items
          mydate = item.date.strftime("%Y%m%d%H%M%S")
          if mydate > get_value("feed",feed_url)
            @bot.say(channel, "Tweetz: #{item.title} [#{item.date}]")
          end
        end
        save_value("feed",feed_url,twitter.items[0].date.strftime("%Y%m%d%H%M%S"))
        save_value("nextupdate",feed_url,(Time.now + time_period).strftime("%Y%m%d%H%M%S"))        
      end
    }
  end
  
  def list(m, params)
    feed_count = 0
    @registry.keys.each { |key|
      if key =~ /feed\|/
        url = url_from_feed_key(key.to_s)
        m.reply("Following #{get_value("username",url)} for channel #{get_value("channel",url)}.  Next update in #{(get_value("nextupdate",url).to_i - Time.now.strftime("%Y%m%d%H%M%S").to_i) / 60} minutes.")
        feed_count += 1
      end
    }
    if feed_count == 0
      m.remply("I am not following any people on twitter.  Add some!")
    end
    m.reply "Remaining API hits: #{check_rate_limit()}"
  end
  
  def remove(m,params)
    url = params[:url]
    if url
      if url !~ /http:\/\//
        username = url
        @registry.keys.each { |key|
          if key =~ /username\|/
            if @registry[key] == username
              url = key.split("|")[1]
              break
            end
          end
        }        
      end
      action_id = get_value("action",url)
      if action_id
        @bot.timer.remove(action_id)
        @registry.delete("username|#{url}")
        @registry.delete("nextupdate|#{url}")
        @registry.delete("feed|#{url}")
        @registry.delete("action|#{url}")
        @registry.delete("channel|#{url}")
        m.reply "#{url} is no longer being followed."
      else
        m.reply "I am not following that url."
      end
    else
      m.reply "Please supply a valid url"
    end
  end
  
end
plugin = TweetzPlugin.new
plugin.map 'tweetz follow :url', :action => 'follow'
plugin.map 'tweetz remove :url', :action => 'remove'
plugin.map 'tweetz list', :action => 'list'
plugin.map 'tweetz'
