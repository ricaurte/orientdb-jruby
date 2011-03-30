raise "Rubyhaze only runs on JRuby. Sorry!" unless (RUBY_PLATFORM =~ /java/)

$: << File.dirname(__FILE__)
$: << File.expand_path('../../jars/', __FILE__)

require 'java'
require "orientdb-client-0.9.25"

module OrientDB

  def self.const_missing(missing)
    puts "[#{name}:const_missing] #{missing}"
    super
  end
  
  def self::load_all_settings
    if File.exists?(File.join(ORIENT_APP_ROOT, 'config', 'orientdb.yml'))
      YAML::load( File.open(File.join(ORIENT_APP_ROOT, 'config', 'orientdb.yml')) )
    end
  end
  
  def self::load_database_setting(environment)
    settings = self::load_all_settings
    
    if settings
      settings[environment]
    end
  end
  
  def self::connect_to_database(environment)
    OrientDB::DocumentDatabase.connect(environment['database'], environment['user'], environment['password'])
  end

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

