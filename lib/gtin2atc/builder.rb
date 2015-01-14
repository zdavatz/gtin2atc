require "gtin2atc/options"
require 'mechanize'

module Gtin2atc
  class Util
    @@archive = File.expand_path(File.join(__FILE__, '../../..', 'data'))
    @@today   = Date.today
    def Util.get_today
      @@today
    end
    def Util.get_archive
      @@archive
    end
    def Util.debug_msg(msg)
      if defined?(MiniTest) then $stdout.puts Time.now.to_s + ': ' + msg; $stdout.flush; return end
      if not defined?(@@checkLog) or not @@checkLog
        name = File.join(@@archive, 'log.log')
        FileUtils.makedirs(@@archive)
        @@checkLog = File.open(name, 'a+')
        $stdout.puts "Opened #{name}"
      end
      @@checkLog.puts("#{Time.now}: #{msg}")
      @@checkLog.flush
    end
    def Util.get_latest_and_dated_name(keyword, extension)
      return File.expand_path(File.join(Util.get_archive, keyword + '-latest' + extension)),
          File.expand_path(File.join(Util.get_archive, Util.get_today.strftime("#{keyword}-%Y.%m.%d" + extension)))
    end
  end
  class Builder
    def initialize(opts)
      puts "opts are #{opts}"
    end
    def run
      Swissmedic.get_latest
    end
  end
  class Swissmedic
    def Swissmedic.get_latest
      Util.debug_msg 'test'
      @index_url = 'https://www.swissmedic.ch/arzneimittel/00156/00221/00222/00230/index.html?lang=de'
      Util.debug_msg("SwissmedicPlugin @index_url #{@index_url}")
      latest_name, target =  Util.get_latest_and_dated_name('Packungen', '.xlsx')
      if File.exist?(target)
        Util.debug_msg "#{__FILE__}: #{__LINE__} skip writing #{target} as it already exists and is #{File.size(target)} bytes."
        return target
      end
      $stderr.puts "target #{target} #{latest_name}"
      latest = ''
      if(File.exist? latest_name)
        latest = File.read latest_name
        return
      end

      agent=Mechanize.new
      page = agent.get @index_url
      links = page.links.select do |link|
        /Packungen/iu.match link.attributes['title']
      end
      link = links.first or raise "could not identify url to Packungen.xlsx"
      file = agent.get(link.href)
      download = file.body

      if(download[-1] != ?\n)
        download << "\n"
      end
      if(!File.exist?(latest_name) or download.size != File.size(latest_name))
        File.open(target, 'w') { |fh| fh.puts(download) }
        msg = "#{__FILE__}: #{__LINE__} updated download.size is #{download.size} -> #{target} #{File.size(target)}"
        msg += "#{target} now #{File.size(target)} bytes != #{latest_name} #{File.size(latest_name)}" if File.exists?(latest_name)
        Util.debug_msg(msg)
        target
      else
        Util.debug_msg "#{__FILE__}: #{__LINE__} skip writing #{target} as #{latest_name} is #{File.size(latest_name)} bytes. Returning latest"
        nil
      end
    end

  end
  VERSION = "0.1.0"
end
