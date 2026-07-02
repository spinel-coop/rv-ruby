require File.expand_path("../Abstract/rv-portable-formula", __dir__)

class RvRubyAT049 < Formula
  prepend RvPortableFormulaMixin
  keg_only "portable formulae are keg-only"
  desc "A working upgrade of the oldest extant ruby version"
  homepage "https://github.com/sampersand/ruby-0.49"
  version "0.49"
  url "https://github.com/sampersand/ruby-0.49/archive/refs/tags/v1.0.tar.gz"
  sha256 "88e011f60c6bb532c8e0787506a5ed518f31288bce749e1eb868febe290d83be"
  license "ruby"

  depends_on "bison" => :build

  def install
    Dir.chdir("fixed") do
      system "./configure", *std_configure_args
      system "make"
      system "mkdir", "-p", bin
      system "make install"
    end
  end

  test do
    system bin/"ruby", "--version"
  end
end
