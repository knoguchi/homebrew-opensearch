class OpensearchKnn < Formula
  desc "K-nearest neighbors (k-NN) plugin for OpenSearch"
  homepage "https://github.com/opensearch-project/k-NN"
  url "https://github.com/opensearch-project/k-NN/archive/refs/tags/3.2.0.0.tar.gz"
  sha256 "c0b3f7883953c8a576746f0ad0727b77448a046abe6f5e95bd04d0279839ef44"
  license "Apache-2.0"

  depends_on "gradle@8" => :build
  depends_on "openjdk@21" => :build
  depends_on "opensearch"

  def install
    ENV["JAVA_HOME"] = Formula["openjdk@21"].opt_prefix
    
    system "gradle", "bundlePlugin", "-x", "test", 
           "-PopensearchVersion=3.2.0"
    
    plugin_file = Dir["plugin/build/distributions/opensearch-knn-*.zip"].first
    raise "Plugin zip file not found" unless plugin_file
    libexec.install plugin_file => "plugin.zip"
  end

  def post_install
    opensearch = Formula["opensearch"]
    
    # Check if plugin is already installed
    plugin_list = `#{opensearch.bin}/opensearch-plugin list 2>/dev/null`.strip
    
    if plugin_list.include?("opensearch-knn")
      puts "==> opensearch-knn plugin already installed, updating..."
      system opensearch.bin/"opensearch-plugin", "remove", "opensearch-knn", :out => File::NULL, :err => File::NULL
    end
    
    system opensearch.bin/"opensearch-plugin", "install", "--batch",
           "file://#{libexec}/plugin.zip"
  end

  def caveats
    <<~EOS
      k-NN plugin has been installed.
      
      To use k-NN functionality, you may need to restart OpenSearch:
      brew services restart opensearch
      
      Verify plugin installation with: opensearch-plugin list
    EOS
  end

  test do
    opensearch = Formula["opensearch"]
    output = shell_output("#{opensearch.bin}/opensearch-plugin list")
    assert_match "opensearch-knn", output
  end
end