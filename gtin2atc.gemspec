# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gtin2atc/version'

Gem::Specification.new do |spec|
  spec.name        = "gtin2atc"
  spec.version     = Gtin2atc::VERSION
  spec.author      = "Niklaus Giger, Zeno R.R. Davatz"
  spec.email       = "ngiger@ywesee.com, zdavatz@ywesee.com"
  spec.description = "gtin2atc file with gtin, atc_code, pharmanr from input file with gtin"
  spec.summary     = "gtin2atc creates csv files with GTIN and ATC."
  spec.homepage    = "https://github.com/zdavatz/gtin2atc"
  spec.license       = "GPL-v2"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # We fix the version of the spec to newer versions only in the third position
  # hoping that these version fix only security/severe bugs
  # Consulted the Gemfile.lock to get 
  spec.add_dependency 'rubyzip', '~> 1.1.3'
#  spec.add_dependency 'archive-tar-minitar', '~> 0.5.2'
  spec.add_dependency 'mechanize', '~> 2.5.1'
  spec.add_dependency 'nokogiri', '~> 1.5.10'
  spec.add_dependency 'savon'#, '~> 2.4.0'
#  spec.add_dependency 'spreadsheet', '~> 1.0.0'
  spec.add_dependency 'rubyXL'
  spec.add_dependency 'sax-machine' #,  '~> 0.1.0'
  
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rdoc"
end

