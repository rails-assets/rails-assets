require 'rubygems/indexer'

class Reindex
  include Sidekiq::Worker

  sidekiq_options queue: 'reindex', unique: true, retry: 0

  def perform(force = false)
    Build::Locking.with_lock(:index) do
      if force || Version.pending_index.count > 0
        Version.transaction do
          Version.pending_index.
            update_all(build_status: 'indexed')

          generate_indexes
        end
      else
        Rails.logger.info("nothing to reindex, skipping")
      end
    end

    # Clear cache for components.json api endpoint
    Rails.cache.delete('components_json')

    true
  end

  def generate_indexes
    write_index File.join(Figaro.env.data_dir, 'specs.4.8') do
      Version.
        builded.
        joins(:component).
        order('components.name, versions.position').
        where(prerelease: false).
        pluck('components.name', 'string')
    end

    write_index File.join(Figaro.env.data_dir, 'latest_specs.4.8') do
      Version.
        builded.
        from("(#{
          Version.select('distinct on (component_id) *').
          where(prerelease: false).
          order('component_id, position desc').to_sql
        }) as versions").
        joins(:component).order('components.name').
        pluck('components.name', 'string').to_a
    end

    write_index File.join(Figaro.env.data_dir, 'prerelease_specs.4.8') do
      Version.
        builded.
        joins(:component).
        order('components.name, versions.position').
        where(prerelease: true).
        pluck('components.name', 'string')
    end
  end

  # For now deprecated, as gemspecs are generated
  # dynamically in Build::Converter.persist!
  def generate_gemspecs
    gemspecs_dir = File.join(
      Figaro.env.data_dir, 'quick', 'Marshal.4.8'
    )

    FileUtils.mkdir_p(gemspecs_dir)

    gems = Dir[File.join(
      Figaro.env.data_dir, 'gems', '*.gem'
    )].map { |s| s.split('/').last[0..-5] }

    gemspecs = Dir[File.join(
      gemspecs_dir, '*.gemspec.rz'
    )].map { |s| s.split('/').last[0..-12] }

    missing = gems - gemspecs

    missing.map(&method(:reindex_spec))
  end

  def reindex_spec(name)
    puts "Generating gemspec.rz for #{name}..."

    gem_path = File.join(
      Figaro.env.data_dir, 'gems', name + '.gem'
    )

    gemspec_path = File.join(
      Figaro.env.data_dir,
      'quick', 'Marshal.4.8', name + '.gemspec.rz'
    )

    gemspec = gemspec_rz(read_spec(gem_path))

    FileUtils.mkdir_p(File.dirname(gemspec_path))

    open gemspec_path, 'wb' do |io| io.write(gemspec) end
  end

  def read_spec(path)
    Build::GemPackage.open File.open(path), "r", nil do |pkg|
      return pkg.metadata
    end
  end

  def gemspec_rz(spec)
    spec.abbreviate
    spec.sanitize
    Gem.deflate(Marshal.dump(spec))
  end

  def write_index(path)
    data = yield

    data.each do |d|
      d[0] = "#{GEM_PREFIX}#{d[0]}"
      d << 'ruby'
    end

    minimized = minimize_specs(data)
    stringified = stringify(minimized)
    gunzipped = gunzip(stringified)

    open path, 'wb' do |io| io.write(stringified) end
    open "#{path}.gz", 'wb' do |io| io.write(gunzipped) end

    true
  end

  def minimize_specs(data)
    names     = Hash.new { |h,k| h[k] = k }
    versions  = Hash.new { |h,k| h[k] = Gem::Version.new(k) }
    platforms = Hash.new { |h,k| h[k] = k }

    data.each do |row|
      row[0] = names[row[0]]
      row[1] = versions[row[1].strip]
      row[2] = platforms[row[2]]
    end

    data
  end

  def stringify(value)
    Marshal.dump(value)
  end

  def gunzip(value)
    final = StringIO.new
    gzip = Zlib::GzipWriter.new(final)
    gzip.write(value)
    gzip.close

    final.string
  end

  def self.indexer
    @indexer ||=
      begin
        indexer = Gem::Indexer.new(Figaro.env.data_dir,
                                   :build_legacy => false)
        def indexer.say(message) end
        indexer
      end
  end
end
