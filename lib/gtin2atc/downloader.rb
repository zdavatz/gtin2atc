# encoding: utf-8
# Copied and only using BAG SwissIndex from oddb2xml/downloader.rb
require 'mechanize'
require 'zip'
require 'savon'

module Gtin2atc
  module DownloadMethod
    private
    def download_as(file, option='r')
      tempFile  = File.join(WorkDir,   File.basename(file))
      file2save = File.join(Util.get_archive, File.basename(file))
      Gtin2atc.log "download_as file #{file2save} via #{tempFile} from #{@url}"
      data = nil
      FileUtils.rm_f(tempFile, :verbose => false)
      if Gtin2atc.skip_download(file)
        io = File.open(file, option)
        data = io.read
      else
        begin
          response = @agent.get(@url)
          response.save_as(file)
          response = nil # win
          io = File.open(file, option)
          data = io.read
        rescue Timeout::Error, Errno::ETIMEDOUT
          retrievable? ? retry : raise
        ensure
          io.close if io and !io.closed? # win
          Gtin2atc.download_finished(tempFile)
        end
      end
      return data
    end
  end
  class Downloader
    attr_reader :type
    def initialize(options={}, url=nil)
      @options     = options
      @url         = url
      @retry_times = 3
      HTTPI.log = false # disable httpi warning
      Gtin2atc.log "Downloader from #{@url} for #{self.class}"
      init
    end
    def init
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:16.0) Gecko/20100101 Firefox/16.0'
      @agent.redirect_ok         = true
      @agent.redirection_limit   = 5
      @agent.follow_meta_refresh = true
      if RUBY_PLATFORM =~ /mswin|mingw|bccwin|cygwin/i and
         ENV['SSL_CERT_FILE'].nil?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_file(File.expand_path('../../../tools/cacert.pem', __FILE__))
        @agent.cert_store = cert_store
      end
    end
    protected
    def retrievable?
      if @retry_times > 0
        sleep 5
        @retry_times -= 1
        true
      else
        false
      end
    end
    def read_xml_from_zip(target, zipfile)
      Gtin2atc.log "read_xml_from_zip target is #{target} zip: #{zipfile} #{File.exists?(zipfile)}"
      entry = nil
      Dir.glob(File.join(Util.get_archive, '*')).each { |name| if target.match(name) then entry = name; break end }
      if entry
        dest = "#{Util.get_archive}/#{File.basename(entry)}"
        if File.exists?(dest)
          Gtin2atc.log "read_xml_from_zip return content of #{dest} #{File.size(dest)} bytes "
          return IO.read(dest)
        else
          Gtin2atc.log "read_xml_from_zip could not read #{dest}"
        end
      else
        Gtin2atc.log "read_xml_from_zip could not find #{target.to_s}"
      end
      xml = ''
      if RUBY_PLATFORM =~ /mswin|mingw|bccwin|cygwin/i
        Zip::File.open(zipfile) do |zipFile|
          zipFile.each do |entry|
            if entry.name =~ target
              Gtin2atc.log "read_xml_from_zip reading #{__LINE__}: #{entry.name}"
              io = entry.get_input_stream
              until io.eof?
                bytes = io.read(1024)
                xml << bytes
                bytes = nil
              end
              io.close if io.respond_to?(:close)
              dest = "#{Util.get_archive}/#{File.basename(entry.name)}"
              File.open(dest, 'w+') { |f| f.write xml }
              Gtin2atc.log "read_xml_from_zip saved as #{dest}"
            end
          end
        end
      else
        Zip::File.foreach(zipfile) do |entry|
          if entry.name =~ target
            Gtin2atc.log "read_xml_from_zip #{__LINE__}: reading #{entry.name}"
            dest = "#{Util.get_archive}/#{File.basename(entry.name)}"
            entry.get_input_stream { |io| xml = io.read }
            File.open(dest, 'w+') { |f| f.write xml }
            Gtin2atc.log "read_xml_from_zip saved as #{dest}"
          end
        end
      end
      xml
    end
  end
  class BagXmlDownloader < Downloader
    def init
      super
      @url ||= 'http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip'
    end
    def download
      file = File.join(WorkDir, 'XMLPublications.zip')
      Gtin2atc.log "BagXmlDownloader #{__LINE__}: #{file} from #{@url}"
      if File.exists?(file) and diff_hours = ((Time.now-File.ctime(file)).to_i/3600) and diff_hours < 24
        puts "Skip download of #{file} as only #{diff_hours} hours old"
      else
        FileUtils.rm_f(file, :verbose => true)
        begin
          response = @agent.get(@url)
          response.save_as(file)
          response = nil # win
        rescue Timeout::Error, Errno::ETIMEDOUT
          retrievable? ? retry : raise
        ensure
          Gtin2atc.download_finished(file)
        end
      end
      content = read_xml_from_zip(/Preparations.xml/, File.join(Util.get_archive, File.basename(file)))
      content
    end
  end

  class SwissIndexDownloader < Downloader
    def initialize(options={}, type=:pharma, lang='DE')
      @type = (type == :pharma ? 'Pharma' : 'NonPharma')
      @lang = lang
      url = "https://index.ws.e-mediat.net/Swissindex/#{@type}/ws_#{@type}_V101.asmx?WSDL"
      super(options, url)
    end
    def init
      config = {
        :log_level       => :info,
        :log             => false, # $stdout
        :raise_errors    => true,
        :ssl_version     => :SSLv3,
        :wsdl            => @url
      }
      @client = Savon::Client.new(config)
    end
    def download
      begin
        filename =  "swissindex_#{@type}_#{@lang}.xml"
        file2save = File.join(WorkDir, "swissindex_#{@type}_#{@lang}.xml")
        if File.exists?(file2save) and diff_hours = ((Time.now-File.ctime(file2save)).to_i/3600) and diff_hours < 24
          puts "Skip download of #{file2save} as only #{diff_hours} hours old"
          IO.read(file2save)
        end
        FileUtils.rm_f(file2save, :verbose => false)
        soap = <<XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <lang xmlns="http://swissindex.e-mediat.net/Swissindex#{@type}_out_V101">#{@lang}</lang>
</soap:Body>
</soap:Envelope>
XML
        response = @client.call(:download_all, :xml => soap)
        if response.success?
          if xml = response.to_xml
            response = nil # win
            FileUtils.makedirs(WorkDir)
            File.open(file2save, 'w+') { |file| file.write xml }
          else
            # received broken data or internal error
            raise StandardError
          end
        else
          raise Timeout::Error
        end
      rescue HTTPI::SSLError
        exit # catch me in Cli class
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      end
      puts "Download of #{file2save} finished"
      xml
    end
  end
end