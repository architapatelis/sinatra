# Nancy will be the Rack application we are creating.
require "rack"

module Nancy
  class Base
    def initialize
      @routes = {}
    end

    attr_reader :routes

    # The & is used to convert the block into a Proc.
    # The block is code or string we write between do/end when we call the get method
    def get(path, &handler)
      route("GET", path, &handler)
    end

    def post(path, &handler)
      route("POST", path, &handler)
    end

    def put(path, &handler)
      route("PUT", path, &handler)
    end

    def patch(path, &handler)
      route("PATCH", path, &handler)
    end

    def delete(path, &handler)
      route("DELETE", path, &handler)
    end

    def head(path, &handler)
      route("HEAD", path, &handler)
    end

    # for a more detailed explanation visit http://gabebw.com/blog/2015/08/10/advanced-rack
    # parameter env is the Rack environment. It has a lot of information about the request, like what HTTP verb was used, the request path, the host, and more.
    # Rack uses handlers to run Rack applications. Each Ruby webserver has its own handler, for example WEBrick handler (WEBrick is installed by default with Ruby.)
    # example: verb is 'GET' and path requested_path is '/hello'
    def call(env)
      @request = Rack::Request.new(env)
      verb = @request.request_method
      requested_path = @request.path_info
      handler = @routes.fetch(verb, {}).fetch(requested_path, nil)

      if handler
        # give handler access to all of the methods, on the instance of Nancy::Base
        result = instance_eval(&handler)
        # If a handler returns a string, assume that it is a successful response, and so we construct a successful Rack response
        # otherwise, we return the result of the block as-is
        # [status, header, body]
        if result.class == String
          [200, {}, [result]]
        else
          result
        end
      else
        [404, {}, ["Oops! No route for #{verb} #{requested_path}"]]
      end
    end

    # In most POST and PUT requests, we’ll want to access the request body.
    # Since the handler has access to every instance method on Nancy::Base,
    # we need to add an instance method named 'request'
    # that has access to our @request instance variable that we set in the call method
    attr_reader :request

    private
    #The routes hash, is composed of 'verb' hash. If the 'verb' hash is nil or false then set it to an empty hash.
    # Each verb hash will have a key of path and value of handler.
    def route(verb, path, &handler)
      @routes[verb] ||= {}
      @routes[verb][path] = handler
    end

    #The Rack::Request class that wraps the env has a method called params
    # It contains information about all parameters provided to the method - GET, POST etc.
    def params
      @request.params
    end
  end

  # instance of Nancy::Base that we can reference
  Application = Base.new

  # Nancy::Delegator will delegate get, patch, post, etc to Nancy::Application
  # so that calling 'get' in context with Nancy::Delegator will behave exactly like calling Nancy::Application.get.
  module Delegator
    def self.delegate(*methods, to:)
      Array(methods).each do |method_name|
        define_method(method_name) do |*args, &block|
          to.send(method_name, *args, &block)
        end

        private method_name
      end
    end

    delegate :get, :patch, :put, :post, :delete, :head, to: Application
  end
end
include Nancy::Delegator


#*******************************************************************************
#*
# TESTING
# call the get method which passes the GET verb, path and handler to the route method. This will add a new route
# verb = GET, path = "/hello" between do/end is a block(become &handler Proc)
get "/hello" do
  "Hello World!!!!"
end

# test post method by running: curl --data "Hi there!!" localhost:9292/hello
post "/hello" do
  request.body.read
end

#*******************************************************************************
#*

# this is the handler for Nancy::Base
# Rack handlers take a Rack app and actually run them.
Rack::Handler::WEBrick.run Nancy::Application, Port: 9292
