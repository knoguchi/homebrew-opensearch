class OpensearchJobScheduler < Formula
  desc "Job Scheduler plugin for OpenSearch"
  homepage "https://github.com/opensearch-project/job-scheduler"
  url "https://github.com/opensearch-project/job-scheduler/archive/refs/tags/3.2.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "Apache-2.0"

  depends_on "gradle@8" => :build
  depends_on "openjdk" => :build
  depends_on "opensearch"  # Runtime dependency

  def install
    ENV["JAVA_HOME"] = Formula["openjdk"].opt_prefix
    
    system "gradle", "assemble", "-x", "test", 
           "-PopensearchVersion=3.2.0"
    
    plugin_file = Dir["build/distributions/opensearch-job-scheduler-*.zip"].first
    (libexec/"plugin.zip").install plugin_file
  end

  def post_install
    opensearch = Formula["opensearch"]
    system opensearch.bin/"opensearch-plugin", "install", "--batch",
           "file://#{libexec}/plugin.zip"
  end

  def caveats
    "Run 'opensearch-plugin list' to verify installation"
  end
end
