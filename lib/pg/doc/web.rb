require "sinatra/base"

module PG
  module Doc
    class Web < Sinatra::Base
      set :views, Proc.new { File.join(root, "../../../views") }
      get '/' do
        erb :index
      end
    end
  end
end
