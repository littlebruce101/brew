# frozen_string_literal: true

require "git_repository"

RSpec.describe GitRepository do
  subject(:repo) { described_class.new(Pathname(dir)) }

  let(:dir) { mktmpdir }

  def git(*args)
    system("git", "-C", dir, *args, out: File::NULL, err: File::NULL)
  end

  def git_init
    git("-c", "init.defaultBranch=main", "init")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test User")
  end

  def git_commit(message = "initial commit")
    FileUtils.touch(File.join(dir, "README"))
    git("add", "--all")
    git("commit", "--allow-empty", "-m", message)
  end

  describe "#git_repository?" do
    context "when the directory has a .git folder" do
      before do
        git_init
      end

      it "returns true" do
        expect(repo.git_repository?).to be true
      end
    end

    context "when the directory does not have a .git folder" do
      it "returns false" do
        expect(repo.git_repository?).to be false
      end
    end
  end

  describe "#origin_url" do
    before do
      git_init
      git("remote", "add", "origin", "https://github.com/example/repo.git")
    end

    it "returns the remote URL" do
      expect(repo.origin_url).to eq("https://github.com/example/repo.git")
    end

    context "when there is no remote" do
      before do
        git("remote", "remove", "origin")
      end

      it "returns nil" do
        expect(repo.origin_url).to be_nil
      end
    end

    context "when directory is not a git repo" do
      subject(:repo) { described_class.new(Pathname(mktmpdir)) }

      it "returns nil (safe: false by default)" do
        # popen_git returns nil when not a git repo (safe: false path)
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect(repo.origin_url).to be_nil
      end
    end
  end

  describe "#head_ref" do
    before do
      git_init
      git_commit
    end

    it "returns the full HEAD commit hash" do
      result = repo.head_ref
      expect(result).to match(/\A[0-9a-f]{40}\z/)
    end

    context "when directory is not a git repo" do
      subject(:repo) { described_class.new(Pathname(mktmpdir)) }

      it "returns nil when safe: false (default)" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect(repo.head_ref).to be_nil
      end

      it "raises when safe: true" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect { repo.head_ref(safe: true) }.to raise_error(RuntimeError, /Not a Git repository/)
      end
    end
  end

  describe "#branch_name" do
    before do
      git_init
      git_commit
    end

    it "returns the current branch name" do
      expect(repo.branch_name).to eq("main")
    end

    context "when directory is not a git repo" do
      subject(:repo) { described_class.new(Pathname(mktmpdir)) }

      it "returns nil by default" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect(repo.branch_name).to be_nil
      end
    end
  end

  describe "#origin_branch_name" do
    before do
      git_init
      git_commit
      git("remote", "add", "origin", "https://github.com/example/repo.git")
      # Simulate refs/remotes/origin/HEAD pointing to origin/main
      git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    end

    it "returns the default origin branch name" do
      expect(repo.origin_branch_name).to eq("main")
    end

    context "when no origin HEAD is set" do
      before do
        # Remove the symbolic ref if it was created
        git("update-ref", "-d", "refs/remotes/origin/HEAD")
      end

      it "returns nil" do
        expect(repo.origin_branch_name).to be_nil
      end
    end
  end

  describe "#default_origin_branch?" do
    before do
      git_init
      git_commit
      git("remote", "add", "origin", "https://github.com/example/repo.git")
      git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    end

    context "when current branch matches origin default" do
      it "returns true" do
        expect(repo.default_origin_branch?).to be true
      end
    end

    context "when current branch differs from origin default" do
      before do
        git("checkout", "-b", "other-branch", out: File::NULL, err: File::NULL)
      end

      it "returns false" do
        expect(repo.default_origin_branch?).to be false
      end
    end
  end
end
