# require "fileutils"
# require "shellwords"

def add_gems
  gem "foreman", "~> 0.85.0"
  gem "webpacker", "~> 3.5", ">= 3.5.5"
end

def set_application_name
  environment "config.application_name = Rails.application.class.parent_name"
end

def install_webpacker
  rails_command "webpacker:install"
end

def change_webpacker_config_file
  gsub_file "config/webpacker.yml",

    /source_path: app\/javascript/,
    "source_path: frontend"
end

def move_webpacker_javascript_directory_to_root
  run "mv app/javascript frontend"

  change_webpacker_config_file
end

def setup_images_for_webpack
file "frontend/packs/images.js", <<-CODE
import "../images"
CODE

file "frontend/images/index.js", <<-CODE
function importAll(r) {
  return r.keys().map(r);
}

const images = importAll(require.context("./", false, /\.(png|jpe?g|svg)$/));
CODE
end

def setup_tailwindcss
  run "yarn add tailwindcss"
  run "mkdir -p frontend/stylesheets"
  run "./node_modules/.bin/tailwind init frontend/stylesheets/tailwind.js"

  inject_into_file "./.postcssrc.yml", "\n  tailwindcss: './frontend/stylesheets/tailwind.js'", after: "postcss-cssnext: {}"

file "frontend/stylesheets/application.css", <<-CODE
/* All your Css goes here */
CODE
end

def setup_stimulus
  run "bundle exec rails webpacker:install:stimulus"
end

def remove_default_assets
  run "rm -rf app/assets/"
end

def add_foreman
file "Procfile", <<-CODE
web: rails server
webpack: ./bin/webpack-dev-server --watch --colors --progress
CODE
end

def setup_application_pack_file
  run "rm frontend/packs/application.js"

file "frontend/packs/application.js", <<-CODE
/* eslint no-console:0 */

import { Application } from "stimulus"
import { definitionsFromContext } from "stimulus/webpack-helpers"

const application = Application.start()
const context = require.context("controllers", true, /.js$/)
application.load(definitionsFromContext(context))

import "../stylesheets/application.css"
CODE
end

def replace_application_include_tags
  gsub_file "app/views/layouts/application.html.erb", /stylesheet_link_tag/, "stylesheet_pack_tag"
  gsub_file "app/views/layouts/application.html.erb", /javascript_include_tag/, "javascript_pack_tag"
end

def stop_spring
  run "spring stop"
end

add_gems

after_bundle do
  set_application_name
  stop_spring
  install_webpacker
  move_webpacker_javascript_directory_to_root
  setup_images_for_webpack
  setup_tailwindcss
  setup_stimulus
  add_foreman
  remove_default_assets
  setup_application_pack_file
  replace_application_include_tags

  rails_command "db:create"
  rails_command "db:migrate"

  git :init
  git add: "."
  git commit: %Q{ -m "Initial commit" }
end
