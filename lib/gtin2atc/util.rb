require 'date'
module Gtin2atc
  class Util
    @@archive = Dir.pwd
    @@today   = Date.today
    @@logging = false
    def Util.get_today
      @@today
    end
    def Util.set_archive_dir(archiveDir)
      @@archive = archiveDir
    end
    def Util.get_archive
      @@archive
    end
    def Util.set_logging(default)
      @@logging = default
    end
    def Util.info(msg)
      puts msg
      return unless @@logging
      Util.init
      @@checkLog.puts("#{Time.now}: #{msg}")
    end
    def Util.init
      return unless @@logging
      if not defined?(@@checkLog) or not @@checkLog
        name = File.join(@@archive, 'log.log')
        FileUtils.makedirs(@@archive)
        @@checkLog = File.open(name, 'a+')
      end
    end
    def Util.debug_msg(msg)
      return unless @@logging
      Util.init
      if @@logging or defined?(MiniTest) then $stdout.puts Time.now.to_s + ': ' + msg; $stdout.flush; return end
      @@checkLog.puts("#{Time.now}: #{msg}")
      @@checkLog.flush
    end
    def Util.get_latest_and_dated_name(keyword, extension)
      return File.expand_path(File.join(Util.get_archive, keyword + '-latest' + extension)),
          File.expand_path(File.join(Util.get_archive, Util.get_today.strftime("#{keyword}-%Y.%m.%d" + extension)))
    end
  end
  def Gtin2atc.download_finished(file, remove_file = true)
  end
end