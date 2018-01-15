require "bundler"
Bundler.require

require "pg/doc"
run PG::Doc::Web ENV['DATABASE_URL']
