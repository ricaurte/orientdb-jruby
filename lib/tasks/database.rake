require "erb"
require "orientdb"
require "yaml"

#####
# put in the Rakefile:
# APPLICATION_ROOT = File.expand_path('..', __FILE__)
#####

if !defined?(DATABASES_ROOT)
  DATABASES_ROOT = File.join(APPLICATION_ROOT, 'db')
end
if !defined?(MIGRATION_ROOT)
  MIGRATION_ROOT = File.join(DATABASES_ROOT, 'migrate')
end


desc "Primitive database rake task file for migrating the OrientDB databases"
namespace :db do
  
  task :settings do
    settings = YAML::load( File.open( File.join(APPLICATION_ROOT, 'config', 'database.yml') ) )
    
    environment_setting = case ENV['RACK_ENV']
    when "production"
      settings['production']
    when "testing"
      settings['testing']
    else
      settings['development']
    end
    
    @location = environment_setting['database']
    @user = environment_setting['user']
    @password = environment_setting['password']
  end

  task :create => :settings do
    begin
      # ensure that database has been created
      begin
        database = OrientDB::DocumentDatabase.connect(@location, @user, @password)
      rescue com.orientechnologies.orient.core.exception.ODatabaseException
        # need root password to create database
        input = ''
        STDOUT.puts "The database #{@location} does not exist. Please enter the root password to create the database. It is located in [OrientDB_ROOT]/config/orientdb-server-config.xml"
        input = STDIN.gets.strip
        
        # create database
        com.orientechnologies.orient.client.remote.OServerAdmin.new(@location).connect('root', input).createDatabase('local').close()
        
        # update admin's password to the one listed in the config file
        database = OrientDB::DocumentDatabase.connect(@location, 'admin', 'admin')
        database.all_in_class("OUser").each do |user|
          user.password = @password
          user.save
        end

        #OrientDB::DocumentDatabase.create("remote:localhost/sponus_production")
      end
      
      # ensure that schema_migrations table has been created
      if !database.get_class("SchemaMigrations")
        oclass = OrientDB::OClass.create(database, "SchemaMigrations")
        oclass.add("migration", :string)
      end
      
      database.close
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
      database.close
    end
    # ensure folder databases exists and databases/migrations exists
    if !File.directory?(DATABASES_ROOT)
      Dir.mkdir(DATABASES_ROOT)
    end
    
    if !File.directory?(MIGRATION_ROOT)
      Dir.mkdir(MIGRATION_ROOT)
    end
  end
  
  task :migrate => :create do
    # load all files in database/migrations
    
    # load schema_migrations table
    migrated = nil
    begin
      database = OrientDB::DocumentDatabase.connect(@location, @user, @password)
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
      if database
        database.close
      end
    end
    # find files not migrated and migrate them in order
    
  end
  
  task :rollback do
    begin
      database = OrientDB::DocumentDatabase.connect(@location, @user, @password)
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
      if database
        database.close
      end
    end
  end
  
  task :generate_migration do
    # take timestamp and create a basic migration file in database/migrations
    numeric_time = Time.now.strftime("%Y%m%d%H%M%S")
    name = ENV['name']
    @numeric_name = "#{numeric_time}_#{name}"
    
    File.open(File.join(MIGRATION_ROOT, "#{@numeric_name}.rb"), "w+") do |file|
      file.write(ERB.new(<<-EOF
class <%= @numeric_name %>
  def self::up
    
  end
  
  def self::down
    
  end
end
EOF
).result())
    end
  end
end
