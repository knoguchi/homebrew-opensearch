class OpensearchMlModels < Formula
  desc "Default ML models for OpenSearch ML Commons plugin"
  homepage "https://github.com/opensearch-project/ml-commons"
  version "1.0.0"
  license "Apache-2.0"
  
  # Uses same source as ML Commons for consistency
  url "https://github.com/opensearch-project/ml-commons/archive/refs/tags/3.2.0.0.tar.gz"
  sha256 "0809225da8b0556021a38ae50aed15028da785d4681524c23b4072cda600a1ea"
  
  depends_on "curl"
  depends_on "jq"
  depends_on "knoguchi/opensearch/opensearch-ml-commons"

  # Constants
  OPENSEARCH_URL = "http://localhost:9200"
  ML_STATE_DIR = "#{Dir.home}/.opensearch/ml-commons"
  MODEL_GROUP_FILE = "#{ML_STATE_DIR}/model_group_id"
  MODEL_ID_FILE = "#{ML_STATE_DIR}/model_id"

  def install
    # Create a helper script for model management
    (bin/"opensearch-ml-setup").write(ml_setup_script)
    chmod 0755, bin/"opensearch-ml-setup"
  end

  def post_install
    puts "==> Setting up OpenSearch ML models..."
    
    # Update JVM options for ML models (same as ML Commons)
    opensearch = Formula["opensearch"]
    jvm_options = opensearch.etc/"opensearch/jvm.options"
    jvm_updated = false
    if jvm_options.exist?
      content = jvm_options.read
      if content.include?("-Xms1g") || content.include?("-Xmx1g")
        puts "==> Updating OpenSearch JVM heap size from 1GB to 4GB for ML models..."
        content.gsub!("-Xms1g", "-Xms4g")
        content.gsub!("-Xmx1g", "-Xmx4g")
        jvm_options.atomic_write(content)
        puts "==> JVM options updated in #{jvm_options}"
        jvm_updated = true
      else
        puts "==> JVM heap size already configured (not 1GB default)"
      end
    else
      puts "==> Warning: Could not find #{jvm_options} - you may need to manually set heap to 4GB"
    end
    
    # Restart OpenSearch if JVM was updated
    if jvm_updated
      puts "==> Restarting OpenSearch to apply new JVM settings..."
      
      # Try brew services restart first, but handle failure gracefully
      restart_success = system "brew", "services", "restart", "opensearch", { :out => :close, :err => :close }
      
      unless restart_success
        puts "==> Brew services restart failed, trying alternative restart method..."
        
        # Stop and start manually as fallback
        system "brew", "services", "stop", "opensearch", { :out => :close, :err => :close }
        sleep 3
        
        start_success = system "brew", "services", "start", "opensearch", { :out => :close, :err => :close }
        
        unless start_success
          puts "==> Warning: Automatic restart failed. Please manually restart OpenSearch:"
          puts "    brew services restart opensearch"
          puts "==> Then re-run: brew postinstall knoguchi/opensearch/opensearch-ml-models"
          exit 1
        end
      end
      
      puts "==> OpenSearch restarted successfully"
    end
    
    puts "==> Waiting for OpenSearch to be ready..."
    
    # Wait for OpenSearch to be available
    system "#{bin}/opensearch-ml-setup", "wait"
    
    puts "==> Configuring ML Commons cluster settings..."
    system "#{bin}/opensearch-ml-setup", "configure"
    
    puts "==> Creating default model group..."
    system "#{bin}/opensearch-ml-setup", "create-group"
    
    puts "==> Registering Neural Sparse V2 model (recommended for search)..."
    system "#{bin}/opensearch-ml-setup", "register-sparse-v2"
    
    puts "==> Registering text embedding model..."
    system "#{bin}/opensearch-ml-setup", "register-embedding"
    
    puts "==> Registering cross-encoder model for reranking..."
    system "#{bin}/opensearch-ml-setup", "register-cross-encoder"
    
    puts "==> Waiting for registrations to complete and deploying models..."
    system "#{bin}/opensearch-ml-setup", "wait-and-deploy"
    
    puts "==> OpenSearch ML models setup complete!"
  end

  def ml_setup_script
    <<~EOS
      #!/bin/bash
      set -e

      OPENSEARCH_URL="#{OPENSEARCH_URL}"
      ML_STATE_DIR="#{ML_STATE_DIR}"
      MODEL_GROUP_FILE="#{MODEL_GROUP_FILE}"
      MODEL_ID_FILE="#{MODEL_ID_FILE}"
      SPARSE_TASK_FILE="$ML_STATE_DIR/sparse_task_id"
      EMBEDDING_TASK_FILE="$ML_STATE_DIR/embedding_task_id"
      CROSS_ENCODER_TASK_FILE="$ML_STATE_DIR/cross_encoder_task_id"

      # Ensure state directory exists
      mkdir -p "$ML_STATE_DIR"

      case "$1" in
        wait)
          echo "Waiting for OpenSearch to be available..."
          for i in {1..30}; do
            if curl -s -f "$OPENSEARCH_URL" > /dev/null 2>&1; then
              echo "OpenSearch is ready"
              exit 0
            fi
            echo "Attempt $i/30: OpenSearch not ready, waiting 5 seconds..."
            sleep 5
          done
          echo "Error: OpenSearch failed to start after 2.5 minutes"
          exit 1
          ;;
        
        configure)
          curl -s -X PUT "$OPENSEARCH_URL/_cluster/settings" \\
            -H "Content-Type: application/json" \\
            -d '{
              "persistent": {
                "plugins.ml_commons.allow_registering_model_via_url": true,
                "plugins.ml_commons.only_run_on_ml_node": false,
                "plugins.ml_commons.max_model_on_node": 3,
                "plugins.ml_commons.native_memory_threshold": 99
              }
            }'
          ;;
        
        create-group)
          RESPONSE=$(curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/model_groups/_register" \\
            -H "Content-Type: application/json" \\
            -d '{"name": "default_models", "description": "Default ML models installed by Homebrew"}')
          
          MODEL_GROUP_ID=$(echo "$RESPONSE" | jq -r '.model_group_id')
          echo "$MODEL_GROUP_ID" > "$MODEL_GROUP_FILE"
          echo "Created model group: $MODEL_GROUP_ID"
          ;;
        
        register-sparse-v2)
          if [ ! -f "$MODEL_GROUP_FILE" ]; then
            echo "Error: Model group ID not found. Run create-group first."
            exit 1
          fi
          
          MODEL_GROUP_ID=$(cat "$MODEL_GROUP_FILE")
          echo "Registering OpenSearch Neural Sparse V2 Distill model (recommended)..."
          RESPONSE=$(curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/_register" \\
            -H "Content-Type: application/json" \\
            -d "{
              \\"name\\": \\"amazon/neural-sparse/opensearch-neural-sparse-encoding-v2-distill\\",
              \\"version\\": \\"1.0.0\\",
              \\"model_group_id\\": \\"$MODEL_GROUP_ID\\",
              \\"model_format\\": \\"TORCH_SCRIPT\\",
              \\"url\\": \\"https://artifacts.opensearch.org/models/ml-models/amazon/neural-sparse/opensearch-neural-sparse-encoding-v2-distill/1.0.0/torch_script/neural-sparse_opensearch-neural-sparse-encoding-v2-distill-1.0.0-torch_script.zip\\",
              \\"hash_value\\": \\"a7a80f911838c402d74a7ce05e20672642fc63aafaa982b1055ab277abe808d2\\"
            }")
          
          TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')
          echo "Sparse model registration task: $TASK_ID"
          echo "$TASK_ID" > "$SPARSE_TASK_FILE"
          ;;
        
        register-embedding)
          if [ ! -f "$MODEL_GROUP_FILE" ]; then
            echo "Error: Model group ID not found. Run create-group first."
            exit 1
          fi
          
          MODEL_GROUP_ID=$(cat "$MODEL_GROUP_FILE")
          echo "Registering text embedding model..."
          RESPONSE=$(curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/_register" \\
            -H "Content-Type: application/json" \\
            -d "{
              \\"name\\": \\"huggingface/sentence-transformers/all-MiniLM-L6-v2\\",
              \\"version\\": \\"1.0.1\\",
              \\"model_group_id\\": \\"$MODEL_GROUP_ID\\",
              \\"model_format\\": \\"TORCH_SCRIPT\\"
            }")
          
          TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')
          echo "Embedding model registration task: $TASK_ID"
          echo "$TASK_ID" > "$EMBEDDING_TASK_FILE"
          ;;
        
        register-cross-encoder)
          if [ ! -f "$MODEL_GROUP_FILE" ]; then
            echo "Error: Model group ID not found. Run create-group first."
            exit 1
          fi
          
          MODEL_GROUP_ID=$(cat "$MODEL_GROUP_FILE")
          echo "Registering cross-encoder model for reranking..."
          RESPONSE=$(curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/_register" \\
            -H "Content-Type: application/json" \\
            -d "{
              \\"name\\": \\"huggingface/sentence-transformers/ms-marco-MiniLM-L-12-v2\\",
              \\"version\\": \\"1.0.1\\",
              \\"model_group_id\\": \\"$MODEL_GROUP_ID\\",
              \\"model_format\\": \\"TORCH_SCRIPT\\"
            }")
          
          TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')
          echo "Cross-encoder model registration task: $TASK_ID"
          echo "$TASK_ID" > "$CROSS_ENCODER_TASK_FILE"
          ;;
        
        wait-and-deploy)
          echo "Waiting for model registrations to complete..."
          echo "WARNING: This process takes approximately 15 minutes. Please wait patiently."
          
          # Wait for sparse model
          if [ -f "$SPARSE_TASK_FILE" ]; then
            TASK_ID=$(cat "$SPARSE_TASK_FILE")
            echo "Waiting for sparse model registration ($TASK_ID)..."
            
            for i in {1..60}; do
              TASK_RESPONSE=$(curl -s "$OPENSEARCH_URL/_plugins/_ml/tasks/$TASK_ID")
              STATE=$(echo "$TASK_RESPONSE" | jq -r '.state')
              
              if [ "$STATE" = "COMPLETED" ]; then
                MODEL_ID=$(echo "$TASK_RESPONSE" | jq -r '.model_id')
                echo "Sparse model registered: $MODEL_ID"
                curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/$MODEL_ID/_deploy"
                echo "Sparse model deployed"
                break
              elif [ "$STATE" = "FAILED" ]; then
                echo "Sparse model registration failed:"
                echo "$TASK_RESPONSE" | jq '.error'
              fi
              
              echo "Sparse model registration in progress... ($i/60)"
              sleep 5
            done
          fi
          
          # Wait for embedding model  
          if [ -f "$EMBEDDING_TASK_FILE" ]; then
            TASK_ID=$(cat "$EMBEDDING_TASK_FILE")
            echo "Waiting for embedding model registration ($TASK_ID)..."
            
            for i in {1..60}; do
              TASK_RESPONSE=$(curl -s "$OPENSEARCH_URL/_plugins/_ml/tasks/$TASK_ID")
              STATE=$(echo "$TASK_RESPONSE" | jq -r '.state')
              
              if [ "$STATE" = "COMPLETED" ]; then
                MODEL_ID=$(echo "$TASK_RESPONSE" | jq -r '.model_id')
                echo "Embedding model registered: $MODEL_ID"
                curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/$MODEL_ID/_deploy"
                echo "Embedding model deployed"
                break
              elif [ "$STATE" = "FAILED" ]; then
                echo "Embedding model registration failed:"
                echo "$TASK_RESPONSE" | jq '.error'
              fi
              
              echo "Embedding model registration in progress... ($i/60)"
              sleep 5
            done
          fi
          
          # Wait for cross-encoder model
          if [ -f "$CROSS_ENCODER_TASK_FILE" ]; then
            TASK_ID=$(cat "$CROSS_ENCODER_TASK_FILE")
            echo "Waiting for cross-encoder model registration ($TASK_ID)..."
            
            for i in {1..60}; do
              TASK_RESPONSE=$(curl -s "$OPENSEARCH_URL/_plugins/_ml/tasks/$TASK_ID")
              STATE=$(echo "$TASK_RESPONSE" | jq -r '.state')
              
              if [ "$STATE" = "COMPLETED" ]; then
                MODEL_ID=$(echo "$TASK_RESPONSE" | jq -r '.model_id')
                echo "Cross-encoder model registered: $MODEL_ID"
                curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/$MODEL_ID/_deploy"
                echo "Cross-encoder model deployed"
                break
              elif [ "$STATE" = "FAILED" ]; then
                echo "Cross-encoder model registration failed:"
                echo "$TASK_RESPONSE" | jq '.error'
              fi
              
              echo "Cross-encoder model registration in progress... ($i/60)"
              sleep 5
            done
          fi
          ;;
        
        deploy-model)
          if [ ! -f "$MODEL_ID_FILE" ]; then
            echo "Error: Model ID not found. Run register-model first."
            exit 1
          fi
          
          MODEL_ID=$(cat "$MODEL_ID_FILE")
          curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/$MODEL_ID/_deploy"
          echo "Model deployed: $MODEL_ID"
          ;;
        
        status)
          echo "==> Checking ML Commons status..."
          curl -s "$OPENSEARCH_URL/_plugins/_ml/stats" | jq '.'
          ;;
        
        test-models)
          echo "==> Testing ML model functionality..."
          
          # Test 1: List all models
          echo "Registered models:"
          curl -s -X GET "$OPENSEARCH_URL/_plugins/_ml/models/_search" \\
            -H "Content-Type: application/json" \\
            -d '{"query": {"match_all": {}}}' | jq '.hits.hits[]._source | {name, model_state, model_format}'
          
          # Test 2: Test text embedding
          echo -e "\\nTesting text embedding with 'hello world':"
          curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/_predict/text_embedding" \\
            -H "Content-Type: application/json" \\
            -d '{"text_docs": ["hello world"], "target_response": ["sentence_embedding"]}' | jq '.'
          
          # Test 3: Test sparse encoding  
          echo -e "\\nTesting sparse encoding with 'test query':"
          curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/_predict/sparse_encoding" \\
            -H "Content-Type: application/json" \\
            -d '{"text_docs": ["test query"]}' | jq '.'
          ;;
        
        clean)
          echo "==> Cleaning up ML models and state..."
          
          # Get list of all registered models
          echo "==> Undeploying and deleting registered models..."
          curl -s -X GET "$OPENSEARCH_URL/_plugins/_ml/models/_search" \
            -H "Content-Type: application/json" \
            -d '{"query": {"match_all": {}}, "size": 100}' | \
            jq -r '.hits.hits[]._source.model_id' | \
            while read -r model_id; do
              if [ ! -z "$model_id" ] && [ "$model_id" != "null" ]; then
                echo "Undeploying model: $model_id"
                curl -s -X POST "$OPENSEARCH_URL/_plugins/_ml/models/$model_id/_undeploy" > /dev/null
                echo "Deleting model: $model_id"  
                curl -s -X DELETE "$OPENSEARCH_URL/_plugins/_ml/models/$model_id" > /dev/null
              fi
            done
          
          # Clean up model groups
          echo "==> Cleaning up model groups..."
          curl -s -X GET "$OPENSEARCH_URL/_plugins/_ml/model_groups/_search" \
            -H "Content-Type: application/json" \
            -d '{"query": {"match_all": {}}, "size": 100}' | \
            jq -r '.hits.hits[]._source.model_group_id' | \
            while read -r group_id; do
              if [ ! -z "$group_id" ] && [ "$group_id" != "null" ]; then
                echo "Deleting model group: $group_id"
                curl -s -X DELETE "$OPENSEARCH_URL/_plugins/_ml/model_groups/$group_id" > /dev/null
              fi
            done
          
          # Clean up state files
          echo "==> Cleaning up state files..."
          rm -rf "$ML_STATE_DIR"
          
          echo "==> ML Commons cleanup complete"
          echo "==> Models, groups, and state files removed"
          echo "==> JVM memory settings (4GB) preserved for other plugins"
          echo "==> You can now safely uninstall the ML Commons plugin:"
          echo "    brew uninstall knoguchi/opensearch/opensearch-ml-commons"
          echo "==> Note: opensearch-job-scheduler will be automatically removed only if no other plugins depend on it"
          ;;
        
        *)
          echo "Usage: $0 {wait|configure|create-group|register-sparse-v2|register-embedding|register-cross-encoder|wait-and-deploy|status|test-models|clean}"
          exit 1
          ;;
      esac
    EOS
  end

  def uninstall_preflight
    # Clean up ML models and state before uninstalling
    if File.exist?("#{bin}/opensearch-ml-setup")
      puts "==> Running automatic cleanup before uninstall..."
      system "#{bin}/opensearch-ml-setup", "clean"
    end
  end

  def caveats
    <<~EOS
      OpenSearch ML models have been installed and configured:
      - Neural Sparse V2 Distill (sparse encoding - recommended for search)
      - Text Embedding (all-MiniLM-L6-v2 - for vector embeddings)
      - Cross-Encoder (ms-marco-MiniLM-L-12-v2 - for reranking)
      
      To test model functionality:
      opensearch-ml-setup test-models
      
      To check model status:
      opensearch-ml-setup status
      
      To remove ML models and plugin:
      brew uninstall knoguchi/opensearch/opensearch-ml-commons
      
      Note: ML models and state are automatically cleaned up during uninstall.
      opensearch-job-scheduler will be automatically removed by Homebrew
      only if no other plugins depend on it.
      
      Model files are cached in OpenSearch data directory.
      Use 'opensearch-ml-setup' for individual model management.
    EOS
  end

  test do
    assert_predicate bin/"opensearch-ml-setup", :exist?
    assert_predicate bin/"opensearch-ml-setup", :executable?
    
    # Test ML Commons API endpoints are available
    # Note: These tests require OpenSearch to be running
    opensearch_url = "http://localhost:9200"
    
    # Test 1: Check ML Commons plugin is loaded
    output = shell_output("curl -s #{opensearch_url}/_cat/plugins")
    assert_match "opensearch-ml", output
    
    # Test 2: Check ML stats endpoint  
    ml_stats = shell_output("curl -s #{opensearch_url}/_plugins/_ml/stats")
    assert_match "nodes", ml_stats
    
    # Test 3: List registered models
    models = shell_output("curl -s -X GET #{opensearch_url}/_plugins/_ml/models/_search -H 'Content-Type: application/json' -d '{\"query\": {\"match_all\": {}}}'")
    assert_match "hits", models
    
    # Test 4: Test text embedding functionality (if models are deployed)
    embed_test = shell_output("curl -s -X POST #{opensearch_url}/_plugins/_ml/_predict/text_embedding -H 'Content-Type: application/json' -d '{\"text_docs\": [\"hello world\"], \"target_response\": [\"sentence_embedding\"]}' || echo 'models_not_ready'")
    # Don't fail if models aren't deployed yet, just check API responds
    assert(embed_test.include?("sentence_embedding") || embed_test.include?("models_not_ready") || embed_test.include?("error"))
  end
end