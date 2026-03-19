require File.expand_path("../Abstract/rv-ruby", __dir__)

class RvRubyDev < RvRuby
  head "https://github.com/ruby/ruby.git", branch: "master"

  depends_on "autoconf" => :build

  def install
    system "./autogen.sh"
    super
  end

  def stable
    @head
  end
end
