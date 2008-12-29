require 'net/http'
require 'webrick/httputils'

class EstraierAdmin
  RequestFailed = Class.new(StandardError)
  CREATE_NODE_ACTION = 8
  DELETE_NODE_ACTION = 9
  DEFAULT_CONFIG = {
    :host=> "localhost",
    :port=>1978,
    :user=>"admin",
    :password=>"admin"
  }.freeze

  # requires host 
  def initialize(config={})
    @config = DEFAULT_CONFIG.dup
    config.each { |k, v| @config[k.to_sym] = v }
  end

  def create_node(name, label = nil)
    label ||= name
    request_or_raise(:name=>name, :action=>CREATE_NODE_ACTION, :label=>label)
    return true
  end

  def delete_node(name)
    request_or_raise(:name=>name, :action=>DELETE_NODE_ACTION, :sure=>1)
    return true
  end

  private
  def request_or_raise(params, path="/master_ui")
    req = Net::HTTP::Post.new(path)
    req.basic_auth(@config[:user], @config[:password])
    res = Net::HTTP.start(@config[:host], @config[:port]) do |http|
            http.request(req, build_body(params))
          end
    raise if res.code.to_i >= 400 
    return true
  end

  def build_body(params={})
    params.map{|k,v| "#{k}=#{WEBrick::HTTPUtils.escape_form(v.to_s)}" }.join('&')
  end
end

