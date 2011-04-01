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
  
  desc "load the database settings to access the database."
  task :settings => :environment do
    if CURRENT_ODB_SETTING
      @location = CURRENT_ODB_SETTING['database']
      @user = CURRENT_ODB_SETTING['user']
      @password = CURRENT_ODB_SETTING['password']
    else
      # throw error!
    end
  end

  desc "create and setup the database. On creation you need to supply it the OrientDB root password, then it will create the database and assign the admin, writer, and reader users the password you put in your config/database.yml"
  task :create => :settings do
    begin
      # ensure that database has been created
      begin
        database = OrientDB::DocumentDatabase.connect(@location, @user, @password)
      rescue com.orientechnologies.orient.core.exception.ODatabaseException
        # need root password to create database
        if CURRENT_ODB_SETTING.nil?
          STDOUT.puts "The database does not exist."
          STDOUT.puts "Please enter a name for the database (_development, _production, will be added for you):"
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
          
          @database_stub = "#{@place}:#{@domain}/#{@database_name}"
          File.open(File.join(config_root, 'orientdb.yml'), "w+") do |file|
            file.write(ERB.new(<<-EOF
production:
  user: "<%= @user %>"
  password: "<%= @password %>"
  database: "<%= @database_stub %>_production"
  
development:
  user: "<%= @user %>"
  password: "<%= @password %>"
  database: "<%= @database_stub %>_development"

EOF
).result)
          end
          
          @location = "#{@database_stub}_#{ENV['env']}"
          
          STDOUT.puts "Your config/orientdb.yml file that contains your database access settings has been created."
        end
        STDOUT.puts "Please enter the OrientDB server's root password to create the database. It is located in [OrientDB_ROOT]/config/orientdb-server-config.xml"
        root_password = STDIN.gets.strip
        

        # create database
        com.orientechnologies.orient.client.remote.OServerAdmin.new(@location).connect('root', root_password).createDatabase('local').close()
        STDOUT.puts "Your database has been created"
        
        # update admin's password to the one listed in the config file
        database = OrientDB::DocumentDatabase.connect(@location, 'admin', 'admin')
        database.all_in_class("OUser").each do |user|
          user.password = @password
          user.save
        end
        STDOUT.puts "Your user passwords for admin, writer, and reader have been updated"
        #OrientDB::DocumentDatabase.create("remote:localhost/sponus_production")
      end
      
      # ensure that SchemaMigration class has been created
      if !database.get_class("SchemaMigration")
        database.create_class("SchemaMigration", "migration" => :string)
      end
      STDOUT.puts "Your SchemaMigration table has been created."
      
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
    end
    
    if database
      database.close
    end
    # ensure folder databases exists and databases/migrations exists
    if !File.directory?(DATABASES_ROOT)
      Dir.mkdir(DATABASES_ROOT)
      STDOUT.puts "Your orientd folder has been created"
    end
    
    if !File.directory?(MIGRATION_ROOT)
      Dir.mkdir(MIGRATION_ROOT)
      STDOUT.puts "Your orientd/migrations folder has been created"
    end
  end
  
  desc "migrates any database migrations that have not been migrated yet. Currently not functional."
  task :migrate => :settings do
    # load all files in database/migrations
    
    # load schema_migrations table
    begin
      database = OrientDB::DocumentDatabase.connect(@location, @user, @password)
      
      migrated = database.all_in_class("SchemaMigration").inject({}) {|hash, migration| hash[migration.migration] = migration; hash}
      
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
        parts = migration.partition("_")
        klass_name = "#{parts[2]}_#{parts[0]}"
        
        Object.const_get(klass_name).up(database)
        OrientDB::Document.create database, "SchemaMigration", :migration => migration
        
        STDOUT.puts "#{migration} has been migrated"
      end
    rescue com.orientechnologies.orient.core.exception.ODatabaseException

    end
    
    if database
      database.close
    end
  end
  
  desc "rolls back one database migration.  Should be expanded to include the number of steps. Currently not functional."
  task :rollback => :settings do
    begin
      database = OrientDB::DocumentDatabase.connect(@location, @user, @password)
    rescue com.orientechnologies.orient.core.exception.ODatabaseException
      if database
        database.close
      end
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
