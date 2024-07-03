$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require "mesh_bbs"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "tmp/test.db"
)

task :server do
  _, port = ARGV

  unless port
    puts "Usage: start.rb <port>"
    exit
  end

  MeshBBS.start!(port:)

  loop do
    sleep 1
  end
end

task :console do
  require "irb"
  require "irb/completion"

  _, port = ARGV

  unless port
    puts "Usage: start.rb <port>"
    exit
  end

  MeshBBS.start!(port:)

  ARGV.clear
  IRB.start
end

namespace :migrate do
  task :up do
    require_relative "db/migrate/0001_create_messages"
    require_relative "db/migrate/0002_create_bulletins"

    CreateMessages.migrate(:up)
    CreateBulletins.migrate(:up)
  end

  task :down do
    require_relative "db/migrate/0001_create_messages"
    require_relative "db/migrate/0002_create_bulletins"

    CreateMessages.migrate(:down)
    CreateBulletins.migrate(:down)
  end
end
