
desc 'Run local server for development'
task :local do
  require 'yaml'
  command = YAML.load_file('Procfile')['web']
  command.sub!('$PORT', ENV['PORT'] || '3000')
  sh "bin/rerun '#{command}'"
end

desc "Convert bower package to gem. Run with rake convert[name] or convert[name#version]"
task :convert, [:pkg] => :environment do |t, args|
  pkg = args[:pkg]

  if component = Convert.new(Component.new(pkg)).convert!(:io => STDOUT, :debug => true, :force => true)
    system "gem unpack #{component.gem_path}"
  end
end

desc "List all gems"
task :list => :environment do
  index = Index.new
  index.all.sort.each do |g|
    c = Component.new(g)
    vs = index.versions(c).join(", ")
    puts "#{c.name} (#{vs})"
  end
end

desc "Remove gem"
task :remove, [:pkg] => :environment do |t, args|
  pkg = args[:pkg]
  index = Index.new
  fs = FileStore.new
  component = Component.new(pkg)

  components = if component.version
    [component]
  else
    index.versions(component).map do |v|
      Component.new(component.name, v)
    end
  end

  components.each do |c|
    puts "Removing gem #{c.gem_filename}"
    fs.delete(c)
    index.delete(c)
  end

  Reindex.new.perform
end

desc "Update gem"
task :update, [:pkg] => :environment do |t, args|
  Update.new.perform(args[:pkg])
end

desc "Wipeout all data (data dir, redis index, installed gems)"
task :wipeout do
  print "Are you sure?"
  STDIN.gets

  system "rm -rf data"
  system "gem list rails-assets | xargs gem uninstall -ax"
  system "redis-cli KEYS 'rails-assets*' | xargs redis-cli DEL"
end

desc "Rebuild all"
task :rebuild => :environment do
  index = Index.new

  index.all.each do |gem_name|
    pkg = gem_name.sub(GEM_PREFIX, "")
    index.versions(gem_name).each do |version|
      component = Component.new(pkg, version)
      Convert.new(component).convert!(:force => true)
    end
  end
end

desc "Reindex all gems"
task :reindex => :environment do
  Reindex.new.perform(:force)
end
