# frozen_string_literal: true

require "formula_cellar_checks"

RSpec.describe FormulaCellarChecks do
  # Build a minimal concrete class that satisfies the abstract interface.
  let(:formula_prefix) { mktmpdir }
  let(:test_formula) do
    f = formula do
      url "https://brew.sh/test-1.0.tgz"
    end
    allow(f).to receive(:prefix).and_return(formula_prefix)
    allow(f).to receive(:lib).and_return(formula_prefix/"lib")
    allow(f).to receive(:share).and_return(formula_prefix/"share")
    f
  end

  let(:checker) do
    f = test_formula
    obj = Object.new
    obj.extend(described_class)
    allow(obj).to receive(:formula).and_return(f)
    allow(obj).to receive(:problem_if_output) { |msg| msg }
    obj
  end

  describe "#check_manpages" do
    it "returns nil when no top-level man directory exists" do
      expect(checker.check_manpages).to be_nil
    end

    it "reports a problem when a top-level man directory is present" do
      (formula_prefix/"man").mkpath
      expect(checker.check_manpages).to match('top-level "man" directory')
    end
  end

  describe "#check_infopages" do
    it "returns nil when no top-level info directory exists" do
      expect(checker.check_infopages).to be_nil
    end

    it "reports a problem when a top-level info directory is present" do
      (formula_prefix/"info").mkpath
      expect(checker.check_infopages).to match('top-level "info" directory')
    end
  end

  describe "#check_jars" do
    it "returns nil when lib does not exist" do
      expect(checker.check_jars).to be_nil
    end

    it "returns nil when lib has no .jar files" do
      (formula_prefix/"lib").mkpath
      (formula_prefix/"lib/libfoo.dylib").write("")
      expect(checker.check_jars).to be_nil
    end

    it "reports a problem when .jar files are installed to lib" do
      lib = formula_prefix/"lib"
      lib.mkpath
      (lib/"foo.jar").write("")
      expect(checker.check_jars).to match("JARs were installed")
    end
  end

  describe "#check_non_libraries" do
    it "returns nil when lib does not exist" do
      expect(checker.check_non_libraries).to be_nil
    end

    it "returns nil when all lib children have valid extensions" do
      lib = formula_prefix/"lib"
      lib.mkpath
      (lib/"libfoo.a").write("")
      (lib/"libfoo.so").write("")
      expect(checker.check_non_libraries).to be_nil
    end

    it "reports non-library files installed to lib" do
      lib = formula_prefix/"lib"
      lib.mkpath
      (lib/"foo.txt").write("")
      expect(checker.check_non_libraries).to match("Non-libraries were installed")
    end
  end

  describe "#check_non_executables" do
    it "returns nil when bin does not exist" do
      expect(checker.check_non_executables(formula_prefix/"bin")).to be_nil
    end

    it "returns nil when all bin children are executable files" do
      bin = formula_prefix/"bin"
      bin.mkpath
      exe = bin/"foo"
      exe.write("#!/bin/sh")
      exe.chmod(0755)
      expect(checker.check_non_executables(bin)).to be_nil
    end

    it "reports non-executable files in bin" do
      bin = formula_prefix/"bin"
      bin.mkpath
      (bin/"README").write("docs")
      expect(checker.check_non_executables(bin)).to match("Non-executables were installed")
    end

    it "reports subdirectories in bin" do
      bin = formula_prefix/"bin"
      bin.mkpath
      (bin/"subdir").mkpath
      expect(checker.check_non_executables(bin)).to match("Non-executables were installed")
    end
  end

  describe "#check_generic_executables" do
    it "returns nil when bin does not exist" do
      expect(checker.check_generic_executables(formula_prefix/"bin")).to be_nil
    end

    it "returns nil when no generic names present" do
      bin = formula_prefix/"bin"
      bin.mkpath
      (bin/"mytool").write("#!/bin/sh")
      expect(checker.check_generic_executables(bin)).to be_nil
    end

    it "reports generic binary names" do
      bin = formula_prefix/"bin"
      bin.mkpath
      (bin/"service").write("#!/bin/sh")
      expect(checker.check_generic_executables(bin)).to match("Generic binaries were installed")
    end
  end

  describe "#check_easy_install_pth" do
    it "returns nil when no easy-install.pth files exist" do
      lib = formula_prefix/"lib"
      lib.mkpath
      expect(checker.check_easy_install_pth(lib)).to be_nil
    end

    it "reports easy-install.pth files found in python site-packages" do
      lib = formula_prefix/"lib"
      site_packages = lib/"python3.11/site-packages"
      site_packages.mkpath
      (site_packages/"easy-install.pth").write("")

      expect(checker.check_easy_install_pth(lib)).to match("easy-install.pth")
    end
  end

  describe "#check_elisp_dirname" do
    it "returns nil when emacs/site-lisp does not exist" do
      share = formula_prefix/"share"
      share.mkpath
      expect(checker.check_elisp_dirname(share, "mypackage")).to be_nil
    end

    it "returns nil when emacs is the formula itself" do
      share = formula_prefix/"share"
      site_lisp = share/"emacs/site-lisp"
      site_lisp.mkpath
      (site_lisp/"other-dir").mkpath
      expect(checker.check_elisp_dirname(share, "emacs")).to be_nil
    end

    it "returns nil when directory name matches the formula name" do
      share = formula_prefix/"share"
      site_lisp = share/"emacs/site-lisp"
      (site_lisp/"mypackage").mkpath
      expect(checker.check_elisp_dirname(share, "mypackage")).to be_nil
    end

    it "reports when elisp files are in a directory with the wrong name" do
      share = formula_prefix/"share"
      site_lisp = share/"emacs/site-lisp"
      (site_lisp/"wrong-name").mkpath
      result = checker.check_elisp_dirname(share, "mypackage")
      expect(result).to match("wrong")
    end
  end

  describe "#valid_library_extension?" do
    it "returns true for valid library extensions" do
      %w[.a .so .jar .la .o .prl .pm .sh].each do |ext|
        expect(checker.valid_library_extension?(Pathname("libfoo#{ext}"))).to be true
      end
    end

    it "returns false for non-library extensions" do
      %w[.txt .py .rb .exe .dll].each do |ext|
        expect(checker.valid_library_extension?(Pathname("foo#{ext}"))).to be false
      end
    end
  end
end
