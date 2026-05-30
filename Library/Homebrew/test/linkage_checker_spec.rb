# frozen_string_literal: true

require "linkage_checker"
require "linkage_cache_store"

RSpec.describe LinkageChecker do
  # Build a real keg under HOMEBREW_CELLAR so Keg.new does not raise.
  let(:formula_name) { "testpkg" }
  let(:keg_path) do
    path = HOMEBREW_CELLAR/formula_name/"1.0"
    path.mkpath
    path
  end
  let(:keg) { Keg.new(keg_path) }

  # Stub out the cache store so check_dylibs does not try to write to disk.
  let(:store) do
    s = instance_double(LinkageCacheStore)
    allow(s).to receive(:fetch).and_return({})
    allow(s).to receive(:update!)
    s
  end

  let(:formula_double) do
    f = instance_double(
      Formula,
      name:    formula_name,
      prefix:  keg_path,
      deps:    [],
      build:   instance_double(BuildOptions, without?: false),
      tap:     nil,
    )
    allow(f).to receive(:runtime_formula_dependencies).and_return([])
    f
  end

  # Build a LinkageChecker with all expensive operations bypassed.
  # The keg has no binaries, so check_dylibs iterates zero files.
  let(:checker) do
    allow(LinkageCacheStore).to receive(:new).and_return(store)
    described_class.new(keg, formula_double, cache_db: nil)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # broken_library_linkage?
  # ──────────────────────────────────────────────────────────────────────────

  describe "#broken_library_linkage?" do
    context "when there are no broken deps or dylibs" do
      it "returns false" do
        expect(checker.broken_library_linkage?).to be false
      end
    end

    context "in test mode with no additional issues" do
      it "returns false" do
        expect(checker.broken_library_linkage?(test: true)).to be false
      end
    end

    it "raises ArgumentError when strict: true without test: true" do
      expect { checker.broken_library_linkage?(strict: true) }
        .to raise_error(ArgumentError, /Strict linkage checking requires test mode/)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private helper: harmless_broken_link?
  # ──────────────────────────────────────────────────────────────────────────

  describe "#harmless_broken_link? (private)" do
    it "returns true for known harmless dylibs" do
      [
        "/usr/lib/libgcc_s_ppc64.1.dylib",
        "/opt/local/lib/libgcc/libgcc_s.1.dylib",
        "#{HOMEBREW_PREFIX}/opt/llvm/lib/libc++.1.dylib",
      ].each do |lib|
        expect(checker.send(:harmless_broken_link?, lib)).to be true
      end
    end

    it "returns false for arbitrary dylibs" do
      expect(checker.send(:harmless_broken_link?, "/usr/lib/libc.dylib")).to be false
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private helper: system_framework?
  # ──────────────────────────────────────────────────────────────────────────

  describe "#system_framework? (private)" do
    it "returns true for paths under /System/Library/Frameworks/" do
      expect(checker.send(:system_framework?, "/System/Library/Frameworks/AppKit.framework/AppKit")).to be true
    end

    it "returns false for arbitrary paths" do
      expect(checker.send(:system_framework?, "/usr/lib/libz.dylib")).to be false
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private helper: dylib_to_dep
  # ──────────────────────────────────────────────────────────────────────────

  describe "#dylib_to_dep (private)" do
    it "extracts the formula name from a Cellar dylib path" do
      path = "#{HOMEBREW_PREFIX}/Cellar/openssl@3/3.1.0/lib/libssl.3.dylib"
      expect(checker.send(:dylib_to_dep, path)).to eq("openssl@3")
    end

    it "extracts the formula name from an opt dylib path" do
      path = "#{HOMEBREW_PREFIX}/opt/zlib/lib/libz.dylib"
      expect(checker.send(:dylib_to_dep, path)).to eq("zlib")
    end

    it "returns nil for system dylibs" do
      expect(checker.send(:dylib_to_dep, "/usr/lib/libz.dylib")).to be_nil
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private helper: sort_by_formula_full_name!
  # ──────────────────────────────────────────────────────────────────────────

  describe "#sort_by_formula_full_name! (private)" do
    it "sorts plain names before tap-qualified names" do
      arr = ["tap/user/zlib", "openssl", "tap/user/curl", "git"]
      checker.send(:sort_by_formula_full_name!, arr)
      expect(arr.first(2)).to match_array(%w[git openssl])
      expect(arr.last(2)).to match_array(["tap/user/curl", "tap/user/zlib"])
    end

    it "sorts plain names alphabetically" do
      arr = %w[zlib openssl curl]
      checker.send(:sort_by_formula_full_name!, arr)
      expect(arr).to eq(%w[curl openssl zlib])
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private helper: display_items
  # ──────────────────────────────────────────────────────────────────────────

  describe "#display_items (private)" do
    it "returns nil-equivalent (empty) for an empty collection" do
      # display_items returns early for empty things without output
      output = checker.send(:display_items, "Label", [], puts_output: false)
      expect(output).to be_nil
    end

    it "formats an array of strings under the given label" do
      result = checker.send(:display_items, "Missing libraries", %w[libfoo.dylib libbar.dylib], puts_output: false)
      expect(result).to include("Missing libraries")
      expect(result).to include("libfoo.dylib")
      expect(result).to include("libbar.dylib")
    end

    it "formats a hash with sub-labels" do
      hash = { "dep_a" => Set.new(["lib_a1.dylib", "lib_a2.dylib"]) }
      result = checker.send(:display_items, "Homebrew libraries", hash, puts_output: false)
      expect(result).to include("dep_a")
      expect(result).to include("lib_a1.dylib")
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Public readers
  # ──────────────────────────────────────────────────────────────────────────

  describe "public readers" do
    it "exposes #keg" do
      expect(checker.keg).to eq(keg)
    end

    it "exposes #formula" do
      expect(checker.formula).to eq(formula_double)
    end

    it "exposes #undeclared_deps as an array" do
      expect(checker.undeclared_deps).to be_an(Array)
    end
  end
end
