require 'spec_helper'

module Build
  describe Utils do
    context '#bower' do
      it 'executes bower command and returns JSON' do
        expect(silence_stream(STDOUT) {
          Utils.bower('/', 'info jquery#2.0.3')
        }).to be_a(Hash)
      end

      it 'raises BowerError on bower error' do
        expect{silence_stream(STDOUT) {
          Utils.bower('/', 'info jquery#0.0.0')
        }}.to raise_error(BowerError)
      end
    end

    context '#fix_version_string' do
      it 'should not mutate argument' do
        foo = '2.0.0-beta.3'
        Utils.fix_version_string(foo)
        expect(foo).to eq('2.0.0-beta.3')
      end

      specify do
        expect(Utils.fix_version_string('master')).to eq(">= 0")
      end

      specify do
        expect(Utils.fix_version_string('latest')).to eq(">= 0")
      end

      specify do
        expect(Utils.fix_version_string('2.0.3-foo')).to eq('2.0.3.foo')
      end

      specify do
        expect(Utils.fix_version_string('>=2.0.1')).to eq('>= 2.0.1')
      end

      specify do
        expect(Utils.fix_version_string('~ 2.1.2')).to eq('~> 2.1.2')
      end

      specify do
        expect(Utils.fix_version_string('2.3.x')).to eq('~> 2.3.0')
      end

      specify do
        expect(Utils.fix_version_string('v2.3.x')).to eq('~> 2.3.0')
      end

      specify do
        expect(Utils.fix_version_string('foo/bar2')).to eq(">= 0")
      end

      specify do
        expect(Utils.fix_version_string(
          'https://github.com/voodootikigod/node-csv/tarball/master')
        ).to eq(">= 0")
      end

      specify do
        expect(Utils.fix_version_string(
          'https://github.com/voodootikigod/node-csv/tarball/v2.3.1-foo'
        )).to eq('2.3.1.foo')
      end

      specify do
        expect(Utils.fix_version_string('~1.x')).to eq('~> 1.0')
      end

      specify do
        expect(Utils.fix_version_string('1.x')).to eq('~> 1.0')
      end

      specify do
        expect(Utils.fix_version_string('~1.*')).to eq('~> 1.0')
      end

      specify do
        expect(Utils.fix_version_string('1.*')).to eq('~> 1.0')
      end

      specify do
        expect(Utils.fix_version_string('~3.4')).to eq('~> 3.4')
      end

      specify do
        expect(Utils.fix_version_string('*')).to eq(">= 0")
      end

      specify do
        expect(Utils.fix_version_string('v1.2.6-build.1989+sha.b0474cb')).
          to eq("1.2.6.build.1989.sha.b0474cb")
      end

      specify do
        expect(Utils.fix_version_string('>= 2.0.1 < 2.1.0')).
          to eq('>= 2.0.1, < 2.1.0')
      end

      specify do
        expect(Utils.fix_version_string('>= 2.0.1-foo < 2.1.0')).
          to eq('>= 2.0.1.foo, < 2.1.0')
      end

      specify do
        expect(Utils.fix_version_string('>= 2.1.2 <3.0.0')).
          to eq('>= 2.1.2, < 3.0.0')
      end

      specify do
        expect(Utils.fix_version_string(' >=1  <2 ')).
          to eq(">= 1, < 2")
      end

      specify do
        expect {
          Utils.fix_version_string(' 1.0.x  ||>=1.0.5 ')
        }.to raise_error(BuildError)
      end

      specify do
        expect(Utils.fix_version_string('desandro/doc-ready#>=1.0.1 <2.0')).
          to eq(">= 1.0.1, < 2.0")
      end

      specify do
        expect(Utils.fix_version_string('!=1.0.0')).
          to eq("!= 1.0.0")
      end

      specify do
        expect(Utils.fix_version_string('=1.0.0')).
          to eq("1.0.0")
      end

      specify do
        expect(Utils.fix_version_string('>=1.0.x')).
          to eq(">= 1.0.0")
      end

      specify do
        expect(Utils.fix_version_string('~v1.0.0')).
          to eq("~> 1.0.0")
      end

      specify do
        expect(Utils.fix_version_string('~v1.0.x')).
          to eq("~> 1.0.0")
      end

      specify do
        expect(Utils.fix_version_string('1.0.v0')).
          to eq("1.0.v0")
      end

      # a-class-above#0.0.9
      specify do
        expect(Utils.fix_version_string('> 1.0.0*')).
          to eq("> 1.0.0")
      end

      specify do
        expect(Utils.fix_version_string('^1.2.3')).
          to eq(">= 1.2.3, < 2")
      end

      specify do
        expect(Utils.fix_version_string('^1.2.3 <1.9')).
          to eq(">= 1.2.3, < 2, < 1.9")
      end

      specify do
        expect(Utils.fix_version_string('^0.1.3')).
          to eq(">= 0.1.3, < 0.2")
      end

      specify do
        # Not sure if it means "> 1.0" or "> 1.0.0"
        # I am sure - https://github.com/isaacs/node-semver#ranges
        expect(Utils.fix_version_string('>1.0.x')).
          to eq(">= 1.0.0, < 1.1.0")
      end

      specify do
        expect(Utils.fix_version_string('<2.0.x')).
          to eq(">= 1.0.0, < 2.0.0")
      end

      specify do
        expect(Utils.fix_version_string('1.0 - 1.2')).
          to eq(">= 1.0, < 1.3")
      end

      specify do
        expect(Utils.fix_version_string('1.2 - 1.3.4')).
          to eq(">= 1.2, < 1.3.5")
      end

      specify do
        expect(Utils.fix_version_string('1.1.5 - 1.2.4')).
          to eq(">= 1.1.5, < 1.2.5")
      end

      specify do
        # without spaces
        expect(Utils.fix_version_string('1.2.1-1.5.4')).
          to eq(">= 1.2.1, < 1.5.5")
      end

      xspecify do
        expect(Utils.fix_version_string('1.0 || 1.1')).
          to eq(">= 1.0, < 1.2")
      end
    end

    context '#fix_gem_name' do
      it 'does notthing if version is normal' do
        expect(Utils.fix_gem_name('foobar', '0.2.1')).to eq('foobar')
        expect(Utils.fix_gem_name('foobar', nil)).to eq('foobar')
      end

      it 'uses repository name if version is github url' do
        expect(Utils.fix_gem_name(
          'node-csv', 'https://github.com/voodootikigod/node-csv/tarball/v2.3.1-foo'
        )).to eq('voodootikigod--node-csv')
      end

      it 'removes .git postfix from git url' do
        expect(Utils.fix_gem_name(
          'tinymce', 'git://github.com/jozzhart/tinymce.git#4.0.0'
        )).to eq('jozzhart--tinymce')
      end

      it 'removes rails-assets- prefix' do
        expect(Utils.fix_gem_name(
          'rails-assets-tinymce', '1.0.0'
        )).to eq('tinymce')
      end

      it 'replaces / with -- even if # is present' do
        expect(Utils.fix_gem_name(
          'matches-selector', 'desandro/matches-selector#>=0.2.0'
        )).to eq('desandro--matches-selector')
      end
    end

    context '#fix_dependencies' do
      specify do
        expect(Utils.fix_dependencies(
          "desandro/matches-selector" => ">=0.2.0"
        )).to eq(
          "rails-assets-desandro--matches-selector" => ">= 0.2.0"
        )
      end

      specify do
        expect(Utils.fix_dependencies(
          "tinymce" => "git://github.com/jozzhart/tinymce.git#4.0.0"
        )).to eq(
          "rails-assets-jozzhart--tinymce" => "4.0.0"
        )
      end

      specify do
        expect(Utils.fix_dependencies(
          "git://github.com/jozzhart/tinymce.git" => "4.0.0"
        )).to eq(
          "rails-assets-jozzhart--tinymce" => "4.0.0"
        )
      end
    end
  end
end
