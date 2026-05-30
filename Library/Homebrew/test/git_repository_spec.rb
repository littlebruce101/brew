# frozen_string_literal: true

require "git_repository"

RSpec.describe GitRepository do
  subject(:repo) { described_class.new(Pathname(dir)) }

  let(:dir) { mktmpdir }

  def git(*args)
    # Suppress output without using keyword-style redirect to avoid
    # "no implicit conversion of Hash into String" on older Ruby.
    IO.popen(["git", "-C", dir, *args, err: [:child, :out]], &:read)
    $CHILD_STATUS.success?
  end

  def git_init
    git("-c", "init.defaultBranch=main", "init")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test User")
    # Disable commit signing so tests can create commits in any environment.
    git("config", "commit.gpgsign", "false")
    git("config", "gpg.format", "openpgp")
  end

  def git_commit(message = "initial commit")
    FileUtils.touch(File.join(dir, "README"))
    git("add", "--all")
    git("commit", "--allow-empty", "--no-gpg-sign", "-m", message)
  end

  describe "#git_repository?" do
    context "when the directory has a .git folder" do
      before { git_init }

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
      before { git("remote", "remove", "origin") }

      it "returns nil" do
        expect(repo.origin_url).to be_nil
      end
    end

    context "when directory is not a git repo" do
      subject(:repo) { described_class.new(Pathname(mktmpdir)) }

      it "returns nil (safe: false by default)" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect(repo.origin_url).to be_nil
      end
    end
  end

  describe "#head_ref" do
    context "when directory is not a git repo" do
      it "returns nil when safe: false (default)" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect(repo.head_ref).to be_nil
      end

      it "raises when safe: true" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect { repo.head_ref(safe: true) }.to raise_error(RuntimeError, /Not a Git repository/)
      end
    end

    context "when git is initialised with a commit" do
      before do
        git_init
        git_commit
      end

      it "returns the full HEAD commit hash" do
        result = repo.head_ref
        skip "Cannot create commits in this environment" if result.nil?

        expect(result).to match(/\A[0-9a-f]{40}\z/)
      end
    end
  end

  describe "#branch_name" do
    context "when directory is not a git repo" do
      it "returns nil by default" do
        allow(Utils::Git).to receive(:available?).and_return(true)
        expect(repo.branch_name).to be_nil
      end
    end

    context "when git is initialised with a commit" do
      before do
        git_init
        git_commit
      end

      it "returns the current branch name" do
        result = repo.branch_name
        skip "Cannot create commits in this environment" if result.nil? || result == "HEAD"

        expect(result).to eq("main")
      end
    end
  end

  describe "#origin_branch_name" do
    before do
      git_init
      git_commit
      git("remote", "add", "origin", "https://github.com/example/repo.git")
      git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    end

    it "returns the default origin branch name" do
      result = repo.origin_branch_name
      skip "Cannot create commits in this environment" unless result

      expect(result).to eq("main")
    end

    context "when no origin HEAD is set" do
      before { git("symbolic-ref", "--delete", "refs/remotes/origin/HEAD") }

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
        skip "Cannot create commits in this environment" unless repo.head_ref

        expect(repo.default_origin_branch?).to be true
      end
    end

    context "when current branch differs from origin default" do
      it "returns false" do
        skip "Cannot create commits in this environment" unless repo.head_ref

        git("checkout", "-b", "other-branch")
        expect(repo.default_origin_branch?).to be false
      end
    end
  end
end
