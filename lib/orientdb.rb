raise "Rubyhaze only runs on JRuby. Sorry!" unless (RUBY_PLATFORM =~ /java/)

$: << File.dirname(__FILE__)
$: << File.expand_path('../../jars/', __FILE__)

require 'java'
require "orientdb-client-0.9.25"
require 'ruby-debug'

module OrientDB
  def environment
    @environment || 'development'
  end
  module_function :environment
  
  def environment=(env)
    @environment = env
  end
  module_function :environment=

  def self.const_missing(missing)
    puts "[#{name}:const_missing] #{missing}"
    super
  end
  
  def load_database_setting(reload=false)
    if @database and !reload
      @database
    else
      @database_setting = if File.exists?(File.join(ORIENT_APP_ROOT, 'config', "orientdb_#{self::environment}.yml"))
        YAML::load( File.open(File.join(ORIENT_APP_ROOT, 'config', "orientdb_#{self::environment}.yml")) )
      end
    end
  end
  module_function :load_database_setting
  
  def database_location(setting)
    if setting
      "#{setting['place']}:#{setting['domain']}/#{setting['database']}"
    end
  end
  module_function :database_location
  
  def connect_to_database(overrides={})
    setting = (self::load_database_setting ? self::load_database_setting : {})
    
    overrides.keys.each do |key|
      setting[key.to_s] = overrides[key]
    end
    
    #puts "setting #{setting}"
    
    OrientDB::DocumentDatabase.connect(self::database_location(setting), setting['user'], setting['password'])
  end
  module_function :connect_to_database

  #
  # Can't enable transactions yet, because there are problems with .commit using up the heap
  #
  def transaction(overrides={}, &body)
    has_error = nil
    database = self::connect_to_database(overrides)
    
    #puts "begin transaction"
    #database.begin
    begin
      response = yield database
      #debugger
      #puts "commit transaction"
      #database.commit
    rescue
      has_error = true
      #puts "rollback transaction"
      #database.rollback
    end
    
    #puts "close connection"
    database.close
    
    if has_error
      raise
    else
      response
    end
  end
  module_function :transaction
  
  def query(overrides={}, &body)
    has_error = nil
    database = self::connect_to_database(overrides)
    
    begin
      response = yield database
    rescue
      has_error = true
    end
    
    database.close
    
    if has_error
      raise
    else
      response
    end
  end
  module_function :query

end

require 'orientdb/ext'
require 'orientdb/rid'
require 'orientdb/constants'
require 'orientdb/version'
require 'orientdb/user'
require 'orientdb/property'
require 'orientdb/schema'
require 'orientdb/storage'
require 'orientdb/database'
require 'orientdb/record'
require 'orientdb/document'
require 'orientdb/sql'
require 'orientdb/oclass'

