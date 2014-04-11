require "open3"

module Build
  module Utils extend self

    # Returns The Hash result if command succeeded.
    # Raises The BowerError if command failed.
    def bower(path, *command)
      command = "#{BOWER_BIN} #{command.join(' ')} --json --quiet"
      command += " --config.tmp=#{Figaro.env.bower_tmp}" if Figaro.env.bower_tmp.present?
      command += " --config.storage.packages=#{Figaro.env.bower_cache}" if Figaro.env.bower_cache.present?
      command += " --config.interactive=false"
      JSON.parse(Utils.sh(path, command))
    rescue ShellError => e
      raise BowerError.from_shell_error(e)
    end

    # Returns The String stdout if command succeeded.
    # Raises The ShellError if command failed.
    def sh(cwd, *cmd)
      cmd = cmd.join(" ")

      Rails.logger.debug "cd #{cwd} && #{cmd}"

      output, error, status =
        Open3.capture3(cmd, :chdir => cwd)

      Rails.logger.debug("#{cmd}\n#{output}") if output.present?
      Rails.logger.warn("#{cmd}\n#{error}") if error.present? && !status.success?

      raise ShellError.new(error, cwd, cmd) unless status.success?

      output
    end

    def fix_version_string(version)
      version = version.to_s.dup

      sem_version = semversion_fix(version)
      return sem_version unless sem_version.nil?

      if version.include?('||')
        raise BuildError.new(
          "Rubygems does not support || in version string '#{version}'"
        )
      end

      # Remove any unnecessary spaces
      version = version.split(' ').join(' ')

      specifiers = ['>', '<', '>=', '<=', '~', '~>', '=', '!=', '^']

      specifiers.each do |specifier|
        version = version.gsub(/#{Regexp.escape(specifier)}\s/) { specifier }
      end

      if version.include?(' ')
        return version.chomp.split(' ').map do |v|
          Utils.fix_version_string(v)
        end.join(', ')
      end

      if version.include?('#')
        return Utils.fix_version_string(version.split('#').last)
      end

      version = version.gsub(/^([^\d]*)v/) { $1 }
      version = version.gsub('.*', '.x')

      version = if ['latest', 'master', '*'].include?(version)
        ">= 0"
      elsif version.match(/^[^\/]+\/[^\/]+$/)
        ">= 0"
      elsif version.match(/^(http|git|ssh)/)
        if version.split('/').last =~ /^v?([\w\.-]+)$/
          fix_version_string($1.strip)
        else
          ">= 0"
        end
      else

        if version.match('.x')
          version.gsub!('.x', '.0')

          unless version.include?('>')
            version = "~> #{version.gsub('~', '')}"
          end
        end

        if version.match(/\d+\s?\*/)
          version.gsub!(/(\d+)\s?\*/) { $1 }
        end

        version.gsub!(/[+-]/, '.')

        version.gsub!(/~(?!>)\s?(\d)/, '~> \1')

        version = version[1..-1].strip if version[0] == '='

        version
      end

      if version[0] == "^"
        version = version[1..-1] 

        major = version.split('.')[0].to_i

        if major == 0
          minor = version.split('.')[1].to_i

          version = ">= #{version}, < #{major}.#{minor + 1}"
        else
          version = ">= #{version}, < #{major + 1}"
        end
      end

      specifiers.each do |specifier|
        version = version.gsub(/#{Regexp.escape(specifier)}(\d)/) { specifier + ' ' + $1 }
      end

      version
    end

    # TODO: cleanup
    def fix_gem_name(gem_name, version)
      version = version.to_s.gsub(/#.*$/, '')
      version = version.gsub(/\.git$/, '')

      gem_name = if version.match(/^[^\/]+\/[^\/]+$/)
        version
      elsif version =~ /github\.com\/([^\/]+\/[^\/]+)/
        $1
      else
        gem_name.sub(/^#{Regexp.escape(GEM_PREFIX)}/, '')
      end

      gem_name = gem_name.to_s.gsub(/#.*$/, '')
      gem_name = gem_name.gsub(/\.git$/, '')

      gem_name = if gem_name.match(/^[^\/]+\/[^\/]+$/)
        gem_name
      elsif gem_name =~ /github\.com\/([^\/]+\/[^\/]+)/
        $1
      else
        gem_name.sub(/^#{Regexp.escape(GEM_PREFIX)}/, '')
      end

      gem_name.sub('/', '--')
    end

    # TODO: tests
    def fix_dependencies(dependencies)
      Hash[dependencies.map do |name, version|
        [
          "#{GEM_PREFIX}#{Utils.fix_gem_name(name, version)}",
          Utils.fix_version_string(version)
        ]
      end]
    end

    private

    def semversion_fix(version)
      # for >1.0.x
      semVerReg = /([\<\>])(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+).x/
      if version.match(semVerReg)
        res = version.match(semVerReg)

        version_token = res[2..4].reject(&:nil?).map(&:to_i)
        version_last_token = version_token.dup
        case res[1]
          when ">"
            version_last_token[-1] += 1
          when "<"
            index = version_token.size - 1
            while version_token[index] && 0 == version_token[index]
              index =- 1
              break if -1 == index
            end
            if index == -1
              version_token[0] = 1
            else
              version_token[index] -= 1
            end
        end
        return ">= #{version_token.join(".")}.0, < #{version_last_token.join(".")}.0"
      end
      # sem version with "-"
      semVerRegSlash = /(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+)\s?-\s?(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+)/
      if version.match(semVerRegSlash)
        res = version.match(semVerRegSlash)

        version_first_token = res[1..3].reject(&:nil?).map(&:to_i)
        version_last_token = res[4..6].reject(&:nil?).map(&:to_i)

        index = version_last_token.size - 1
        while version_last_token[index] && 0 == version_last_token[index]
          index =- 1
          break if -1 == index
        end
        if -1 == index
          version_last_token[0] = 1
        else
          version_last_token[index] += 1
        end
        return ">= #{version_first_token.join(".")}, < #{version_last_token.join(".")}"
      end
      return nil
    end

  end
end
