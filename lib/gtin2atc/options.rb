# encoding: utf-8
require 'optparse'

module Gtin2atc
  
  class Options
    attr_reader :parser, :opts
    def Options.default_opts
      {
        :log          => false,
      }
    end
    def Options.help
  <<EOS
#$0 ver.#{Gtin2atc::VERSION}
Usage:
  gtin2atc [option]
    produced files are found under data
    --log                log important actions
    -h,   --help         Show this help message.
EOS
    end
    def initialize
      @parser = OptionParser.new
      @opts   = Options.default_opts
      @parser.on('--log')                                  {|v| @opts[:log] = true }
      @parser.on_tail('-h', '--help') { puts Options.help; exit }
    end
  end
end
