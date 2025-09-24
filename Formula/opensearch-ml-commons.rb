class OpensearchMlCommons < Formula
  desc "Machine Learning plugin for OpenSearch"
  homepage "https://github.com/opensearch-project/ml-commons"
  url "https://github.com/opensearch-project/ml-commons/archive/refs/tags/3.2.0.0.tar.gz"
  sha256 "0809225da8b0556021a38ae50aed15028da785d4681524c23b4072cda600a1ea"
  license "Apache-2.0"

  depends_on "gradle@8" => :build
  depends_on "openjdk@21" => :build
  depends_on "opensearch"
  depends_on "opensearch-job-scheduler"  # Required plugin dependency

  # Apply patch for Intel Mac PyTorch compatibility
  patch :DATA if Hardware::CPU.intel?

  def install
    ENV["JAVA_HOME"] = Formula["openjdk@21"].opt_prefix
    
    system "gradle", "bundlePlugin", "-x", "test", 
           "-PopensearchVersion=3.2.0"
    
    plugin_file = Dir["plugin/build/distributions/opensearch-ml-*.zip"].first
    raise "Plugin zip file not found" unless plugin_file
    libexec.install plugin_file => "plugin.zip"
  end

  def post_install
    opensearch = Formula["opensearch"]
    
    # Check if plugin is already installed
    plugin_list = `#{opensearch.bin}/opensearch-plugin list 2>/dev/null`.strip
    
    if plugin_list.include?("opensearch-ml")
      puts "==> opensearch-ml plugin already installed, updating..."
      system opensearch.bin/"opensearch-plugin", "remove", "opensearch-ml", :out => File::NULL, :err => File::NULL
    end
    
    system opensearch.bin/"opensearch-plugin", "install", "--batch",
           "file://#{libexec}/plugin.zip"
  end

  def caveats
    <<~EOS
      ML Commons plugin has been installed.
      
      To install and configure ML models automatically (includes memory setup):
      brew install knoguchi/opensearch/opensearch-ml-models
      
      Or manually configure ML Commons by starting OpenSearch and following:
      https://opensearch.org/docs/latest/ml-commons-plugin/pretrained-models/
      
      Note: ML models require 4GB heap memory. The models formula handles this automatically.
      
      Verify plugin installation with: opensearch-plugin list
    EOS
  end

  test do
    opensearch = Formula["opensearch"]
    output = shell_output("#{opensearch.bin}/opensearch-plugin list")
    assert_match "opensearch-ml", output
    assert_match "opensearch-job-scheduler", output
  end
end

__END__
diff -u -r ml-commons-3.2.0.0/common/build.gradle ml-commons-3.2.0.0-patched/common/build.gradle
--- ml-commons-3.2.0.0/common/build.gradle	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/common/build.gradle	2025-09-24 13:51:11.033712330 -0700
@@ -24,7 +24,7 @@
     testImplementation "org.opensearch.test:framework:${opensearch_version}"
 
     compileOnly group: 'org.apache.commons', name: 'commons-text', version: '1.10.0'
-    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     compileOnly group: 'org.json', name: 'json', version: '20231013'
     testImplementation group: 'org.json', name: 'json', version: '20231013'
     implementation('com.google.guava:guava:32.1.3-jre') {
diff -u -r ml-commons-3.2.0.0/memory/build.gradle ml-commons-3.2.0.0-patched/memory/build.gradle
--- ml-commons-3.2.0.0/memory/build.gradle	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/memory/build.gradle	2025-09-24 13:51:30.261864315 -0700
@@ -38,7 +38,7 @@
     testImplementation group: 'org.mockito', name: 'mockito-core', version: '5.15.2'
     testImplementation "org.opensearch.test:framework:${opensearch_version}"
     testImplementation "org.opensearch.client:opensearch-rest-client:${opensearch_version}"
-    testImplementation group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    testImplementation group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     testImplementation group: 'org.json', name: 'json', version: '20231013'
     testImplementation("com.fasterxml.jackson.core:jackson-annotations:${versions.jackson}")
     testImplementation("com.fasterxml.jackson.core:jackson-databind:${versions.jackson_databind}")
diff -u -r ml-commons-3.2.0.0/ml-algorithms/build.gradle ml-commons-3.2.0.0-patched/ml-algorithms/build.gradle
--- ml-commons-3.2.0.0/ml-algorithms/build.gradle	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/ml-algorithms/build.gradle	2025-09-24 13:50:13.829947903 -0700
@@ -44,8 +44,8 @@
     implementation (group: 'com.google.guava', name: 'guava', version: '32.1.3-jre') {
 	exclude group: 'com.google.errorprone', module: 'error_prone_annotations'
     }
-    implementation group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
-    implementation platform("ai.djl:bom:0.31.1")
+    implementation group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
+    implementation platform("ai.djl:bom:0.28.0")
     implementation group: 'ai.djl.pytorch', name: 'pytorch-model-zoo'
     implementation group: 'ai.djl', name: 'api'
     implementation group: 'ai.djl.huggingface', name: 'tokenizers'
diff -u -r ml-commons-3.2.0.0/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java ml-commons-3.2.0.0-patched/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java
--- ml-commons-3.2.0.0/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java	2025-09-24 13:50:30.252154598 -0700
@@ -253,7 +253,7 @@
                 ClassLoader contextClassLoader = Thread.currentThread().getContextClassLoader();
                 try {
                     System.setProperty("PYTORCH_PRECXX11", "true");
-                    System.setProperty("PYTORCH_VERSION", "2.5.1");
+                    System.setProperty("PYTORCH_VERSION", "2.2.2");
                     System.setProperty("DJL_CACHE_DIR", mlEngine.getMlCachePath().toAbsolutePath().toString());
                     // DJL will read "/usr/java/packages/lib" if don't set "java.library.path". That will throw
                     // access denied exception
diff -u -r ml-commons-3.2.0.0/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java ml-commons-3.2.0.0-patched/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java
--- ml-commons-3.2.0.0/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java	2025-09-24 13:50:47.343244395 -0700
@@ -131,7 +131,7 @@
                 ClassLoader contextClassLoader = Thread.currentThread().getContextClassLoader();
                 try {
                     System.setProperty("PYTORCH_PRECXX11", "true");
-                    System.setProperty("PYTORCH_VERSION", "2.5.1");
+                    System.setProperty("PYTORCH_VERSION", "2.2.2");
                     System.setProperty("DJL_CACHE_DIR", mlEngine.getMlCachePath().toAbsolutePath().toString());
                     // DJL will read "/usr/java/packages/lib" if don't set "java.library.path". That will throw
                     // access denied exception
diff -u -r ml-commons-3.2.0.0/plugin/build.gradle ml-commons-3.2.0.0-patched/plugin/build.gradle
--- ml-commons-3.2.0.0/plugin/build.gradle	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/plugin/build.gradle	2025-09-24 13:51:51.091447357 -0700
@@ -83,7 +83,7 @@
     implementation (group: 'com.google.guava', name: 'guava', version: '32.1.3-jre') {
 	exclude group: 'com.google.errorprone', module: 'error_prone_annotations'
     }
-    implementation group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    implementation group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     implementation group: 'org.apache.commons', name: 'commons-lang3', version: "${versions.commonslang}"
     implementation group: 'org.apache.commons', name: 'commons-math3', version: '3.6.1'
     implementation group: 'org.apache.commons', name: 'commons-text', version: '1.10.0'
diff -u -r ml-commons-3.2.0.0/search-processors/build.gradle ml-commons-3.2.0.0-patched/search-processors/build.gradle
--- ml-commons-3.2.0.0/search-processors/build.gradle	2025-08-13 20:08:51.000000000 -0700
+++ ml-commons-3.2.0.0-patched/search-processors/build.gradle	2025-09-24 13:52:12.803457297 -0700
@@ -30,7 +30,7 @@
 dependencies {
     implementation project(path: ":${rootProject.name}-common", configuration: 'shadow')
     compileOnly group: 'org.opensearch', name: 'opensearch', version: "${opensearch_version}"
-    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     implementation "org.apache.commons:commons-lang3:${versions.commonslang}"
     implementation project(':opensearch-ml-memory')
     implementation group: 'org.opensearch', name: 'common-utils', version: "${common_utils_version}"
