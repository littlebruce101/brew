# frozen_string_literal: true

require "download_strategy"

RSpec.describe DownloadStrategyDetector do
  describe ".detect" do
    it "delegates to detect_from_url when using is nil" do
      expect(described_class.detect("https://example.com/foo.tar.gz")).to eq(CurlDownloadStrategy)
    end

    it "returns the class directly when using is a subclass of AbstractDownloadStrategy" do
      expect(described_class.detect("https://example.com/foo", NoUnzipCurlDownloadStrategy))
        .to eq(NoUnzipCurlDownloadStrategy)
    end

    it "delegates to detect_from_symbol when using is a symbol" do
      expect(described_class.detect("https://example.com/foo", :nounzip)).to eq(NoUnzipCurlDownloadStrategy)
    end

    it "raises TypeError for an unknown using value" do
      expect { described_class.detect("https://example.com/foo", 42) }
        .to raise_error(TypeError, /Unknown download strategy specification/)
    end
  end

  describe ".detect_from_url" do
    it "detects CurlDownloadStrategy for a plain HTTPS URL" do
      expect(described_class.detect_from_url("https://example.com/file.tar.gz")).to eq(CurlDownloadStrategy)
    end

    it "detects CurlDownloadStrategy for a plain HTTP URL" do
      expect(described_class.detect_from_url("http://example.com/archive.zip")).to eq(CurlDownloadStrategy)
    end

    it "detects GitDownloadStrategy for a .git HTTPS URL" do
      expect(described_class.detect_from_url("https://example.com/repo.git")).to eq(GitDownloadStrategy)
    end

    it "detects GitDownloadStrategy for a git:// URL" do
      expect(described_class.detect_from_url("git://example.com/repo")).to eq(GitDownloadStrategy)
    end

    it "detects GitHubGitDownloadStrategy for a GitHub .git URL" do
      expect(described_class.detect_from_url("https://github.com/owner/repo.git"))
        .to eq(GitHubGitDownloadStrategy)
    end

    it "detects SubversionDownloadStrategy for an svn:// URL" do
      expect(described_class.detect_from_url("svn://example.com/repo")).to eq(SubversionDownloadStrategy)
    end

    it "detects SubversionDownloadStrategy for an svn+http:// URL" do
      expect(described_class.detect_from_url("svn+http://example.com/repo")).to eq(SubversionDownloadStrategy)
    end

    it "detects CVSDownloadStrategy for a cvs:// URL" do
      expect(described_class.detect_from_url("cvs://example.com/repo")).to eq(CVSDownloadStrategy)
    end

    it "detects MercurialDownloadStrategy for an hg:// URL" do
      expect(described_class.detect_from_url("hg://example.com/repo")).to eq(MercurialDownloadStrategy)
    end

    it "detects BazaarDownloadStrategy for a bzr:// URL" do
      expect(described_class.detect_from_url("bzr://example.com/repo")).to eq(BazaarDownloadStrategy)
    end

    it "detects FossilDownloadStrategy for a fossil:// URL" do
      expect(described_class.detect_from_url("fossil://example.com/repo")).to eq(FossilDownloadStrategy)
    end

    it "detects CurlApacheMirrorDownloadStrategy for an Apache closer.cgi URL" do
      expect(described_class.detect_from_url("https://www.apache.org/dyn/closer.cgi/project/1.0.tar.gz"))
        .to eq(CurlApacheMirrorDownloadStrategy)
    end

    it "detects CurlApacheMirrorDownloadStrategy for an Apache closer.lua URL" do
      expect(described_class.detect_from_url("https://www.apache.org/dyn/closer.lua/project/1.0.tar.gz"))
        .to eq(CurlApacheMirrorDownloadStrategy)
    end
  end

  describe ".detect_from_symbol" do
    {
      hg:             MercurialDownloadStrategy,
      nounzip:        NoUnzipCurlDownloadStrategy,
      git:            GitDownloadStrategy,
      bzr:            BazaarDownloadStrategy,
      svn:            SubversionDownloadStrategy,
      curl:           CurlDownloadStrategy,
      homebrew_curl:  HomebrewCurlDownloadStrategy,
      cvs:            CVSDownloadStrategy,
      post:           CurlPostDownloadStrategy,
      fossil:         FossilDownloadStrategy,
    }.each do |symbol, klass|
      it "maps :#{symbol} to #{klass}" do
        expect(described_class.detect_from_symbol(symbol)).to eq(klass)
      end
    end

    it "raises TypeError for an unknown symbol" do
      expect { described_class.detect_from_symbol(:unknown_vcs) }
        .to raise_error(TypeError, /Unknown download strategy/)
    end
  end
end

RSpec.describe AbstractFileDownloadStrategy do
  let(:cache_dir) { mktmpdir }
  let(:strategy) do
    described_class.new("https://example.com/foo-1.0.tar.gz", "foo", "1.0", cache: cache_dir)
  end

  # AbstractFileDownloadStrategy is abstract; use a concrete subclass for instantiation.
  let(:described_class) { CurlDownloadStrategy }

  describe "#temporary_path" do
    it "appends .incomplete to the cached_location path" do
      expect(strategy.temporary_path.to_s).to end_with(".incomplete")
    end
  end

  describe "#cached_location" do
    it "returns a Pathname under the downloads subdirectory of the cache" do
      expect(strategy.cached_location.to_s).to include((cache_dir/"downloads").to_s)
    end

    it "encodes the URL as a SHA-256 prefix in the filename" do
      sha = Digest::SHA256.hexdigest("https://example.com/foo-1.0.tar.gz")
      expect(strategy.cached_location.basename.to_s).to start_with(sha)
    end

    it "returns the same object on repeated calls (memoised)" do
      expect(strategy.cached_location).to equal(strategy.cached_location)
    end
  end

  describe "#symlink_location" do
    it "preserves the original file extension" do
      expect(strategy.symlink_location.to_s).to end_with(".tar.gz")
    end

    it "includes the name and version" do
      expect(strategy.symlink_location.basename.to_s).to include("foo")
      expect(strategy.symlink_location.basename.to_s).to include("1.0")
    end
  end

  describe "#clear_cache" do
    it "removes cached_location when it exists" do
      loc = strategy.cached_location
      loc.dirname.mkpath
      loc.write("data")
      strategy.clear_cache
      expect(loc).not_to exist
    end

    it "also removes the .incomplete file" do
      tmp = strategy.temporary_path
      tmp.dirname.mkpath
      tmp.write("partial")
      strategy.clear_cache
      expect(tmp).not_to exist
    end

    it "does not raise when nothing is cached" do
      expect { strategy.clear_cache }.not_to raise_error
    end
  end

  describe "#quiet!" do
    it "makes quiet? return true" do
      expect { strategy.quiet! }.to change(strategy, :quiet?).from(false).to(true)
    end
  end
end

RSpec.describe AbstractFileDownloadStrategy, "#parse_basename (private)" do
  let(:strategy) { CurlDownloadStrategy.new("https://example.com/foo.tar.gz", "foo", "1.0") }

  def parse(url, **opts)
    strategy.send(:parse_basename, url, **opts)
  end

  it "returns the filename from a plain URL" do
    expect(parse("https://example.com/foo-1.0.tar.gz")).to eq("foo-1.0.tar.gz")
  end

  it "returns the last path component" do
    expect(parse("https://example.com/path/to/archive.zip")).to eq("archive.zip")
  end

  it "prefers query param filename when present and has an extension" do
    url = "https://example.com/download?file=foo-1.0.tar.gz"
    expect(parse(url)).to eq("foo-1.0.tar.gz")
  end

  it "extracts filename from response-content-disposition query parameter" do
    url = "https://s3.example.com/bucket?response-content-disposition=attachment%3B+filename%3Dfoo-1.2.tar.bz2"
    result = parse(url)
    expect(result).to include("foo-1.2.tar.bz2")
  end

  it "falls back to the path component when query has no extension" do
    expect(parse("https://example.com/download.php?id=42")).to eq("download.php")
  end
end

RSpec.describe CurlDownloadStrategy do
  let(:cache_dir) { mktmpdir }

  describe "#mirrors" do
    it "returns an empty array when no mirrors are given" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0", cache: cache_dir)
      expect(strategy.mirrors).to eq([])
    end

    it "returns the provided mirrors" do
      mirrors = ["https://mirror1.example.com/foo.tar.gz", "https://mirror2.example.com/foo.tar.gz"]
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0",
                                     mirrors:, cache: cache_dir)
      expect(strategy.mirrors).to eq(mirrors)
    end
  end

  describe "#_curl_args (private)" do
    it "returns empty array with no special options" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0", cache: cache_dir)
      expect(strategy.send(:_curl_args)).to eq([])
    end

    it "includes cookie header when :cookies meta key present" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0",
                                     cookies: { "session" => "abc123" }, cache: cache_dir)
      args = strategy.send(:_curl_args)
      expect(args).to include("-b")
      expect(args.join(" ")).to include("session=abc123")
    end

    it "includes referer header when :referer meta key present" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0",
                                     referer: "https://referrer.example.com", cache: cache_dir)
      args = strategy.send(:_curl_args)
      expect(args).to include("-e", "https://referrer.example.com")
    end

    it "includes --user option when :user meta key present" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0",
                                     user: "admin:secret", cache: cache_dir)
      args = strategy.send(:_curl_args)
      expect(args).to include("--user", "admin:secret")
    end

    it "includes custom headers when :headers meta key present" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0",
                                     headers: ["X-Api-Key: token123"], cache: cache_dir)
      args = strategy.send(:_curl_args)
      expect(args).to include("--header", "X-Api-Key: token123")
    end

    it "merges :header (singular) into :headers" do
      strategy = described_class.new("https://example.com/foo.tar.gz", "foo", "1.0",
                                     header: "X-Token: abc", cache: cache_dir)
      args = strategy.send(:_curl_args)
      expect(args).to include("--header", "X-Token: abc")
    end
  end
end

RSpec.describe LocalBottleDownloadStrategy do
  let(:path) { mktmpdir/"bottle-1.0.tar.gz" }

  before { path.write("bottle content") }

  describe "#cached_location" do
    it "returns the path passed to the constructor" do
      strategy = described_class.new(path)
      expect(strategy.cached_location).to eq(path)
    end
  end

  describe "#clear_cache" do
    it "does not delete the file (local paths are not managed)" do
      strategy = described_class.new(path)
      strategy.clear_cache
      expect(path).to exist
    end
  end
end

RSpec.describe VCSDownloadStrategy do
  # Use GitDownloadStrategy as a concrete stand-in for the abstract VCSDownloadStrategy
  let(:described_class) { GitDownloadStrategy }

  describe "#extract_ref (private)" do
    it "returns [:tag, value] when :tag is in meta" do
      strategy = described_class.new("https://example.com/repo.git", "repo", "1.0", tag: "v1.0")
      expect(strategy.send(:extract_ref, { tag: "v1.0" })).to eq([:tag, "v1.0"])
    end

    it "returns [:branch, value] when :branch is in meta" do
      strategy = described_class.new("https://example.com/repo.git", "repo", "HEAD", branch: "main")
      expect(strategy.send(:extract_ref, { branch: "main" })).to eq([:branch, "main"])
    end

    it "returns [:revision, value] when :revision is in meta" do
      strategy = described_class.new("https://example.com/repo.git", "repo", "HEAD", revision: "abc123")
      expect(strategy.send(:extract_ref, { revision: "abc123" })).to eq([:revision, "abc123"])
    end

    it "returns [nil, nil] when no ref type is present" do
      strategy = described_class.new("https://example.com/repo.git", "repo", "HEAD")
      expect(strategy.send(:extract_ref, {})).to eq([nil, nil])
    end
  end
end
