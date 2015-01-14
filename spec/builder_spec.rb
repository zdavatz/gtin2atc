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
    cleanup_directories_before_run
#    setup_server_mocks
    Dir.chdir Gtin2atc::WorkDir
  end
  after(:each) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end

  context 'when --log is given' do
    let(:cli) do
      options = Gtin2atc::Options.new
      options.parser.parse!('--log'.split(' '))
      # require 'pry'; binding.pry
      latest, dated = Gtin2atc::Util.get_latest_and_dated_name('Packungen', '.xlsx')
      FileUtils.makedirs(File.dirname(latest))
      FileUtils.makedirs(File.dirname(dated))
      use4test = File.expand_path(File.join( __FILE__, '../data/swissmedic_package.xlsx'))
      FileUtils.cp(use4test, latest, :verbose => true)
      FileUtils.cp(use4test, dated,  :verbose => true)
      Gtin2atc::Builder.new(options.opts)
    end

    it 'should contain the correct prices' do
#      res = buildr_capture(:stdout){ cli.run }
      res =cli.run
      @article_xml = File.expand_path(File.join(Gtin2atc::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      product_filename = File.expand_path(File.join(Gtin2atc::WorkDir, 'oddb_product.xml'))
      File.exists?(product_filename).should eq true
      doc = REXML::Document.new File.new(@article_xml)
      unless /1\.8\.7/.match(RUBY_VERSION)
        price_zur_rose = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='ZURROSE']/PRICE").first.text
        price_zur_rose.should eq '12.9'
        price_zur_rose_pub = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='ZURROSEPUB']/PRICE").first.text
        price_zur_rose_pub.should eq '15.45'
      end
    end
  end

end
