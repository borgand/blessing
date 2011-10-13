require 'blessing/leader'
require 'blessing/runner'

module Blessing
  def self.version
    "Blessing " + File.read(File.join(File.dirname(__FILE__), "..", "VERSION"))
  end
end
