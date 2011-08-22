#!/usr/bin/env ruby
#
# gitwatch - a git plugin for rbot.
#
# This file should be placed in the rbot plugins/ directroy. When you
# load rbot it will scan the directory and load this plugin. DRb will
# automatically start up.
#
# Copyright (c) 2011, James Fryman
#
# based on code provided by
# Copyright (c) 2005, Ben Bleything and Robby Russell
# Released under the terms of the MIT License
#

require 'drb'

# Configuration Options
@conf = {
  :port => '7666',       # 7666 (you will need this to be the same in post-commit)
  :host => 'localhost',  # localhost, don't set to remote ip unless you know what you are doing
  :chan => '#ctp'     # IRC channel that you want rbot to send notices to
}

class GitWatch < Plugin

  attr_writer :channel

  def privmsg(m)
    m.reply "I don't actually have anything to say. I just sit and wait for git to call me."
  end

  def git_commit(info)
    @bot.say @channel, info
  end
end

# register with rbot
@gitwatch = GitWatch.new
@gitwatch.channel = @conf[:chan]
@gitwatch.register("gitwatch")

# start DRb in a new thread so it doesn't hang up the bot
Thread.new {
  # start the DRb instance
  DRb.start_service("druby://#{@conf[:host]}:#{@conf[:port]}", @gitwatch)
  DRb.thread.join
}
