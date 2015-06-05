# config/unicorn.rb
# paths
app_path = '/home/heaven/heaven'
working_directory "#{app_path}/current"
pid "#{app_path}/current/tmp/pids/unicorn.pid"

# workers
worker_processes Integer(ENV['WEB_CONCURRENCY'] || 3)

timeout 15

# preload
preload_app true

# listen
listen "#{app_path}/shared/tmp/sockets/unicorn.sock", backlog: 64

# logging
stderr_path 'log/unicorn.stderr.log'
stdout_path 'log/unicorn.stdout.log'

# use correct Gemfile on restarts
before_exec do |_server|
  ENV['BUNDLE_GEMFILE'] = "#{app_path}/current/Gemfile"
end

before_fork do |server, _worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
  end
end

after_fork do |_server, _worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end
end
