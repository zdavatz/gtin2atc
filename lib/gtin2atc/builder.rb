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
      Util.set_logging(opts[:log])
      @do_compare = opts[:compare]
      Util.debug_msg "Builder: opts are #{opts} @do_compare is #{@do_compare}"
      @data_swissmedic = {}
      @data_bag = {}
      @data_swissindex = {}
      @bag_entries_without_gtin = 0
    end
    def calc_checksum(str)
      str = str.strip
      sum = 0
      val =   str.split(//u)
      12.times do |idx|
        fct = ((idx%2)*2)+1
        sum += fct*val[idx].to_i
      end
      ((10-(sum%10))%10).to_s
    end
    def swissmedic_xls_extractor
      @swissmedic = SwissmedicDownloader.new
      filename = @swissmedic.download
      Util.debug_msg "swissmedic_xls_extractor xml is #{filename}"
      data = {}
      @sheet = RubyXL::Parser.parse(File.expand_path(filename)).worksheets[0]
      i_5,i_3   = 0,10 # :swissmedic_numbers
      atc       = 5    # :atc_code
      @sheet.each_with_index do |row, i|
        next if (i <= 1)
        next unless row[i_5] and row[i_3]
        no8 = sprintf('%05d',row[i_5].value.to_i) + sprintf('%03d',row[i_3].value.to_i)
        unless no8.empty?
          next if no8.to_i == 0
          item = {}
          ean_base12 = "7680#{no8}"
          gtin = (ean_base12.ljust(12, '0') + calc_checksum(ean_base12)).to_i
          item = {}
          item[:gtin]            = gtin
          # item[:pharmacode]      = (phar = pac.PHAR)   ? phar: ''
          item[:atc_code]        =  row[atc] ? row[atc].value.to_s : ''
          data[gtin] = item
        end
      end
      Util.debug_msg "swissmedic_xls_extractor extracted #{data.size} items"
      data
    end
    def swissindex_xml_extractor
      @swissindex = SwissIndexDownloader.new
      xml = @swissindex.download
      Util.debug_msg "swissindex_xml_extractor xml is #{xml.size} bytes long"
      data = {}
      result = PharmaEntry.parse(xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      items = result.PHARMA.ITEM
      items.each do |pac|
        item = {}
        gtin = pac.GTIN ? pac.GTIN.to_i : nil
        next unless item[:gtin].to_i
        item[:gtin]            = gtin
        item[:pharmacode]      = (phar = pac.PHAR)   ? phar: ''
        item[:atc_code]        = (code = pac.ATC)    ? code.to_s : ''
        data[gtin] = item
      end
      Util.debug_msg "swissindex_xml_extractor extracted #{data.size} items"
      data
    end
    def bag_xml_extractor
      data = {}
      @bag = BagXmlDownloader.new
      xml = @bag.download
      Util.debug_msg "bag_xml_extractor xml is #{xml.size} bytes long"

      result = PreparationsEntry.parse(xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      @bag_entries_without_gtin = 0
      result.Preparations.Preparation.each do |seq|
        item = {}
        item[:atc_code]     = (atcc = seq.AtcCode)       ? atcc : ''
        seq.Packs.Pack.each do |pac|
          gtin = pac.GTIN
          if gtin
            gtin = gtin.to_i
            item[:gtin] = gtin
            data[gtin] = item
            Util.debug_msg "run_bag_extractor add #{item}" if $VERBOSE
          else
            @bag_entries_without_gtin += 1
            Util.debug_msg "run_bag_extractor skip phar #{seq.NameDe}: #{seq.DescriptionDe} without gtin."
          end
        end
      end
      Util.debug_msg "bag_xml_extractor extracted #{data.size} items. Skipped #{@bag_entries_without_gtin} entries without gtin"
      data
    end
    def run(gtins_to_parse=[])
      Util.debug_msg("run #{gtins_to_parse}")
      Util.debug_msg("@use_swissindex true")
      @data_swissindex = swissindex_xml_extractor
      output_name =  File.join(Util.get_archive, @do_compare ? 'gtin2atc_swissindex.csv' : 'gtin2atc.csv')
      CSV.open(output_name,'w+') do |csvfile|
        csvfile << ["gtin", "ATC", 'pharmacode']
        @data_swissindex.sort.each do |gtin, item|
          csvfile << [gtin, item[:atc_code], item[:pharmacode]] if  @do_compare or gtins_to_parse.size == 0 or gtins_to_parse.index(gtin.to_s)
        end
      end
      msg = "SwissIndex: Extracted #{gtins_to_parse.size} of #{@data_swissindex.size} items into #{output_name} for #{gtins_to_parse}"
      Util.debug_msg(msg)
      if @do_compare
        @data_bag = bag_xml_extractor
        output_name =  File.join(Util.get_archive, 'gtin2atc_bag.csv')
        CSV.open(output_name,'w+') do |csvfile|
          csvfile << ["gtin", "ATC"]
          @data_bag.sort.each do |gtin, item|
            csvfile << [gtin, item[:atc_code]]
          end
        end
        Util.debug_msg "BAG: Extracted #{gtins_to_parse.size} of #{@data_bag.size} items into #{output_name} for #{gtins_to_parse}"
      end
      if @do_compare
        @data_swissmedic = swissmedic_xls_extractor
        output_name =  File.join(Util.get_archive, 'gtin2atc_packungen.csv')
        CSV.open(output_name,'w+') do |csvfile|
          csvfile << ["gtin", "ATC"]
          @data_swissmedic.sort.each do |gtin, item|
            csvfile << [gtin, item[:atc_code], item[:pharmacode]]
          end
        end
        Util.debug_msg "SwissMedic: Extracted #{@data_swissmedic.size} items into #{output_name}"
      end
      compare(gtins_to_parse) if @do_compare
    end

    def compare(gtins_to_parse=nil)
      all_gtin = @data_bag.merge(@data_swissindex).merge(@data_swissmedic).sort
      matching = 0
      not_in_bag = 0
      not_in_packungen = 0
      not_in_swissindex = 0
      different_atc = 0
      # require 'pry'; binding.pry
      all_gtin.each{
        |gtin, item|
        if @data_bag[gtin] and @data_swissindex[gtin] and @data_bag[gtin][1] == @data_swissindex[gtin][1]
          matching += 1
          next
        end
        unless @data_swissmedic[gtin]
          Util.debug_msg "#{gtin}: Not in Packungen #{item}"
          not_in_packungen += 1
          next
        end
        unless @data_swissindex[gtin]
          Util.debug_msg "#{gtin}: Not in SwissIndex #{item}"
          not_in_swissindex += 1
          next
        end
        unless @data_bag[gtin]
          Util.debug_msg "#{gtin}: Not in BAG #{item}"
          not_in_bag += 1
          next
        end
        different_atc += 1
        Util.debug_msg "#{gtin}: ATC code differs BAG #{@data_bag[gtin][:atc_code]} swissindex  #{@data_swissindex[gtin][:atc_code]}"
      }
      Util.info  "Resumen:
  Found infos about #{all_gtin.size}  entries
  BAG #{@data_bag.size} entries. #{@bag_entries_without_gtin.size} entries had not GTIN field.. Fetched from #{@bag.origin}
  SwissIndex #{@data_swissindex.size} entries. Fetched from #{@swissindex.origin}
  SwissMedic #{@data_swissmedic.size} entries. Fetched from #{@swissmedic.origin}
  Matching #{matching} items.
  Not in BAG #{not_in_bag}
  Not in SwissIndex #{not_in_swissindex}
  Not in Packungen #{not_in_packungen}
  ATC-Codes differ #{different_atc}
"
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
      Util.debug_msg "target #{target} #{latest_name}"
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
