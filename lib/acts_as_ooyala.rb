require 'base64' 
require 'digest/sha2' 
require 'cgi'
require 'yaml'
require 'activesupport'
require 'open-uri'

module LocusFocus # :nodoc
  module Ooyala # :nodoc:
    def self.included(base)
      base.module_eval do
        cattr_accessor :secret_code
        cattr_accessor :partner_code
      end
      
      base.extend ClassMethods
    end
    
    class RecordNotFound < StandardError
      def message
        "Record Not Found"
      end
    end
    
    class RequestExpired < StandardError
      def message
        "Already Expired"
      end
    end
    
    class ThumbnailsNotFound < StandardError
      def message
        "Thumbnails Not Found"
      end
    end
      
    module ClassMethods
      # This method extends an ActiveResource model to use the Ooyala API
      def acts_as_ooyala
        config = YAML.load_file("#{RAILS_ROOT}/config/ooyala.yml")[RAILS_ENV]
        self.site = "http://www.ooyala.com/partner/"
        self.secret_code = config["secret_code"]
        self.partner_code = config["partner_code"]
        self.timeout = 10
        extend LocusFocus::Ooyala::SingletonMethods
        include LocusFocus::Ooyala::InstanceMethods
      end
    end
    
    module SingletonMethods      
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}
        options = keys_as_s(options)
        
        begin
          options.assert_valid_keys('embedCode', 'includeLabels', 'includeDeleted', 'status', 'statistics', 'title')
        rescue ArgumentError => e
          
          # Ooyala allows for some dynamic keys, which we can't count on.
          # Supress the argument errror for those keys.
          raise(ArgumentError, e.message) unless e.message =~ /label\[[0-9]\]/
        end
        
        # Statistics cannot have spaces between the attributes.
        options['statistics'] = options['statistics'].gsub(' ','') if options['statistics']
          
        case scope
          when :all   then find_every(options)
          when :first then find_every(options).first
          when :last  then find_every(options).last
          when :one   then find_one(options)
          else             find_single(scope, options)
        end
      end
      
      def find_paused(scope, options = {})
        find(scope, options.merge({ 'status' => 'paused' }))
      end
      
      def find_live(scope, options = {})
        find(scope, options.merge({ 'status' => 'live' }))
      end
      
      def find_pending(scope, options = {})
        find(scope, options.merge({ 'status' => 'pending' }))
      end
      
      def find_thumbnails(options = {})
        response = send_request('thumbnails', options) 
        raise LocusFocus::Ooyala::ThumbnailsNotFound.new("No Thumbnails Found for #{options['embedCode']}") unless response["thumbnail"]
        record = instantiate_record(response.except('thumbnail'))
        record.attributes['thumbnails'] = response["thumbnail"]
        record
      end
      
      def find_by_embed_code(code, options = {})
        find(:one, options.merge({ 'embedCode' => code }))
      end
           
      private 
      def find_every(options)
        response = send_request('query', options)
        response.is_a?(String) ? [] : instantiate_collection([response["item"]].flatten)
      end
      
      def find_one(options)
        response = send_request('query', options)
        raise LocusFocus::Ooyala::RecordNotFound.new("Record Not found with id #{options['embedCode']}") unless response["item"]
        instantiate_record(response["item"].is_a?(Array) ? response["item"].first : response["item"])
      end
      
      def find_single(scope, options)
        find_by_embed_code(scope, options)
      end

      def send_request(request_type, params) 
        
        # Convert any hash keys that are symbols to strings
        params = keys_as_s(params)
        
        # Add expires if we were lazy before and didn't provide one 
        params['expires'] ||= (10.days.from_now.to_i).to_s 
        string_to_sign = self.secret_code
        url = "#{request_type}?pcode=#{self.partner_code}"
        
        params.keys.sort.each do |key| 
          string_to_sign += "#{key}=#{params[key]}" 
          url += "&#{CGI.escape(key)}=#{CGI.escape(params[key].to_s)}" 
        end 
        
        digest = Digest::SHA256.digest(string_to_sign) 
        signature = Base64::encode64(digest).chomp.gsub(/=+$/, '') 

        url += "&signature=#{CGI.escape(signature)}"
        do_request url
      end
      
      def do_request(url)
        result = http.send(:get, "#{self.site}#{url}")
        response = connection.send(:handle_response, result)
        raise LocusFocus::Ooyala::RequestExpired.new() if response.body == "already expired"
        connection.format.decode(response.body)
      end
      
      def http
        http             = Net::HTTP.new(self.site.host, self.site.port)
        http.use_ssl     = self.site.is_a?(URI::HTTPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl
        http.read_timeout = self.timeout if self.timeout # If timeout is not set, the default Net::HTTP timeout (60s) is used.
        http
      end
      
      def keys_as_s(hash)
        Hash[*hash.collect{|x,y| [x.to_s, y] }.flatten]
      end
    end
    
    module InstanceMethods
      
      def uploaded_at
        attributes['uploadedAt'].to_i
      end
      
      def uploaded_at_as_date
        Time.at(uploaded_at)
      end
      
      def thumbnail
        if attributes.keys.include?('thumbnail')
          attributes['thumbnail']
        else
          nil
        end
      end          
      def thumbnails
        if attributes.keys.include?('thumbnails')
          attributes['thumbnails'].is_a?(Array) ? attributes['thumbnails'] : [attributes['thumbnails']]
        else
          []
        end
      end
    end
  end
end