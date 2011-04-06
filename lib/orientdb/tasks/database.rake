require "erb"
require "orientdb"
require "yaml"

#####
# put in the Rakefile:
# APPLICATION_ROOT = File.expand_path('..', __FILE__)
#####

if !defined?(DATABASES_ROOT)
  DATABASES_ROOT = File.join(ORIENT_APP_ROOT, 'orientdb')
end
if !defined?(MIGRATION_ROOT)
  MIGRATION_ROOT = File.join(DATABASES_ROOT, 'migrations')
end


desc "Primitive database rake task file for migrating the OrientDB databases"
namespace :orientdb do

  desc "create and setup the database. On creation you need to supply it the OrientDB root password, then it will create the database and assign the admin, writer, and reader users the password you put in your config/database.yml"
  task :create => :environment do
    begin
      OrientDB::connect_to_database.close
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
      # need root password to create database
      if OrientDB::load_database_setting.nil?
        STDOUT.puts "The database does not exist."
        STDOUT.puts "Please enter a name for the database:"
        @database_name = STDIN.gets.strip
        STDOUT.puts "Is the database remote? (y/n) Tip: Remote access allows for more connections."
        @place = (STDIN.gets.strip[0] == "y" ? "remote" : "local")
        STDOUT.puts "What is the domain of the database? (localhost if on your computer)"
        @domain = STDIN.gets.strip
        STDOUT.puts "What user will the program use to access the database? (admin, writer, and reader are standard)"
        @user = STDIN.gets.strip
        STDOUT.puts "What would you like to set the passwords of all the users to? (you can change specific ones later)"
        @password = STDIN.gets.strip
        
        config_root = File.join(ORIENT_APP_ROOT, 'config')
        if !File.directory?(config_root)
          Dir.mkdir(config_root)
        end
        
        File.open(File.join(config_root, "orientdb_#{OrientDB::environment}.yml"), "w+") do |file|
          file.write(ERB.new(<<-EOF
user: "<%= @user %>"
password: "<%= @password %>"
place: "<%= @place %>"
domain: "<%= @domain %>"
database: "<%= @database_name %>_<%= OrientDB::environment %>"

EOF
).result)
        end
        
        OrientDB::load_database_setting(true)
        
        STDOUT.puts "Your config/orientdb_#{OrientDB::environment}.yml file that contains your database access settings has been created."
      end
      STDOUT.puts "Please enter the OrientDB server's root password to create the database. It is located in [OrientDB_ROOT]/config/orientdb-server-config.xml"
      root_password = STDIN.gets.strip
      
      # create database
      com.orientechnologies.orient.client.remote.OServerAdmin.new(OrientDB::database_location(OrientDB::load_database_setting)).connect('root', root_password).createDatabase('local').close()
      STDOUT.puts "Your database has been created"
      
      # update admin's password to the one listed in the config file
      OrientDB::transaction(:password => 'admin') do |database|
        database.all_in_class("OUser").each do |user|
          user.password = OrientDB::load_database_setting['password']
          user.save
        end
      end
      STDOUT.puts "Your user passwords for admin, writer, and reader have been updated"
      #OrientDB::DocumentDatabase.create("remote:localhost/sponus_production")
      
      # ensure that SchemaMigration class has been created
      OrientDB::transaction do |database|
        if !database.get_class("SchemaMigration")
          database.create_class("SchemaMigration", "migration" => :string)
          STDOUT.puts "Your SchemaMigration table has been created."
        end
      end
      
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
    end
    
    if !File.directory?(MIGRATION_ROOT)
      # ensure folder databases exists and databases/migrations exists
      if !File.directory?(DATABASES_ROOT)
        Dir.mkdir(DATABASES_ROOT)
        STDOUT.puts "Your orientdb folder has been created"
      end
      
      Dir.mkdir(MIGRATION_ROOT)
      STDOUT.puts "Your orientd/migrations folder has been created"
    end
  end
  
  desc "migrates any database migrations that have not been migrated yet. Currently not functional."
  task :migrate => :environment do
    # load all files in database/migrations
    
    # load schema_migrations table
    migrated = OrientDB::query do |database|
      database.all_in_class("SchemaMigration").inject({}) {|hash, migration| hash[migration.migration] = migration; hash}
    end
    
    to_migrate = Dir.glob("#{MIGRATION_ROOT}/*.rb").inject([]) do |list, file| 
      migration = file.split('/').last.split('.')[0]
      if !migrated.has_key?(migration)
        list << migration
        require file
      end
      list
    end
    
    to_migrate.sort!
    to_migrate.each do |migration|
      OrientDB::transaction do |database|
        parts = migration.partition("_")
        klass_name = "#{parts[2]}_#{parts[0]}"
        
        Object.const_get(klass_name).up(database)
        OrientDB::Document.create database, "SchemaMigration", :migration => migration
        
        STDOUT.puts "#{migration} has been migrated"
      end
    end
  end
  
  desc "rolls back one database migration.  Should be expanded to include the number of steps. Currently not functional."
  task :rollback => :environment do
    OrientDB::transaction do |database|
      
    end
  end
  
  desc "generate a new database migration"
  task :generate_migration do
    # take timestamp and create a basic migration file in database/migrations
    numeric_time = Time.now.strftime("%Y%m%d%H%M%S")
    name = ENV['name'].capitalize
    @numeric_name = "#{numeric_time}_#{name}"
    @class_name = "#{name}_#{numeric_time}"
    
    File.open(File.join(MIGRATION_ROOT, "#{@numeric_name}.rb"), "w+") do |file|
      file.write(ERB.new(<<-EOF
class <%= @class_name %>
  def self::up(database)
    
  end
  
  def self::down(database)
    
  end
end
EOF
).result())
    end
  end
end
