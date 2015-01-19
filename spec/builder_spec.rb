# encoding: utf-8

require 'spec_helper'
require "rexml/document"
include REXML

module Kernel
  def buildr_capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval "$#{stream} = #{stream.upcase}"
    end
    result
  end
end

describe Gtin2atc::Builder do
  include ServerMockHelper
  before(:each) do
    @savedDir = Dir.pwd
    FileUtils.makedirs Gtin2atc::WorkDir
    Dir.chdir Gtin2atc::WorkDir
    Gtin2atc::Util.set_archive_dir(Gtin2atc::WorkDir)
    cleanup_directories_before_run
    setup_server_mocks
    { 'XMLPublications' => '.zip',
      'swissindex_Pharma_DE' => '.xml',
      'swissmedic_package' => '.xlsx',
      }.each {
      |name, extension|
      use4test = File.expand_path(File.join( __FILE__, '../data/'+name + extension))
      latest, dated = Gtin2atc::Util.get_latest_and_dated_name(name, extension)
      FileUtils.cp(use4test, latest, :verbose => true)
    }
  end
  after(:each) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  after(:all) do
    puts "Dir pwe #{Dir.pwd} Gtin2atc::WorkDir #{Gtin2atc::WorkDir}"
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end

  context 'when --log is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('--log'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce a correct csv' do
      @res = buildr_capture(:stdout){ cli.run }
      # @res = cli.run
      puts "@res ist #{@res.inspect}"
      ['gtin2atc_bag.csv',
       'gtin2atc_swissindex.csv',
       'gtin2atc_packungen.csv',
       ].each {
        |file|
          # puts "File #{File.expand_path(file)}"
          File.exists?(file).should eq true
          inhalt = IO.read(file)
          # puts inhalt
      }
    end
  end

end
