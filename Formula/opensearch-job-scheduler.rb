class OpensearchJobScheduler < Formula
  desc "Job Scheduler plugin for OpenSearch"
  homepage "https://github.com/opensearch-project/job-scheduler"
  url "https://github.com/opensearch-project/job-scheduler/archive/refs/tags/3.2.0.0.tar.gz"
  sha256 "ca09e5c928bfdcac819484094de6b841796aeef76a947011c73d10727fa0533c"
  license "Apache-2.0"

  depends_on "gradle@8" => :build
  depends_on "openjdk@21" => :build
  depends_on "opensearch"  # Runtime dependency

  def install
    ENV["JAVA_HOME"] = Formula["openjdk@21"].opt_prefix
    
    system "gradle", "bundlePlugin", "-x", "test", 
           "-PopensearchVersion=3.2.0"
    
    plugin_file = Dir["build/distributions/opensearch-job-scheduler-*.zip"].first
    raise "Plugin zip file not found" unless plugin_file
    libexec.install plugin_file => "plugin.zip"
  end

  def post_install
    opensearch = Formula["opensearch"]
    
    # Check if plugin is already installed
    plugin_list = `#{opensearch.bin}/opensearch-plugin list 2>/dev/null`.strip
    
    if plugin_list.include?("opensearch-job-scheduler")
      puts "==> opensearch-job-scheduler plugin already installed, updating..."
      system opensearch.bin/"opensearch-plugin", "remove", "opensearch-job-scheduler", :out => File::NULL, :err => File::NULL
    end
    
    system opensearch.bin/"opensearch-plugin", "install", "--batch",
           "file://#{libexec}/plugin.zip"
  end

  test do
    opensearch = Formula["opensearch"]
    output = shell_output("#{opensearch.bin}/opensearch-plugin list")
    assert_match "opensearch-job-scheduler", output
  end

  def caveats
    "Run 'opensearch-plugin list' to verify installation"
  end
end
