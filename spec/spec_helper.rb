require 'simplecov'
require 'codeclimate-test-reporter'
require 'digest'
require 'chunky_png'
require 'digest/md5'
SimpleCov.add_filter 'vendor'
SimpleCov.add_filter 'examples'
SimpleCov.formatter = CodeClimate::TestReporter::Formatter
SimpleCov.start CodeClimate::TestReporter.configuration.profile

require 'gnuplotrb'

include ChunkyPNG::Color
include GnuplotRB
$RSPEC_TEST = true

def same_images?(*imgs)
  imgs.map { |img| ChunkyPNG::Image.from_file(img).pixels }.inject(&:==)
end

def awesome?
  # sure!
  true
end
