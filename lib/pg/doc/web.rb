require "sinatra/base"

module PG
  module Doc

    # Returns an instantiated (and configured) rack app
    def self.Web connection, opts = {}
      PG::Doc::Web.new do |app|
        app.setup connection, opts
      end
    end

    class Web < Sinatra::Base

      set :public_folder, Proc.new { File.join(root, "../../../static") }
      set :views, Proc.new { File.join(root, "../../../views") }

      get '/' do
        erb :index
      end

      # Initializes the internal state for this instance
      def setup connection, opts

        @conn = PG.connect connection
        @schema_filter = opts.fetch(:schema_filter, nil) || ->(field) {
          <<~SQL
            #{field} NOT ILIKE 'pg_%'
            AND #{field} != 'information_schema'
          SQL
        }

        @cache = Hash.new
        @cache[:schemas] = @conn.exec(<<~SQL).values
          SELECT
            schema_name
          FROM
            information_schema.schemata
          WHERE
            #{@schema_filter.call :schema_name}
          ORDER BY
            1
        SQL
        @cache[:tables] = @conn.exec(<<~SQL).values.group_by{ |row| row[0] }
          SELECT
            table_schema, table_name
          FROM
            information_schema.tables
          WHERE
            #{@schema_filter.call :table_schema}
          ORDER BY
            1, 2
        SQL
        @cache[:views] = @conn.exec(<<~SQL).values.group_by{ |row| row[0] }
          SELECT
            table_schema, table_name, view_definition
          FROM
            information_schema.views
          WHERE
            #{@schema_filter.call :table_schema}
          ORDER BY
            1, 2
        SQL
        @cache[:functions] = @conn.exec(<<~SQL).map.group_by{ |row| row["routine_schema"] }
          SELECT
            routine_schema, routine_name, routine_definition, external_language
          FROM
            information_schema.routines
          WHERE
            #{@schema_filter.call :routine_schema}
            AND external_name IS NULL
          ORDER BY
            1, 2
        SQL
      end

    end
  end
end
