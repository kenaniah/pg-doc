require "sinatra/base"

module PG
  module Doc
    class Web < Sinatra::Base
      get '/' do
        halt 'Hello world!'
      end
    end
  end
end
