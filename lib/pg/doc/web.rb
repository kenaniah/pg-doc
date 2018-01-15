require "sinatra/base"

module PG
  module Doc

    # Returns a new web class with the connection already set
    def self.Web connection
      PG::Doc::Web.new do |app|
        app.set_connection connection
      end
    end

    class Web < Sinatra::Base

      # Sets the database connection to be used
      def set_connection connection
        @conn = PG.connect connection
      end

      set :views, Proc.new { File.join(root, "../../../views") }
      get '/' do
        erb :index
      end

    end
  end
end
