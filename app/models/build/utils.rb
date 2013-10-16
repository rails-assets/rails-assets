require "open3"

module Build
  module Utils
    def sh(cwd, *cmd)
      cmd = cmd.join(" ")
      Rails.logger.debug "Running shell command '#{cmd}' in #{cwd}"

      output = ""
      status = Open3.popen3(cmd, :chdir => cwd) do |stdin, stdout, stderr, thr|
        stdout.each do |line|
          output << line
          Rails.logger.info(line.chomp)
        end

        stderr.each do |line|
          output << line
          Rails.logger.warn(line.chomp)
        end

        thr.value
      end

      if status.success?
        output
      else
        raise BuildError.new("Command '#{cmd}' failed with exit code #{status.to_i}", :log => output)
      end
    end

    def fix_version_string(version)
      version = version.to_s

      if version =~ /^v(.+)/
        version = $1.strip
      end

      if version =~ />=(.+)<(.+)/
        if $1.strip[0] != $2.strip[0]
          version = "~> #{$1.strip.match(/\d+\.\d+/)}"
        else
          version = "~> #{$1.strip}"
        end
      end

      if version =~ />=(.+)/
        version = ">= #{$1.strip}"
      end

      if version.strip == "latest" || version.strip == "master"
        nil
      elsif version.match(/^[^\/]+\/[^\/]+$/) 
        nil
      elsif version.match(/^(http|git|ssh)/)
        if version.split('/').last =~ /^v?([\w\.-]+)$/
          fix_version_string($1.strip)
        else
          nil
        end
      else
        version.gsub!('-', '.')
        version.gsub!(/~\s?(\d)/, '~> \1')

        if version.match('.x')
          version.gsub!('.x', '.0')
          version = "~> #{version}"
        end

        version
      end
    end

    def fix_gem_name(gem_name, version)
      version = version.to_s

      if version.match(/^[^\/]+\/[^\/]+$/) 
        version.sub('/', '--')
      elsif version =~ /github\.com\/([^\/]+\/[^\/]+)/
        $1
      else
        gem_name
      end
    end
  end
end
