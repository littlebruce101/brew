# frozen_string_literal: true

require "on_system"
require "simulate_system"

RSpec.describe OnSystem do
  after { Homebrew::SimulateSystem.clear }

  describe ".arch_condition_met?" do
    it "returns true when the simulated arch matches" do
      Homebrew::SimulateSystem.with(arch: :arm) do
        expect(described_class.arch_condition_met?(:arm)).to be true
      end
    end

    it "returns false when the simulated arch does not match" do
      Homebrew::SimulateSystem.with(arch: :intel) do
        expect(described_class.arch_condition_met?(:arm)).to be false
      end
    end

    it "raises ArgumentError for an invalid arch" do
      expect { described_class.arch_condition_met?(:sparc) }
        .to raise_error(ArgumentError, /Invalid arch condition/)
    end
  end

  describe ".os_condition_met?" do
    context "with a base OS condition (:macos)" do
      it "returns true when simulating macOS" do
        Homebrew::SimulateSystem.with(os: :macos) do
          expect(described_class.os_condition_met?(:macos)).to be true
        end
      end

      it "returns false when simulating Linux" do
        Homebrew::SimulateSystem.with(os: :linux) do
          expect(described_class.os_condition_met?(:macos)).to be false
        end
      end
    end

    context "with a base OS condition (:linux)" do
      it "returns true when simulating Linux" do
        Homebrew::SimulateSystem.with(os: :linux) do
          expect(described_class.os_condition_met?(:linux)).to be true
        end
      end

      it "returns false when simulating macOS" do
        Homebrew::SimulateSystem.with(os: :macos) do
          expect(described_class.os_condition_met?(:linux)).to be false
        end
      end
    end

    context "with a versioned macOS condition" do
      it "returns false when simulating Linux" do
        Homebrew::SimulateSystem.with(os: :linux) do
          expect(described_class.os_condition_met?(:ventura)).to be false
        end
      end

      it "returns true when the simulated version matches exactly" do
        Homebrew::SimulateSystem.with(os: :ventura) do
          expect(described_class.os_condition_met?(:ventura)).to be true
        end
      end

      it "returns false when the simulated version differs" do
        Homebrew::SimulateSystem.with(os: :monterey) do
          expect(described_class.os_condition_met?(:ventura)).to be false
        end
      end
    end

    context "with :or_newer modifier" do
      it "returns true for a newer macOS" do
        Homebrew::SimulateSystem.with(os: :sonoma) do
          expect(described_class.os_condition_met?(:ventura, :or_newer)).to be true
        end
      end

      it "returns true for the exact version" do
        Homebrew::SimulateSystem.with(os: :ventura) do
          expect(described_class.os_condition_met?(:ventura, :or_newer)).to be true
        end
      end

      it "returns false for an older version" do
        Homebrew::SimulateSystem.with(os: :monterey) do
          expect(described_class.os_condition_met?(:ventura, :or_newer)).to be false
        end
      end
    end

    context "with :or_older modifier" do
      it "returns true for an older version" do
        Homebrew::SimulateSystem.with(os: :monterey) do
          expect(described_class.os_condition_met?(:ventura, :or_older)).to be true
        end
      end

      it "returns true for the exact version" do
        Homebrew::SimulateSystem.with(os: :ventura) do
          expect(described_class.os_condition_met?(:ventura, :or_older)).to be true
        end
      end

      it "returns false for a newer version" do
        Homebrew::SimulateSystem.with(os: :sonoma) do
          expect(described_class.os_condition_met?(:ventura, :or_older)).to be false
        end
      end
    end

    it "raises ArgumentError for an invalid macOS version symbol" do
      expect { described_class.os_condition_met?(:windows_xp) }
        .to raise_error(ArgumentError, /Invalid OS condition/)
    end

    it "raises ArgumentError for an invalid or_condition" do
      expect { described_class.os_condition_met?(:ventura, :or_sideways) }
        .to raise_error(ArgumentError, /Invalid OS `or_\*` condition/)
    end
  end

  describe ".condition_from_method_name" do
    it "strips the on_ prefix" do
      expect(described_class.condition_from_method_name(:on_macos)).to eq(:macos)
    end

    it "strips on_ from versioned names" do
      expect(described_class.condition_from_method_name(:on_ventura)).to eq(:ventura)
    end

    it "strips on_ from arch names" do
      expect(described_class.condition_from_method_name(:on_arm)).to eq(:arm)
    end
  end

  describe "on_arm / on_intel block methods" do
    let(:host) do
      klass = Class.new
      klass.include(OnSystem::MacOSAndLinux)
      klass.new
    end

    it "executes the on_arm block when running on ARM" do
      Homebrew::SimulateSystem.with(arch: :arm) do
        called = false
        host.on_arm { called = true }
        expect(called).to be true
      end
    end

    it "skips the on_arm block when running on Intel" do
      Homebrew::SimulateSystem.with(arch: :intel) do
        called = false
        host.on_arm { called = true }
        expect(called).to be false
      end
    end

    it "executes the on_intel block when running on Intel" do
      Homebrew::SimulateSystem.with(arch: :intel) do
        called = false
        host.on_intel { called = true }
        expect(called).to be true
      end
    end

    it "returns the block's return value when condition is met" do
      Homebrew::SimulateSystem.with(arch: :arm) do
        result = host.on_arm { 42 }
        expect(result).to eq(42)
      end
    end

    it "returns nil when condition is not met" do
      Homebrew::SimulateSystem.with(arch: :intel) do
        result = host.on_arm { 42 }
        expect(result).to be_nil
      end
    end

    it "sets @on_system_blocks_exist when on_arm is called" do
      Homebrew::SimulateSystem.with(arch: :arm) do
        host.on_arm {}
        expect(host.instance_variable_get(:@on_system_blocks_exist)).to be true
      end
    end
  end

  describe "on_macos / on_linux block methods" do
    let(:host) do
      klass = Class.new
      klass.include(OnSystem::MacOSAndLinux)
      klass.new
    end

    it "executes on_macos block when simulating macOS" do
      Homebrew::SimulateSystem.with(os: :macos) do
        called = false
        host.on_macos { called = true }
        expect(called).to be true
      end
    end

    it "skips on_macos block when simulating Linux" do
      Homebrew::SimulateSystem.with(os: :linux) do
        called = false
        host.on_macos { called = true }
        expect(called).to be false
      end
    end

    it "executes on_linux block when simulating Linux" do
      Homebrew::SimulateSystem.with(os: :linux) do
        called = false
        host.on_linux { called = true }
        expect(called).to be true
      end
    end
  end

  describe "on_ventura (versioned macOS) block method" do
    let(:host) do
      klass = Class.new
      klass.include(OnSystem::MacOSAndLinux)
      klass.new
    end

    it "executes block when simulating Ventura exactly" do
      Homebrew::SimulateSystem.with(os: :ventura) do
        called = false
        host.on_ventura { called = true }
        expect(called).to be true
      end
    end

    it "skips block when simulating Monterey" do
      Homebrew::SimulateSystem.with(os: :monterey) do
        called = false
        host.on_ventura { called = true }
        expect(called).to be false
      end
    end

    it "executes block with :or_newer on Sonoma" do
      Homebrew::SimulateSystem.with(os: :sonoma) do
        called = false
        host.on_ventura(:or_newer) { called = true }
        expect(called).to be true
      end
    end

    it "skips block with :or_newer on Monterey" do
      Homebrew::SimulateSystem.with(os: :monterey) do
        called = false
        host.on_ventura(:or_newer) { called = true }
        expect(called).to be false
      end
    end
  end

  describe "on_arch_conditional" do
    let(:host) do
      klass = Class.new
      klass.include(OnSystem::MacOSAndLinux)
      klass.new
    end

    it "returns the arm: value when on ARM" do
      Homebrew::SimulateSystem.with(arch: :arm) do
        expect(host.on_arch_conditional(arm: "arm-value", intel: "intel-value")).to eq("arm-value")
      end
    end

    it "returns the intel: value when on Intel" do
      Homebrew::SimulateSystem.with(arch: :intel) do
        expect(host.on_arch_conditional(arm: "arm-value", intel: "intel-value")).to eq("intel-value")
      end
    end
  end
end

# A test host class that includes OnSystem::MacOSAndLinux so we can exercise
# the generated `on_*` methods directly.
class OnSystemTestHost
  include OnSystem::MacOSAndLinux
end

RSpec.describe OnSystem do
  subject(:host) { OnSystemTestHost.new }

  after do
    Homebrew::SimulateSystem.clear
  end

  # ---------------------------------------------------------------------------
  # .arch_condition_met?
  # ---------------------------------------------------------------------------
  describe ".arch_condition_met?" do
    it "returns true when the current arch matches" do
      Homebrew::SimulateSystem.arch = :arm
      expect(described_class.arch_condition_met?(:arm)).to be true
    end

    it "returns false when the current arch does not match" do
      Homebrew::SimulateSystem.arch = :intel
      expect(described_class.arch_condition_met?(:arm)).to be false
    end

    it "raises for an invalid arch symbol" do
      expect { described_class.arch_condition_met?(:powerpc) }
        .to raise_error(ArgumentError, /Invalid arch condition/)
    end
  end

  # ---------------------------------------------------------------------------
  # .os_condition_met? — base OS
  # ---------------------------------------------------------------------------
  describe ".os_condition_met?" do
    it "returns true for :linux when simulating linux" do
      Homebrew::SimulateSystem.os = :linux
      expect(described_class.os_condition_met?(:linux)).to be true
    end

    it "returns false for :linux when simulating macos" do
      Homebrew::SimulateSystem.os = :macos
      expect(described_class.os_condition_met?(:linux)).to be false
    end

    it "returns true for :macos when simulating macos" do
      Homebrew::SimulateSystem.os = :macos
      expect(described_class.os_condition_met?(:macos)).to be true
    end

    it "returns false for :macos when simulating linux" do
      Homebrew::SimulateSystem.os = :linux
      expect(described_class.os_condition_met?(:macos)).to be false
    end

    it "raises for an invalid OS name" do
      expect { described_class.os_condition_met?(:windows) }
        .to raise_error(ArgumentError, /Invalid OS condition/)
    end

    it "raises for an invalid or_condition" do
      Homebrew::SimulateSystem.os = :ventura
      expect { described_class.os_condition_met?(:ventura, :or_sometimes) }
        .to raise_error(ArgumentError, /Invalid OS `or_\*` condition/)
    end
  end

  # ---------------------------------------------------------------------------
  # .os_condition_met? — macOS version comparisons
  # ---------------------------------------------------------------------------
  describe ".os_condition_met? with version comparisons" do
    it "returns true for exact match (ventura == ventura)" do
      Homebrew::SimulateSystem.os = :ventura
      expect(described_class.os_condition_met?(:ventura)).to be true
    end

    it "returns false for exact mismatch (monterey != ventura)" do
      Homebrew::SimulateSystem.os = :monterey
      expect(described_class.os_condition_met?(:ventura)).to be false
    end

    it "returns true for :or_newer when current OS is newer" do
      Homebrew::SimulateSystem.os = :ventura
      expect(described_class.os_condition_met?(:monterey, :or_newer)).to be true
    end

    it "returns false for :or_newer when current OS is older" do
      Homebrew::SimulateSystem.os = :monterey
      expect(described_class.os_condition_met?(:ventura, :or_newer)).to be false
    end

    it "returns true for :or_older when current OS is older" do
      Homebrew::SimulateSystem.os = :monterey
      expect(described_class.os_condition_met?(:ventura, :or_older)).to be true
    end

    it "returns false for :or_older when current OS is newer" do
      Homebrew::SimulateSystem.os = :ventura
      expect(described_class.os_condition_met?(:monterey, :or_older)).to be false
    end

    it "returns false for any macOS version when simulating linux" do
      Homebrew::SimulateSystem.os = :linux
      expect(described_class.os_condition_met?(:ventura)).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # on_macos / on_linux block behaviour
  # ---------------------------------------------------------------------------
  describe "#on_macos" do
    it "calls the block when simulating macOS" do
      Homebrew::SimulateSystem.os = :macos
      called = false
      host.on_macos { called = true }
      expect(called).to be true
    end

    it "does not call the block when simulating linux" do
      Homebrew::SimulateSystem.os = :linux
      called = false
      host.on_macos { called = true }
      expect(called).to be false
    end

    it "returns the block's return value when called" do
      Homebrew::SimulateSystem.os = :macos
      result = host.on_macos { 42 }
      expect(result).to eq 42
    end

    it "returns nil when block is skipped" do
      Homebrew::SimulateSystem.os = :linux
      result = host.on_macos { 42 }
      expect(result).to be_nil
    end
  end

  describe "#on_linux" do
    it "calls the block when simulating linux" do
      Homebrew::SimulateSystem.os = :linux
      called = false
      host.on_linux { called = true }
      expect(called).to be true
    end

    it "does not call the block when simulating macos" do
      Homebrew::SimulateSystem.os = :macos
      called = false
      host.on_linux { called = true }
      expect(called).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # on_arm / on_intel block behaviour
  # ---------------------------------------------------------------------------
  describe "#on_arm" do
    it "calls the block when simulating arm" do
      Homebrew::SimulateSystem.arch = :arm
      called = false
      host.on_arm { called = true }
      expect(called).to be true
    end

    it "does not call the block when simulating intel" do
      Homebrew::SimulateSystem.arch = :intel
      called = false
      host.on_arm { called = true }
      expect(called).to be false
    end
  end

  describe "#on_intel" do
    it "calls the block when simulating intel" do
      Homebrew::SimulateSystem.arch = :intel
      called = false
      host.on_intel { called = true }
      expect(called).to be true
    end

    it "does not call the block when simulating arm" do
      Homebrew::SimulateSystem.arch = :arm
      called = false
      host.on_intel { called = true }
      expect(called).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # macOS-version-specific on_<version> methods
  # ---------------------------------------------------------------------------
  describe "#on_ventura" do
    it "calls the block when simulating ventura exactly" do
      Homebrew::SimulateSystem.os = :ventura
      called = false
      host.on_ventura { called = true }
      expect(called).to be true
    end

    it "does not call the block when simulating a different macOS version" do
      Homebrew::SimulateSystem.os = :monterey
      called = false
      host.on_ventura { called = true }
      expect(called).to be false
    end

    it "calls the block with :or_newer when current OS is newer" do
      Homebrew::SimulateSystem.os = :sonoma
      called = false
      host.on_ventura(:or_newer) { called = true }
      expect(called).to be true
    end

    it "does not call the block with :or_newer when current OS is older" do
      Homebrew::SimulateSystem.os = :monterey
      called = false
      host.on_ventura(:or_newer) { called = true }
      expect(called).to be false
    end

    it "calls the block with :or_older when current OS is older" do
      Homebrew::SimulateSystem.os = :monterey
      called = false
      host.on_ventura(:or_older) { called = true }
      expect(called).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # on_arch_conditional helper
  # ---------------------------------------------------------------------------
  describe "#on_arch_conditional" do
    it "returns the arm value on arm" do
      Homebrew::SimulateSystem.arch = :arm
      result = host.on_arch_conditional(arm: "apple", intel: "x86")
      expect(result).to eq "apple"
    end

    it "returns the intel value on intel" do
      Homebrew::SimulateSystem.arch = :intel
      result = host.on_arch_conditional(arm: "apple", intel: "x86")
      expect(result).to eq "x86"
    end
  end

  # ---------------------------------------------------------------------------
  # on_system_conditional helper
  # ---------------------------------------------------------------------------
  describe "#on_system_conditional" do
    it "returns the macos value on macOS" do
      Homebrew::SimulateSystem.os = :macos
      result = host.on_system_conditional(macos: "mac_value", linux: "linux_value")
      expect(result).to eq "mac_value"
    end

    it "returns the linux value on linux" do
      Homebrew::SimulateSystem.os = :linux
      result = host.on_system_conditional(macos: "mac_value", linux: "linux_value")
      expect(result).to eq "linux_value"
    end
  end
end
