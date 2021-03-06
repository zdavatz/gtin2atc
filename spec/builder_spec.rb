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
  FERRO = '7680316440115;B03AA07;20244;FERRO-GRADUMET Depottabl;;;30;Ferrum(ii);105.0;mg;;;0,2 g O Fe2+'
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

  def check_csv(filename)
    File.exists?(filename).should eq true
    inhalt = IO.readlines(filename)
    /^\d{13};\w{4}/.should match inhalt[1]
    # Packungsgrösse, Dosierung, DDD, Route of Administration
    /^gtin;ATC;pharmacode;description;exfactory_price;public_price;selling units;name;qty;unit;ddd:qty;ddd:unit;ddd:full_text/.should match inhalt.first
    IO.read(filename).index(FERRO).should_not == nil
  end

  context 'when 20273 41803 (Pharmacodes) is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('20273 41803'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce a correct csv' do
       # @res = buildr_capture(:stdout){ cli.run }
      cli.run
      check_csv(CSV_NAME)
    end
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
      @res.match(/swissindex: Extracted/).should_not == nil
    end
  end



  context 'when 20273 41803 (Pharmacodes) is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('20273 41803'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce a csv with a two GTIN' do
      @res = buildr_capture(:stdout){ cli.run(["20273", "41803"]) }
      check_csv(CSV_NAME)
      inhalt = IO.readlines(CSV_NAME)
      inhalt.size.should eq 2+1 # one header lines + two items
      inhalt[1].chomp.should eq '7680147690482;N07BC02;41803;KETALGIN Inj Lös 10 mg/ml;;;;;;;25.0;mg;O,P'
      inhalt[2].chomp.should eq '7680353660163;B03AE10;20273;KENDURAL Depottabl;;;;;;;;;'
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
      /7680353660163;B03AE10;20273;KENDURAL Depottabl/.match(inhalt[2]).should_not == nil
    end
  end

  def check_csv(filename)
    File.exists?(filename).should eq true
    inhalt = IO.readlines(filename)
    /^gtin;ATC/.match(inhalt.first).should_not == nil
    /^\d{13};\w{4}/.match(inhalt[1]).should_not == nil
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
      check_csv('gtin2atc_swissmedic.csv')
      check_csv('gtin2atc_swissindex.csv')
    end

    it 'should produce a good logging output' do
      @res = buildr_capture(:stdout){ cli.run }
      [ /Found infos/,
        /Fetched from/,
        /Matching/,
        /not in bag/,
        /not in swissmedic/,
        /not in swissindex/,
        /atc are different/,
      ].each {
        |pattern|
        unless pattern.match(@res)
          puts "Looking for #{pattern} in #{@res}"
        end
        pattern.match(@res).should_not == nil
      }
    end

  end

  context 'when --compare --full is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('--compare --full'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce many report files' do
      @res = buildr_capture(:stdout){ cli.run }
      Dir.glob(Gtin2atc::WorkDir + '/compare_all_*.txt').size.should == 5
      Dir.glob(Gtin2atc::WorkDir + '/pharmacode_gtin_not_found.txt').size.should == 1
      Dir.glob(Gtin2atc::WorkDir + '/compare_swissmedic_to_swisssindex_*.txt').size.should == 5
      Dir.glob(Gtin2atc::WorkDir + '/compare_bag_to_swissindex_*.txt').size.should == 5
      Dir.glob(Gtin2atc::WorkDir + '/compare_bag_to_swissmedic_*.txt').size.should == 5
    end

  end

  context 'when outputfile is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('7680316440115 tst.csv'.split(' '))
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should produce a correct tst.csv' do
      tst_name = 'tst.csv'
      buildr_capture(:stdout){ cli.run(["7680316440115"], tst_name) }
      check_csv(tst_name)
    end
  end

  context 'when producing csv' do
    let(:cli) do
      options = Gtin2atc::Options.new
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should contain dose for FERRO-GRADUMET Depottab' do
      oddb_calc_xml = File.expand_path(File.join( __FILE__, '../data/oddb_calc.xml'))
      FileUtils.cp(oddb_calc_xml, Gtin2atc::WorkDir, :verbose => false)
      # buildr_capture(:stdout){ cli.run() }
      cli.run()
      check_csv(CSV_NAME)
      inhalt = IO.read(CSV_NAME)
      puts inhalt
      inhalt.index(FERRO).should_not == nil
      inhalt.index('7680291520390;N02BE01;31532;BEN-U-RON Supp 250 mg Kind;;;;;;;;;"3 g O,P,R; 0,75 g O Kinder DDD; 0,375 g R Säuglings DDD; 0,75 g R Kinder DDD"').should_not == nil
      inhalt.index('7680147700112;N07BC02;41826;KETALGIN Tabl 5 mg;;;;;;;25.0;mg;O,P').should_not == nil
    end
  end

end
