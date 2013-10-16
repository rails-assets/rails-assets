module Build

  class Paths < Array

    def initialize(paths = nil)
      super((paths || []).flat_map do |path|
        path ? [Path.new(path)] : []
      end.uniq)
    end

    def self.from(directory)
      new(Dir[File.join(directory, '**', '*')]).select(:file?)
    end

    def select(*args, &block)
      brock = proc { |e| e.send(*args) }
      args.size > 0 ? Paths.new(super(&brock)) : super(&block)
    end

    def select!(*args, &block)
      brock = proc { |e| e.send(*args) }
      args.size > 0 ? Paths.new(super(&brock)) : super(&block)
    end

    def reject(*args, &block)
      brock = proc { |e| e.send(*args) }
      args.size > 0 ? Paths.new(super(&brock)) : super(&block)
    end

    def map(*args, &block)
      brock = proc { |e| e.send(*args) }
      args.size > 0 ? Paths.new(super(&brock)) : super(&block)
    end

    def +(other)
      Paths.new(super(other))
    end

    def common_prefix
      return nil if self.size == 0

      splitted_files = self.map { |f| f.to_s.split('/') }
      min_size = splitted_files.map { |e| e.size }.min

      path = splitted_files.
        map { |dirs| dirs.take(min_size) }.
        transpose.
        take_while { |dirs| dirs.uniq.size == 1 }.
        map(&:first).join('/')

      Path.new(path).extname.present? ?
        Path.new(File.dirname(path)) : Path.new(path)
    end

    def find_main_asset(type, gem_name)
      Path.extension_classes[type].map do |ext|
        self.find do |path|
          path.extension?([ext]) && path.basename.to_s.split('.').first == gem_name
        end
      end.compact.first
    end
  end
end
