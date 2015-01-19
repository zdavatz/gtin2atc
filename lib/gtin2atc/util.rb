require 'date'
module Gtin2atc
  class Util
    @@archive = File.expand_path(File.join(__FILE__, '../../..'))
    @@today   = Date.today
    def Util.get_today
      @@today
    end
    def Util.set_archive_dir(archiveDir)
      @@archive = archiveDir
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
  def Gtin2atc.download_finished(file, remove_file = true)
  end
end