require 'csv'
require 'rubyXL'
require "gtin2atc/options"
require "gtin2atc/downloader"
require "gtin2atc/xml_definitions"
require 'mechanize'

module Gtin2atc
  class Builder
    Strip_For_Sax_Machine = '<?xml version="1.0" encoding="utf-8"?>'+"\n"
    def initialize(opts)
      puts "Builder: opts are #{opts}"
    end
    def swissindex_xml_extractor
      xml = SwissIndexDownloader.new.download
      Util.debug_msg "bag_xml_extractor xml is #{xml.size} bytes long"
      data = []
      result = PharmaEntry.parse(xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      items = result.PHARMA.ITEM
      items.each do |pac|
        item = {}
        item[:gtin]            = (gtin = pac.GTIN)   ? gtin: ''
        item[:pharmacode]      = (phar = pac.PHAR)   ? phar: ''
        item[:atc_code]        = (code = pac.ATC)    ? code.to_s : ''
        data << item
        Util.debug_msg "swissindex_xml_extractor  #{item}"
      end
      data
    end
    def bag_xml_extractor
      data = []
      xml = BagXmlDownloader.new.download
      Util.debug_msg "bag_xml_extractor xml is #{xml.size} bytes long"

      result = PreparationsEntry.parse(xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      result.Preparations.Preparation.each do |seq|
        item = {}
        item[:atc_code]     = (atcc = seq.AtcCode)       ? atcc : ''
        seq.Packs.Pack.each do |pac|
          gtin = pac.GTIN
          if gtin
            item[:gtin] = gtin
            data << item.clone
            Util.debug_msg "run_bag_extractor add #{item}" if $VERBOSE
          else
            Util.debug_msg "run_bag_extractor skip phar #{seq.NameDe}: #{seq.DescriptionDe} without gtin"
          end
        end
      end
      data
    end
    def run(gtins_to_parse=nil)
      # require 'pry'; binding.pry
      data_bag = bag_xml_extractor
      output_name =  File.join(Util.get_archive, 'gtin2atc_bag.csv')
      CSV.open(output_name,'w+') do |csvfile|
        csvfile << ["gtin", "ATC"]
        data_bag.sort{|x,y| x[:gtin] <=> y[:gtin]}.each do |row|
          csvfile << [row[:gtin], row[:atc_code]]
        end
      end
      puts "Extracted #{data_bag.size} items into #{output_name}"
      data_swissindex = swissindex_xml_extractor
      output_name =  File.join(Util.get_archive, 'gtin2atc_swissindex.csv')
      CSV.open(output_name,'w+') do |csvfile|
        csvfile << ["gtin", "ATC", 'pharmacode']
        data_swissindex.sort{|x,y| x[:gtin] <=> y[:gtin]}.each do |row|
          csvfile << [row[:gtin], row[:atc_code], row[:pharmacode]]
        end
      end
      puts "Extracted #{data_swissindex.size} items into #{output_name}"
      compare(gtins_to_parse)
    end

    def compare(gtins_to_parse=nil)
      data_bag        = CSV.read('gtin2atc_bag.csv')
      hash_bag = {};  data_bag.each{ |x| hash_bag[x[0]] =x }

      data_swissindex = CSV.read('gtin2atc_swissindex.csv')
      hash_swissindex = {};  data_swissindex.each{ |x| hash_swissindex[x[0]] =x }
      puts "Got #{data_bag.size} BAG  items and #{data_swissindex.size} Swissindex items"
      all_gtin = (data_bag.collect{ |x| x[0] }+ data_swissindex.collect{ |x| x[0] }).uniq.sort
      matching = 0
      only_in_bag = 0
      only_in_swissindex = 0
      different_atc = 0
      check_gtins = gtins_to_parse ? gtins_to_parse : all_gtin
      check_gtins.each{
        |gtin|
        if hash_bag[gtin] and hash_swissindex[gtin] and hash_bag[gtin][1] == hash_swissindex[gtin][1]
          matching += 1
          next
        end
        unless hash_swissindex[gtin]
          puts "Only in BAG #{hash_bag[gtin]}"
          only_in_bag += 1
          next
        end
        unless hash_bag[gtin]
          puts "Only in SwissIndex #{hash_swissindex[gtin]}"
          only_in_swissindex += 1
          next
        end
        different_atc += 1
        puts "ATC code for #{gtin} differs BAG #{hash_bag[gtin][1]} swissindex  #{hash_swissindex[gtin][1]}"
      }
      puts "Compared #{all_gtin.size} entries from BAG and SwissIndex. Matching #{matching} only_in_bag #{only_in_bag} only_in_swissindex #{only_in_swissindex} different_atc #{different_atc}"
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
        return latest_name
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
end
