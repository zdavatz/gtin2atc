require "gtin2atc/version"
require "gtin2atc/util"

module Gtin2atc
  WorkDir       = Dir.pwd
  def self.log(msg)
    Util.debug_msg(msg)
  end
end
