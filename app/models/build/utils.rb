require 'open3'

module Build
  module Utils
    extend self

    # Returns The Hash result if command succeeded.
    # Raises The BowerError if command failed.
    def bower(path, *command)
      Dir.mktmpdir 'bower' do |tmp|
        command = "#{BOWER_BIN} #{command.join(' ')} --json"
        command += " --config.tmp=#{tmp}/tmp"
        command += " --config.storage.packages=#{tmp}/cache"
        command += ' --config.interactive=false'

        Rails.logger.info(message: 'running bower', command: command)

        JSON.parse(Utils.sh(path, command))
      end
    rescue ShellError => e
      raise BowerError.from_shell_error(e)
    end

    # Returns The String stdout if command succeeded.
    # Raises The ShellError if command failed.
    def sh(cwd, *cmd)
      cmd = cmd.join(' ')

      Rails.logger.debug(message: 'running shell command',
                         command: "cd #{cwd} && #{cmd}")

      output, error, status = Open3.capture3(cmd, chdir: cwd)

      if output.present?
        Rails.logger.debug(
          message: 'shell command finished',
          command: cmd,
          output: output
        )
      end

      if error.present? && !status.success?
        Rails.logger.warn(
          message: 'shell command failed',
          command: cmd,
          error_message: error
        )
      end

      raise ShellError.new(error, cwd, cmd) unless status.success?
      output
    end

    def fix_version_string(version)
      version = version.to_s.dup

      version = version.downcase if version.match(/\p{Upper}/)
      version = semversion_fix(version)

      basic_specifiers = ['>', '<', '>=', '<=']
      specifiers = ['>', '<', '>=', '<=', '~', '~>', '=', '!=', '^']

      basic_specifiers.each do |specifier|
        # for >1.0.x etc.
        semVerReg = /#{Regexp.escape(specifier)}\s*(\d+\.)*[x\*]/

        version.gsub!(semVerReg) do |match|
          new = match.strip[0..-3]

          case specifier
          when '>'
            new[-1] = (new[-1].to_i + 1).to_s
            new.gsub specifier, '>='
          when '<='
            new[-1] = (new[-1].to_i + 1).to_s
            new.gsub specifier, '<'
          else
            new
          end
        end
      end

      version = '*' if version.include?('||')

      # Remove any unnecessary spaces
      version = version.split(' ').join(' ')

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

      version = version.gsub(/^([^\d]*)v/) { Regexp.last_match(1) }
      version = version.gsub('.*', '.x')

      version = if ['latest', 'master', '*'].include?(version)
                  '>= 0'
                elsif version =~ /^[^\/]+\/[^\/]+$/
                  '>= 0'
                elsif version =~ /^(http|git|ssh)/
                  if version.split('/').last =~ /^v?([\w\.-]+)$/
                    fix_version_string(Regexp.last_match(1).strip)
                  else
                    '>= 0'
                  end
                else

                  if version =~ /\.x/
                    version.gsub!(/\.x/, '.0')

                    unless version.include?('>') || version.include?('^')
                      version = "~> #{version.delete('~')}"
                    end
                  end

                  if version =~ /\d+\s?\*/
                    version.gsub!(/(\d+)\s?\*/) { Regexp.last_match(1) }
                  end

                  version.gsub!(/[+-]/, '.')

                  version.gsub!(/~(?!>)\s?(\d)/, '~> \1')

                  version = version[1..-1].strip if version[0] == '='

                  version
                end

      if version[0] == '^'
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
        version = version.gsub(/#{Regexp.escape(specifier)}(\d)/) { specifier + ' ' + Regexp.last_match(1) }
      end

      version
    end

    # TODO: cleanup
    def fix_gem_name(gem_name, version)
      version = version.to_s.gsub(/#.*$/, '')
      version = version.gsub(/\.git$/, '')

      gem_name = if version =~ /^[^\/]+\/[^\/]+$/
                   version
                 elsif version =~ /github\.com\/([^\/]+\/[^\/]+)/
                   Regexp.last_match(1)
                 else
                   gem_name.sub(/^#{Regexp.escape(GEM_PREFIX)}/, '')
                 end

      gem_name = gem_name.to_s.gsub(/#.*$/, '')
      gem_name = gem_name.gsub(/\.git$/, '')

      gem_name = if gem_name =~ /^[^\/]+\/[^\/]+$/
                   gem_name
                 elsif gem_name =~ /github\.com\/([^\/]+\/[^\/]+)/
                   Regexp.last_match(1)
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
      # sem version with "-"
      semVerRegSlash = /(?:(\d+)\.)?(?:(\d+)\.)?(x|\*|\d+)\s-\s(?:(\d+)\.)?(?:(\d+)\.)?(x|\*|\d+)/
      version.gsub!(semVerRegSlash) do |match|
        res = match.match(semVerRegSlash)

        version_first_token = res[1..3].compact.map do |i|
          next if i == 'x' || i == '*'
          i.to_i
        end.compact

        version_last_token = res[4..6].compact.map do |i|
          next if i == 'x' || i == '*'
          i.to_i
        end.compact

        version_last_token[version_last_token.size - 1] += 1

        ">= #{version_first_token.join('.')} < #{version_last_token.join('.')}"
      end

      version
    end
  end
end
