# encoding: utf-8
require 'optparse'

module Gtin2atc
  
  class Options
    attr_reader :parser, :opts
    def Options.default_opts
      {
        :log          => false,
        :compare      => false,
        :full         => false,
      }
    end
    def Options.help
  <<EOS
#$0 ver.#{Gtin2atc::VERSION}
Usage:
  gtin2atc [--compare] [--log] [file_with_gtin or gtin or pharmacode] [gtin..]
    If file_with_gtin is given only the GTIN (or pharamacode) (one per line) is outputted.
    If no file or gtin is given, alle GTIN will be processed.
    --log               log important actions

    --compare           download an compare GTIN/ATC_code from BAG, SwissIndex and RefData
                        For each GTIN we will output a message if it can be only found in the
                        * BAG http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip
                        * SwissIndex e-mediat: http://swissindex.e-mediat.net/SwissindexPharma_out_V101
                        * or if the ATC_Code does not not match
    -- full             if --compare and --full given produce 15 detailed report files
    -h,   --help         Show this help message.
EOS
    end
    def initialize
      @parser = OptionParser.new
      @opts   = Options.default_opts
      @parser.on('--log')             {|v| @opts[:log] = true }
      @parser.on('--compare')         {|v| @opts[:compare] = true }
      @parser.on('--full')            {|v| @opts[:full] = true }
      @parser.on_tail('-h', '--help') { puts Options.help; exit }
    end
  end
end
