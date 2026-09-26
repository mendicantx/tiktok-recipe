lock "~> 3.19"

set :application, "tiktok-recipe"
set :repo_url,    "git@github.com:mendicantx/tiktok-recipe.git"
set :branch,      "main"

set :deploy_to, "/data/www/tiktok-recipe"

# Keep 5 releases on the server
set :keep_releases, 5

# Files and directories to symlink from shared/ into each release.
# storage/ holds the SQLite database and Active Storage cover photos.
append :linked_files, "config/master.key"
append :linked_dirs,  "log", "storage", "tmp/pids", "tmp/cache", "tmp/sockets", "public/assets"

# Passenger restart: touching this file signals Passenger to reload the app
namespace :deploy do
  desc "Restart Passenger"
  task :restart do
    on roles(:app) do
      execute :touch, release_path.join("tmp/restart.txt")
    end
  end
  after :publishing, :restart
end
