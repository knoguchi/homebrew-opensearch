# Homebrew OpenSearch Tap

Custom Homebrew formulas for OpenSearch with ML Commons plugin support and Intel Mac compatibility patches.

## Quick Start

```bash
# Add this tap
brew tap knoguchi/opensearch

# Install OpenSearch with ML plugins and models
brew install opensearch  # From core Homebrew
brew install opensearch-ml-commons  # Automatically installs job-scheduler
brew install opensearch-ml-models   # Installs and configures ML models
```

## Available Formulas

### `opensearch` (from core Homebrew)
- **Version:** 3.2.0  
- **Description:** Core OpenSearch distributed search engine
- **Installation:** `brew install opensearch`
- **Note:** This formula comes from the official Homebrew core tap

### `opensearch-job-scheduler`
- **Version:** 3.2.0.0
- **Description:** Job Scheduler plugin for OpenSearch
- **Installation:** `brew install opensearch-job-scheduler`
- **Required by:** ML Commons

### `opensearch-ml-commons`
- **Version:** 3.2.0.0
- **Description:** Machine Learning plugin for OpenSearch
- **Installation:** `brew install opensearch-ml-commons`
- **Includes:** Intel Mac PyTorch compatibility patches
- **Dependencies:** Automatically installs job-scheduler

### `opensearch-ml-models`
- **Version:** 1.0.0
- **Description:** Default ML models for OpenSearch ML Commons
- **Installation:** `brew install opensearch-ml-models`
- **Includes:** Neural Sparse V2, Text Embedding, Cross-Encoder models
- **Memory:** Automatically configures 4GB JVM heap
- **Dependencies:** Requires opensearch-ml-commons

## Intel Mac Compatibility

This tap includes critical patches for ML Commons on Intel Macs to resolve PyTorch compatibility issues:

### The Problem
- ML Commons 3.2.0.0 ships with DJL 0.31.1, expecting PyTorch 2.5.1+
- Intel Macs only support PyTorch up to 2.2.2 (last version with x86_64 macOS support)
- This causes symbol mismatch errors when deploying models

### The Solution
Our ML Commons formula patches:
- Downgrades DJL from 0.31.1 to 0.28.0
- Updates PyTorch references from 2.5.1 to 2.2.2
- Adjusts gson from 2.11.0 to 2.10.1 for compatibility

## Installation

```bash
brew tap knoguchi/opensearch
brew install opensearch opensearch-ml-commons opensearch-ml-models
brew services start opensearch
```

## Usage

### Verify Installation
```bash
# Check if running
curl -XGET http://localhost:9200

# List installed plugins
opensearch-plugin list

# Check cluster health
curl -XGET http://localhost:9200/_cluster/health?pretty
```

### ML Commons Operations
```bash
# Check ML Commons status
opensearch-ml-setup status

# Test model functionality
opensearch-ml-setup test-models

# List all registered models
curl -X GET "http://localhost:9200/_plugins/_ml/models/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match_all": {}}}'

# Check cluster health
curl -XGET http://localhost:9200/_cluster/health?pretty
```

### Pre-installed ML Models

The `opensearch-ml-models` formula automatically installs and configures three production-ready models:

#### Neural Sparse V2 Distill
- **Purpose:** Sparse encoding for search (recommended)
- **Model:** `amazon/neural-sparse/opensearch-neural-sparse-encoding-v2-distill`
- **Use case:** Semantic search with keyword-like performance

#### Text Embedding (all-MiniLM-L6-v2)
- **Purpose:** Vector embeddings for similarity search
- **Model:** `huggingface/sentence-transformers/all-MiniLM-L6-v2`
- **Use case:** Dense vector search, recommendations

#### Cross-Encoder (ms-marco-MiniLM-L-12-v2)
- **Purpose:** Re-ranking search results
- **Model:** `huggingface/sentence-transformers/ms-marco-MiniLM-L-12-v2`
- **Use case:** Improve search relevance through reranking

### Model Management
```bash
# Check status of all models
opensearch-ml-setup status

# Test model functionality
opensearch-ml-setup test-models

# Clean removal (removes models before uninstalling)
opensearch-ml-setup clean
brew uninstall opensearch-ml-commons
```

## Troubleshooting

### Plugin Installation Issues
```bash
# Check plugin compatibility
opensearch-plugin list

# Remove a plugin
opensearch-plugin remove opensearch-ml

# Reinstall plugins
brew reinstall opensearch-ml-commons
```

### Intel Mac PyTorch Errors
If you see errors like `Symbol not found: __ZN2at4_ops10avg_pool2d4callER...`:
1. Ensure you installed from this tap (not the official formula)
2. Reinstall ML Commons: `brew reinstall opensearch-ml-commons`
3. Restart OpenSearch: `brew services restart opensearch`

### Memory Issues
OpenSearch requires significant memory. Adjust JVM heap size:
```bash
# Edit jvm.options
nano /opt/homebrew/etc/opensearch/jvm.options

# Set heap size (example: 4GB)
-Xms4g
-Xmx4g
```

## Versions

| Component | Version | Notes |
|-----------|---------|-------|
| OpenSearch | 3.2.0 | Latest stable |
| Job Scheduler | 3.2.0.0 | Matches OpenSearch version |
| ML Commons | 3.2.0.0 | Patched for Intel Mac compatibility |
| DJL | 0.28.0 | Downgraded from 0.31.1 for Intel Macs |
| PyTorch | 2.2.2 | Last version supporting Intel Macs |

## Contributing

Issues and PRs are welcome! Please include:
- macOS version (e.g., Ventura 13.5)
- Chip architecture (Apple Silicon M1/M2/M3 or Intel)
- Error messages
- Output of `brew config` and `brew doctor`

## License

Apache 2.0 (matching OpenSearch)

## Related Links

- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [ML Commons Documentation](https://opensearch.org/docs/latest/ml-commons-plugin/index/)
- [OpenSearch GitHub](https://github.com/opensearch-project/OpenSearch)
- [ML Commons GitHub](https://github.com/opensearch-project/ml-commons)

## Acknowledgments

Patches based on debugging PyTorch/DJL compatibility issues. Thanks to the OpenSearch community for the base software.