# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'heaven'
set :repo_url, 'git@github.com:UniversalAvenue/heaven.git'

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/home/heaven/heaven'

# Default value for :scm is :git
# set :scm, :git
set :branch, (ENV['CAP_BRANCH'] || 'master')

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system', 'public/uploads')
set :linked_files, fetch(:linked_files, []).push('.rbenv-vars')

# Default value for keep_releases is 5
# set :keep_releases, 5

# set :rbenv_type, :user
# set :rbenv_ruby, '2.2.2'
# set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
# set :rbenv_map_bins, %w{rake gem bundle ruby rails}
set :default_env, {
  PATH: '$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH',
  RBENV_ROOT: '~/.rbenv',
  RBENV_VERSION: '2.2.2'
}

set :unicorn_config_path, -> { File.join(current_path, 'config', 'unicorn.rb') }

# resque
set :resque_environment_task, true
set :resque_log_file, 'log/resque.log'

namespace :deploy do
  # after :restart, :clear_cache do
  #   on roles(:web), in: :groups, limit: 3, wait: 10 do
  #     # Here we can do anything such as:
  #     within release_path do
  #       execute :rake, 'cache:clear'
  #     end
  #   end
  # end
  after :publishing, :restart do
    invoke 'unicorn:restart'
  end
end
after 'deploy:restart', 'resque:restart'
