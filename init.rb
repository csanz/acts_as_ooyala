require 'acts_as_ooyala'
require 'ooyala_helper'

begin            
  ActiveResource::Base.send(:include, LocusFocus::Ooyala)
  ActionView::Base.send(:include, LocusFocus::Ooyala::Helper)
rescue Errno::ENOENT
  STDERR.puts '** [!] ActsAsOoyala installed but could not find an ooyala.yml config file'
end

