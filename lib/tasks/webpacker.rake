WEBPACKER_APP_TEMPLATE_PATH = File.expand_path('../install/template.rb', File.dirname(__FILE__))

namespace :webpacker do
  desc "Compile javascript packs using webpack for production with digests"
  task :compile do
    dist_path = Rails.application.config.x.webpacker[:packs_dist_path]
    digests_path = Rails.application.config.x.webpacker[:digests_path]
    webpack_digests = JSON.parse(`WEBPACK_DIST_PATH=#{dist_path} WEBPACK_ENV=production ./bin/webpack --json`)['assetsByChunkName']

    js_webpack_digests_json = webpack_digests.each_with_object({}) do |(chunk, file), h|
      h[chunk] = files.is_a?(Array) ? files.first : file
    end.to_json

    packs_path = Rails.root.join('public', dist_path)
    packs_digests_path = digests_path || Rails.root.join(packs_path, 'digests.json')

    FileUtils.mkdir_p(packs_path)
    File.open(packs_digests_path, 'w+') { |file| file.write js_webpack_digests_json }

    puts "Compiled digests for all packs in #{packs_digests_path}: "
    puts js_webpack_digests_json
  end

  desc "Install webpacker in this application"
  task :install do
    exec "./bin/rails app:template LOCATION=#{WEBPACKER_APP_TEMPLATE_PATH}"
  end

  namespace :install do
    desc "Install everything needed for react"
    task :react do
      config_path = Rails.root.join('config/webpack/shared.js')
      config = File.read(config_path)

      if config =~ /presets:\s*\[\s*\[\s*'latest'/
        puts "Replacing loader presets to include react in #{config_path}"
        config.gsub!(/presets:(\s*\[)(\s*)\[(\s)*'latest'/, "presets:\\1\\2'react',\\2[\\3'latest'")
      else
        puts "Couldn't automatically update loader presets in #{config_path}. Please set presets: [ 'react', [ 'latest', { 'es2015': { 'modules': false } } ] ]."
      end

      if config.include?("test: /\\.js(.erb)?$/")
        puts "Replacing loader test to include react in #{config_path}"
        config.gsub!("test: /\\.js(.erb)?$/", "test: /\\.jsx?(.erb)?$/")
      else
        puts "Couldn't automatically update loader test in #{config_path}. Please set test: /\.jsx?(.erb)?$/."
      end

      File.write config_path, config

      puts "Copying react example to app/javascript/packs/hello_react.js"
      FileUtils.copy File.expand_path('../install/react/hello_react.js', File.dirname(__FILE__)),
        Rails.root.join('app/javascript/packs/hello_react.js')

      exec './bin/yarn add --dev babel-preset-react && ./bin/yarn add react react-dom'
    end
  end
end
