require "bundler"
Bundler.require

require "pg/doc"
run PG::Doc.new ENV['DATABASE_URL'], path_to_markdowns: ENV['PATH_TO_MARKDOWNS']
