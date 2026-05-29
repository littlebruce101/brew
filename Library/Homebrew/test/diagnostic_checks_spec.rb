# frozen_string_literal: true

require "diagnostic"

RSpec.describe Homebrew::Diagnostic::Checks do
  subject(:checks) { described_class.new }

  specify "#inject_file_list" do
    expect(checks.inject_file_list([], "foo:\n")).to eq("foo:\n")
    expect(checks.inject_file_list(%w[/a /b], "foo:\n")).to eq("foo:\n  /a\n  /b\n")
  end

  specify "#check_access_directories" do
    skip "User is root so everything is writable." if Process.euid.zero?
    begin
      dirs = [
        HOMEBREW_CACHE,
        HOMEBREW_CELLAR,
        HOMEBREW_REPOSITORY,
        HOMEBREW_LOGS,
        HOMEBREW_LOCKS,
      ]
      modes = {}
      dirs.each do |dir|
        modes[dir] = dir.stat.mode & 0777
        dir.chmod 0555
        expect(checks.check_access_directories).to match(dir.to_s)
      end
    ensure
      modes.each do |dir, mode|
        dir.chmod mode
      end
    end
  end

  specify "#check_user_path_1" do
    bin = HOMEBREW_PREFIX/"bin"
    sep = File::PATH_SEPARATOR
    # ensure /usr/bin is before HOMEBREW_PREFIX/bin in the PATH
    ENV["PATH"] = "/usr/bin#{sep}#{bin}#{sep}" +
                  ENV["PATH"].gsub(%r{(?:^|#{sep})(?:/usr/bin|#{bin})}, "")

    # ensure there's at least one file with the same name in both /usr/bin/ and
    # HOMEBREW_PREFIX/bin/
    (bin/File.basename(Dir["/usr/bin/*"].first)).mkpath

    expect(checks.check_user_path_1)
      .to match("/usr/bin occurs before #{HOMEBREW_PREFIX}/bin")
  end

  specify "#check_user_path_2" do
    ENV["PATH"] = ENV["PATH"].gsub \
      %r{(?:^|#{File::PATH_SEPARATOR})#{HOMEBREW_PREFIX}/bin}o, ""

    expect(checks.check_user_path_1).to be_nil
    expect(checks.check_user_path_2)
      .to match("Homebrew's \"bin\" was not found in your PATH.")
  end

  specify "#check_user_path_3" do
    sbin = HOMEBREW_PREFIX/"sbin"
    (sbin/"something").mkpath

    homebrew_path =
      "#{HOMEBREW_PREFIX}/bin#{File::PATH_SEPARATOR}" +
      ENV["HOMEBREW_PATH"].gsub(/(?:^|#{Regexp.escape(File::PATH_SEPARATOR)})#{Regexp.escape(sbin)}/, "")
    stub_const("ORIGINAL_PATHS", PATH.new(homebrew_path).filter_map { |path| Pathname.new(path).expand_path })

    expect(checks.check_user_path_1).to be_nil
    expect(checks.check_user_path_2).to be_nil
    expect(checks.check_user_path_3)
      .to match("Homebrew's \"sbin\" was not found in your PATH")
  ensure
    FileUtils.rm_rf(sbin)
  end

  specify "#check_for_symlinked_cellar" do
    FileUtils.rm_r(HOMEBREW_CELLAR)

    mktmpdir do |path|
      FileUtils.ln_s path, HOMEBREW_CELLAR

      expect(checks.check_for_symlinked_cellar).to match(path)
    end
  ensure
    HOMEBREW_CELLAR.unlink
    HOMEBREW_CELLAR.mkpath
  end

  specify "#check_tmpdir" do
    ENV["TMPDIR"] = "/i/don/t/exis/t"
    expect(checks.check_tmpdir).to match("doesn't exist")
  end

  specify "#check_for_external_cmd_name_conflict" do
    mktmpdir do |path1|
      mktmpdir do |path2|
        [path1, path2].each do |path|
          cmd = "#{path}/brew-foo"
          FileUtils.touch cmd
          FileUtils.chmod 0755, cmd
        end

        allow(Commands).to receive(:tap_cmd_directories).and_return([path1, path2])

        expect(checks.check_for_external_cmd_name_conflict)
          .to match("brew-foo")
      end
    end
  end

  specify "#check_homebrew_prefix" do
    allow(Homebrew).to receive(:default_prefix?).and_return(false)
    expect(checks.check_homebrew_prefix)
      .to match("Your Homebrew's prefix is not #{Homebrew::DEFAULT_PREFIX}")
  end

  specify "#check_for_unnecessary_core_tap" do
    ENV.delete("HOMEBREW_DEVELOPER")

    expect_any_instance_of(CoreTap).to receive(:installed?).and_return(true)

    expect(checks.check_for_unnecessary_core_tap).to match("You have an unnecessary local Core tap")
  end

  specify "#check_for_unnecessary_cask_tap" do
    ENV.delete("HOMEBREW_DEVELOPER")

    expect_any_instance_of(CoreCaskTap).to receive(:installed?).and_return(true)

    expect(checks.check_for_unnecessary_cask_tap).to match("unnecessary local Cask tap")
  end

  specify "#check_deprecated_official_taps — reports deprecated taps that are installed" do
    deprecated_tap = instance_double(Tap, official?: true, repository: "science")
    allow(Tap).to receive(:select).and_yield(deprecated_tap).and_return([deprecated_tap])

    expect(checks.check_deprecated_official_taps).to match("homebrew-science")
  end

  specify "#check_deprecated_official_taps — returns nil when no deprecated taps installed" do
    allow(Tap).to receive(:select).and_return([])

    expect(checks.check_deprecated_official_taps).to be_nil
  end

  specify "#check_deprecated_official_taps — skips bundle tap in CI" do
    bundle_tap = instance_double(Tap, official?: true, repository: "bundle")
    allow(Tap).to receive(:select).and_return([bundle_tap])
    ENV["GITHUB_ACTIONS"] = "true"

    expect(checks.check_deprecated_official_taps).to be_nil
  ensure
    ENV.delete("GITHUB_ACTIONS")
  end

  specify "#check_for_duplicate_formulae — returns nil when no shadowing" do
    allow(CoreTap.instance).to receive(:formula_names).and_return(["wget", "curl"])
    allow(checks).to receive(:non_core_taps).and_return([])

    expect(checks.check_for_duplicate_formulae).to be_nil
  end

  specify "#check_for_duplicate_formulae — reports formulae that shadow core" do
    non_core_tap = instance_double(Tap,
                                   name:          "user/custom",
                                   formula_names: ["user/custom/wget"],
                                   official?:     false)
    allow(CoreTap.instance).to receive(:formula_names).and_return(["wget"])
    allow(checks).to receive(:non_core_taps).and_return([non_core_tap])
    allow(Formula).to receive(:installed).and_return([])

    result = checks.check_for_duplicate_formulae
    expect(result).to match("user/custom/wget")
    expect(result).to match("brew untap user/custom")
  end

  specify "#check_for_duplicate_formulae — skipped in test-bot environment" do
    ENV["HOMEBREW_TEST_BOT"] = "1"

    expect(checks.check_for_duplicate_formulae).to be_nil
  ensure
    ENV.delete("HOMEBREW_TEST_BOT")
  end

  specify "#check_missing_deps — returns nil when cellar does not exist" do
    allow(HOMEBREW_CELLAR).to receive(:exist?).and_return(false)

    expect(checks.check_missing_deps).to be_nil
  end

  specify "#check_missing_deps — returns nil when no missing deps" do
    allow(HOMEBREW_CELLAR).to receive(:exist?).and_return(true)
    allow(Formula).to receive(:installed).and_return([])
    allow(Homebrew::Diagnostic).to receive(:missing_deps).and_return({})

    expect(checks.check_missing_deps).to be_nil
  end

  specify "#check_missing_deps — reports missing dependencies" do
    dep = instance_double(Dependency, to_s: "openssl", to_installed_formula: instance_double(Formula,
                                                                                              full_name: "openssl"))
    allow(HOMEBREW_CELLAR).to receive(:exist?).and_return(true)
    allow(Formula).to receive(:installed).and_return([])
    allow(Homebrew::Diagnostic).to receive(:missing_deps).and_return({ "wget" => [dep] })
    allow(dep.to_installed_formula).to receive(:full_name).and_return("openssl")

    result = checks.check_missing_deps
    expect(result).to match("missing dependencies")
    expect(result).to match("brew install")
  end

  specify "#check_deprecated_cask_taps — returns nil when no deprecated cask taps" do
    allow(Tap).to receive(:select).and_return([])

    expect(checks.check_deprecated_cask_taps).to be_nil
  end

  specify "#check_deprecated_cask_taps — reports caskroom taps" do
    cask_tap = instance_double(Tap, user: "caskroom", name: "caskroom/fonts")
    allow(Tap).to receive(:select).and_return([cask_tap])

    result = checks.check_deprecated_cask_taps
    expect(result).to match("caskroom/fonts")
    expect(result).to match("brew untap")
  end

  specify "#check_git_status — returns nil when git is unavailable" do
    allow(Utils::Git).to receive(:available?).and_return(false)

    expect(checks.check_git_status).to be_nil
  end

  specify "#check_git_status — returns nil when repos are clean" do
    allow(Utils::Git).to receive(:available?).and_return(true)
    allow(HOMEBREW_REPOSITORY).to receive(:exist?).and_return(true)
    allow(CoreTap.instance).to receive(:path).and_return(instance_double(Pathname, exist?: false))
    allow(CoreCaskTap.instance).to receive(:path).and_return(instance_double(Pathname, exist?: false))

    mktmpdir do |dir|
      system("git", "-C", dir.to_s, "init", "-q")
      system("git", "-C", dir.to_s, "config", "user.email", "test@test.com")
      system("git", "-C", dir.to_s, "config", "user.name", "Test")
      allow(HOMEBREW_REPOSITORY).to receive(:exist?).and_return(true)
      allow(HOMEBREW_REPOSITORY).to receive(:cd).and_return("")

      expect(checks.check_git_status).to be_nil
    end
  end
end
