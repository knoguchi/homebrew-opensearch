class OpensearchMlCommons < Formula
  desc "Machine Learning plugin for OpenSearch"
  homepage "https://github.com/opensearch-project/ml-commons"
  url "https://github.com/opensearch-project/ml-commons/archive/refs/tags/3.2.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "Apache-2.0"

  depends_on "gradle@8" => :build
  depends_on "openjdk" => :build
  depends_on "opensearch"
  depends_on "opensearch-job-scheduler"  # Required plugin dependency

  # Apply patch for Intel Mac PyTorch compatibility
  patch :DATA if Hardware::CPU.intel?

  def install
    ENV["JAVA_HOME"] = Formula["openjdk"].opt_prefix
    
    system "gradle", "assemble", "-x", "test", 
           "-PopensearchVersion=3.2.0"
    
    plugin_file = Dir["build/distributions/opensearch-ml-*.zip"].first
    (libexec/"plugin.zip").install plugin_file
  end

  def post_install
    opensearch = Formula["opensearch"]
    system opensearch.bin/"opensearch-plugin", "install", "--batch",
           "file://#{libexec}/plugin.zip"
  end

  test do
    opensearch = Formula["opensearch"]
    output = shell_output("#{opensearch.bin}/opensearch-plugin list")
    assert_match "opensearch-ml", output
    assert_match "opensearch-job-scheduler", output
  end
end

__END__
diff --git a/ml-algorithms/build.gradle b/ml-algorithms/build.gradle
index abc123..def456 100644
--- a/ml-algorithms/build.gradle
+++ b/ml-algorithms/build.gradle
@@ -44,8 +44,8 @@ dependencies {
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

diff --git a/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java b/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java
index abc123..def456 100644
--- a/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java
+++ b/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModel.java
@@ -253,7 +253,7 @@ public class DLModel implements MLAlgoParams, Executable {
                 ClassLoader contextClassLoader = Thread.currentThread().getContextClassLoader();
                 try {
                     System.setProperty("PYTORCH_PRECXX11", "true");
-                    System.setProperty("PYTORCH_VERSION", "2.5.1");
+                    System.setProperty("PYTORCH_VERSION", "2.2.2");
                     System.setProperty("DJL_CACHE_DIR", mlEngine.getMlCachePath().toAbsolutePath().toString());
                     // DJL will read "/usr/java/packages/lib" if don't set "java.library.path". That will throw
                     // access denied exception

diff --git a/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java b/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java
index abc123..def456 100644
--- a/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java
+++ b/ml-algorithms/src/main/java/org/opensearch/ml/engine/algorithms/DLModelExecute.java
@@ -131,7 +131,7 @@ public class DLModelExecute implements MLAlgoParams, Executable {
             AccessController.doPrivileged((PrivilegedExceptionAction<Void>) () -> {
                 ClassLoader contextClassLoader = Thread.currentThread().getContextClassLoader();
                 try {
-                    System.setProperty("PYTORCH_VERSION", "2.5.1");
+                    System.setProperty("PYTORCH_VERSION", "2.2.2");
                     System.setProperty("DJL_CACHE_DIR", mlEngine.getMlCachePath().toAbsolutePath().toString());
                     // DJL will read "/usr/java/packages/lib" if don't set "java.library.path". That will throw
                     // access denied exception

diff --git a/common/build.gradle b/common/build.gradle
index abc123..def456 100644
--- a/common/build.gradle
+++ b/common/build.gradle
@@ -24,7 +24,7 @@ dependencies {
     testImplementation "org.opensearch.test:framework:${opensearch_version}"

     compileOnly group: 'org.apache.commons', name: 'commons-text', version: '1.10.0'
-    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     compileOnly group: 'org.json', name: 'json', version: '20231013'
     testImplementation group: 'org.json', name: 'json', version: '20231013'
     implementation('com.google.guava:guava:32.1.3-jre') {

diff --git a/memory/build.gradle b/memory/build.gradle
index abc123..def456 100644
--- a/memory/build.gradle
+++ b/memory/build.gradle
@@ -38,7 +38,7 @@ dependencies {
     testImplementation group: 'org.mockito', name: 'mockito-core', version: '5.15.2'
     testImplementation "org.opensearch.test:framework:${opensearch_version}"
     testImplementation "org.opensearch.client:opensearch-rest-client:${opensearch_version}"
-    testImplementation group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    testImplementation group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     testImplementation group: 'org.json', name: 'json', version: '20231013'
     testImplementation("com.fasterxml.jackson.core:jackson-annotations:${versions.jackson}")
     testImplementation("com.fasterxml.jackson.core:jackson-databind:${versions.jackson_databind}")

diff --git a/plugin/build.gradle b/plugin/build.gradle
index abc123..def456 100644
--- a/plugin/build.gradle
+++ b/plugin/build.gradle
@@ -83,7 +83,7 @@ dependencies {
     implementation (group: 'com.google.guava', name: 'guava', version: '32.1.3-jre') {
 	exclude group: 'com.google.errorprone', module: 'error_prone_annotations'
     }
-    implementation group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    implementation group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     implementation group: 'org.apache.commons', name: 'commons-lang3', version: "${versions.commonslang}"
     implementation group: 'org.apache.commons', name: 'commons-math3', version: '3.6.1'
     implementation group: 'org.apache.commons', name: 'commons-text', version: '1.10.0'

diff --git a/search-processors/build.gradle b/search-processors/build.gradle
index abc123..def456 100644
--- a/search-processors/build.gradle
+++ b/search-processors/build.gradle
@@ -30,7 +30,7 @@ repositories {
 dependencies {
     implementation project(path: ":${rootProject.name}-common", configuration: 'shadow')
     compileOnly group: 'org.opensearch', name: 'opensearch', version: "${opensearch_version}"
-    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.11.0'
+    compileOnly group: 'com.google.code.gson', name: 'gson', version: '2.10.1'
     implementation "org.apache.commons:commons-lang3:${versions.commonslang}"
     implementation project(':opensearch-ml-memory')
     implementation group: 'org.opensearch', name: 'common-utils', version: "${common_utils_version}"
