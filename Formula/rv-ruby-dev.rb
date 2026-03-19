require File.expand_path("../Abstract/rv-ruby", __dir__)

class RvRubyDev < RvRuby
  head "https://github.com/ruby/ruby.git", branch: "master"

  depends_on "autoconf" => :build

  def install
    system "./autogen.sh"
    super

    # As of 2026-03-19, configure fails on intel with the error message
    #   configure: error: something wrong with LDFLAGS="-Wl,-search_paths_first"
    # So we're going to delete it, even though that worked in the last 30 daily builds.
    ENV.delete "LDFLAGS" if Hardware::CPU.intel?
  end

  def stable
    @head
  end
end
