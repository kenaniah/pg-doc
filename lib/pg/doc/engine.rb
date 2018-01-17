require "sinatra/base"

module PG
  module Doc

    # Returns an instantiated (and configured) rack app
    def self.new connection, opts = {}
      PG::Doc::Engine.new do |app|
        app.setup connection, opts
      end
    end

    class Engine < Sinatra::Base

      set :public_folder, Proc.new { File.join(root, "../../../static") }
      set :views, Proc.new { File.join(root, "../../../views") }

      get '/' do
        erb :index
      end

      get '/schemas/:schema(.:ext)?' do
        object = @cache.dig :schemas, params["schema"]
        pass unless object
        erb :"objects/schema", locals: {object: object}
      end

      get '/schemas/:schema/:object_type/:name(.:ext)?' do
        object = @cache.dig :schemas, params["schema"], params["object_type"].to_sym, params["name"]
        pass unless object
        erb :"objects/#{params["object_type"].sub(/s$/, "")}", locals: {object: object}
      end

      # Defines helpers
      helpers do
        def render_markdown file
          erb :"includes/markdown", locals: {file: File.join(@path_to_markdowns, file)} if @path_to_markdowns
        end
      end

      # Initializes the internal state for this instance
      def setup connection, opts

        @conn = PG.connect connection
        @path_to_markdowns = opts.fetch(:path_to_markdowns, nil)
        @schema_filter = opts.fetch(:schema_filter, nil) || ->(field) {
          <<~SQL
            #{field} NOT ILIKE 'pg_%'
            AND #{field} != 'information_schema'
          SQL
        }

        @cache = {schemas: {}}

        # Load schemas
        _recordset = @conn.exec <<~SQL
          SELECT
            schema_name
          FROM
            information_schema.schemata
          WHERE
            #{@schema_filter.call :schema_name}
          ORDER BY
            1
        SQL
        _recordset.each_with_object(@cache){ |row, h|
          h[:schemas][row["schema_name"]] = {
            tables: {},
            views: {},
            functions: {}
          }
        }

        # Load tables
        _recordset = @conn.exec <<~SQL
          SELECT
            table_schema,
            table_name,
            obj_description((table_schema || '.' || table_name)::regclass::oid, 'pg_class') as comment
          FROM
            information_schema.tables
          WHERE
            #{@schema_filter.call :table_schema}
          ORDER BY
            1, 2
        SQL
        _recordset.each_with_object(@cache){ |row, h|
          h[:schemas][row["table_schema"]][:tables][row["table_name"]] = {
            columns: [],
            foreign_keys: {},
            comment: row["comment"]
          }
        }

        # Load views
        _recordset = @conn.exec <<~SQL
          SELECT
            table_schema,
            table_name,
            view_definition,
            obj_description((table_schema || '.' || table_name)::regclass::oid, 'pg_class') as comment
          FROM
            information_schema.views
          WHERE
            #{@schema_filter.call :table_schema}
          ORDER BY
            1, 2
        SQL
        _recordset.each_with_object(@cache){ |row, h|
          h[:schemas][row["table_schema"]][:views][row["table_name"]] = {
            view_definition: row["view_definition"],
            columns: [],
            comment: row["comment"]
          }
        }

        # Load columns
        _recordset = @conn.exec <<~SQL
          SELECT
            c.table_schema,
            c.table_name,
            c.column_name,
            c.ordinal_position,
            c.data_type,
            c.is_nullable,
            c.column_default,
            col_description((c.table_schema || '.' || c.table_name)::regclass::oid, c.ordinal_position) as comment,
            t.table_type
          FROM
            information_schema.columns c
            JOIN information_schema.tables t USING (table_catalog, table_schema, table_name)
          WHERE
            #{@schema_filter.call :table_schema}
          ORDER BY
            1, 2, 4
        SQL
        _recordset.each_with_object(@cache){ |row, h|
          type = row.delete("table_type") == "VIEW" ? :views : :tables
          schema = row.delete "table_schema"
          name = row.delete "table_name"
          h[:schemas][schema][type][name][:columns] << row
        }

        # Load functions (note: this currently does not support overloaded functions)
        _recordset = @conn.exec <<~SQL
          SELECT
            routine_schema,
            routine_name,
            routine_definition,
            external_language,
            pg_get_function_identity_arguments((routine_schema || '.' || routine_name)::regproc) as arguments,
            obj_description((routine_schema || '.' || routine_name)::regproc::oid, 'pg_proc') as comment
          FROM
            information_schema.routines
          WHERE
            #{@schema_filter.call :routine_schema}
            AND external_name IS NULL
          ORDER BY
            1, 2
        SQL
        _recordset.each_with_object(@cache){ |row, h|
          h[:schemas][row["routine_schema"]][:functions][row["routine_name"]] = {
            external_language: row["external_language"],
            comment: row["comment"],
            arguments: row["arguments"].split(",").map{ |arg| parse_function_argument arg }
          }
        }

        # Load foreign keys
        _recordset = @conn.exec <<~SQL
          SELECT
            tc.table_schema,
            tc.table_name,
            tc.constraint_name,
            tc.constraint_type,
            kcu.column_name,
            tc.is_deferrable,
            tc.initially_deferred,
            rc.match_option AS match_type,

            rc.update_rule AS on_update,
            rc.delete_rule AS on_delete,
            ccu.table_schema AS references_schema,
            ccu.table_name AS references_table,
            ccu.column_name AS references_field

          FROM
            information_schema.table_constraints tc

          LEFT JOIN information_schema.key_column_usage kcu
            ON tc.constraint_catalog = kcu.constraint_catalog
            AND tc.constraint_schema = kcu.constraint_schema
            AND tc.constraint_name = kcu.constraint_name

          LEFT JOIN information_schema.referential_constraints rc
            ON tc.constraint_catalog = rc.constraint_catalog
            AND tc.constraint_schema = rc.constraint_schema
            AND tc.constraint_name = rc.constraint_name

          LEFT JOIN information_schema.constraint_column_usage ccu
            ON rc.unique_constraint_catalog = ccu.constraint_catalog
            AND rc.unique_constraint_schema = ccu.constraint_schema
            AND rc.unique_constraint_name = ccu.constraint_name

          WHERE
            tc.constraint_type = 'FOREIGN KEY'
          ORDER BY
            1, 2
        SQL
        _recordset.each_with_object(@cache){ |row, h|
          h[:schemas][row["table_schema"]][:tables][row["table_name"]][:foreign_keys][row["column_name"]] = row
        }

      end

      def parse_function_argument arg

        # Determine the argument's mode
        arg = arg.strip
        argmode = case arg
        when /^VARIADIC\b/, /^OUT\b/, /^INOUT\b/, /^IN\b/
          _parts = arg.split(" ")
          _mode = _parts.shift
          arg = _parts.join(" ")
          _mode
        else
          "IN"
        end

        # Determine it's name and type
        if arg.count(" ") > 0
          name, *type = arg.split " "
          type = type.join " "
        else
          name = nil
          type = arg
        end

        {name: name, type: type, mode: argmode}

      end

    end

  end
end
