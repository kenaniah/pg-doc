require "sinatra/base"

module PG
  module Doc

    # Returns a new web class with the connection already set
    def self.Web connection
      PG::Doc::Web.new do |app|
        app.setup connection
      end
    end

    class Web < Sinatra::Base

      # Sets the database connection to be used
      def setup connection
        @conn = PG.connect connection
        @cache = Hash.new
        @cache[:tables] = @conn.exec(<<~SQL).values.group_by{ |row| row[0] }
          SELECT
            table_schema, table_name
          FROM
            information_schema.tables
          WHERE
            table_schema NOT ILIKE 'pg_%'
            AND table_schema != 'information_schema'
          ORDER BY
            1, 2
        SQL
      end

      set :views, Proc.new { File.join(root, "../../../views") }
      get '/' do
        erb :index
      end

    end
  end
end
