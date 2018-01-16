require "bundler"
Bundler.require

require "pg/doc"
run PG::Doc::Engine ENV['DATABASE_URL']
