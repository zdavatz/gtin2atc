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
  CSV_NAME = 'gtin2atc.csv'
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
      FileUtils.cp(use4test, latest, :verbose => false)
    }
  end
  after(:each) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  after(:all) do
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
      check_csv(CSV_NAME)
    end

    it 'should produce more log output' do
      @res = buildr_capture(:stdout){ cli.run }
      @res.match(/swissindex_xml_extractor/).should_not == nil
      @res.match(/SwissIndex: Extracted/).should_not == nil
    end
  end

  context 'when 7680147690482 7680353660163 is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('7680147690482 7680353660163'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce a csv with a two GTIN' do
      @res = buildr_capture(:stdout){ cli.run(["7680147690482", "7680353660163"]) }
      check_csv(CSV_NAME)
      inhalt = IO.readlines(CSV_NAME)
      inhalt.size.should eq 2+1 # one header lines + two items
      /7680147690482/.match(inhalt[1]).should_not == nil
      /7680353660163/.match(inhalt[1]).should == nil
      /7680147690482/.match(inhalt[2]).should == nil
      /7680353660163/.match(inhalt[2]).should_not == nil
    end
  end

  def check_csv(filename)
    File.exists?(filename).should eq true
    inhalt = IO.readlines(filename)
    /^gtin,ATC/.match(inhalt.first).should_not == nil
    /^\d{13},\w{4}/.match(inhalt[1]).should_not == nil
  end

  context 'when --compare is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('--compare'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce three correct csv' do
      @res = buildr_capture(:stdout){ cli.run }
      check_csv('gtin2atc_bag.csv')
      check_csv('gtin2atc_swissindex.csv')
      check_csv('gtin2atc_packungen.csv')
    end

    it 'should produce a good logging output' do
      @res = buildr_capture(:stdout){ cli.run }
      [ /Found infos/,
        /Fetched from/,
        /Matching/,
        /Not in BAG/,
        /Not in Packungen/,
        /ATC-Codes diff/,
      ].each {
        |pattern|
        unless pattern.match(@res)
          puts "Looking for #{pattern} in #{@res}"
        end
        pattern.match(@res).should_not == nil
      }
    end

  end

end
