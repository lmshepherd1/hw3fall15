require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    if @from == @to
      self.errors.add(:from, 'cannot be the same as To')
    end
  end

  def initialize(api_key='')
    @api_key = api_key
    @from = 'Kevin Bacon'
    @to = 'Kevin Bacon'
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      # your code here
      raise NetworkError
    end
    # your code here: create the OracleOfBacon::Response object
    @response = Response.new(xml)
  end

  def make_uri_from_arguments
    @uri = "http://oracleofbacon.org/cgi-bin/xml?p=" + @api_key + "&a=" + CGI.escape(@to) + "&b=" + CGI.escape(@from);
  end
      
  class Response
    attr_accessor :type, :data
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      # error
      if ! @doc.xpath('/error').empty?
        parse_error_response
      # spellcheck 
      elsif ! @doc.xpath('//spellcheck').empty?
        parse_spellcheck_response
      elsif ! @doc.xpath('//movie').empty? and ! @doc.xpath('//actor').empty? and @doc.xpath('//actor').length - @doc.xpath('//movie').length === 1
        parse_graph_response
      else
        parse_unknown_response        
      end
    end
    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end
    def parse_spellcheck_response
      @type = :spellcheck
      @data = []
      @doc.xpath('//match').each do |val|
        @data.push(val.text)
      end
      # @data = @doc.xpath('//match')
    end
    def parse_graph_response
      @type = :graph
      @actors = []
      @movies = []
      @doc.xpath('//actor').each do |val|
        @actors.push(val.text)
      end
      @doc.xpath('//movie').each do |val|
        @movies.push(val.text)
      end
      @data = @actors.zip(@movies).flatten.compact
    end
    def parse_unknown_response
      @type = :unknown
      @data = 'unknown response'
    end
  end
end

