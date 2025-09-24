# Homebrew OpenSearch Tap

Custom Homebrew formulas for OpenSearch with ML Commons plugin support and Intel Mac compatibility patches.

## Quick Start

```bash
# Add this tap
brew tap yourusername/opensearch

# Install OpenSearch with ML plugins
brew install opensearch
brew install opensearch-ml-commons  # Automatically installs job-scheduler
```

## Available Formulas

### `opensearch`
- **Version:** 3.2.0
- **Description:** Core OpenSearch distributed search engine
- **Installation:** `brew install opensearch`

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

### Full Installation (Recommended)
```bash
# Add the tap
brew tap yourusername/opensearch

# Install everything
brew install opensearch opensearch-ml-commons

# Start OpenSearch
brew services start opensearch

# Verify plugins
opensearch-plugin list
```

### Core Only
```bash
# Just OpenSearch without ML plugins
brew install opensearch
brew services start opensearch
```

### Manual Plugin Installation
```bash
# Install OpenSearch first
brew install opensearch

# Add plugins later
brew install opensearch-job-scheduler
brew install opensearch-ml-commons
```

## Configuration

### Default Paths
- **Config:** `/opt/homebrew/etc/opensearch/` (Apple Silicon) or `/usr/local/etc/opensearch/` (Intel)
- **Data:** `/opt/homebrew/var/lib/opensearch/`
- **Logs:** `/opt/homebrew/var/log/opensearch/`
- **Plugins:** `/opt/homebrew/var/opensearch/plugins/`

### Default Settings
- Cluster name: `opensearch_homebrew`
- HTTP port: `9200`
- Transport port: `9300`

### Custom Configuration
Edit the configuration file:
```bash
# Apple Silicon
nano /opt/homebrew/etc/opensearch/opensearch.yml

# Intel Mac
nano /usr/local/etc/opensearch/opensearch.yml
```

## Usage

### Starting/Stopping
```bash
# Start OpenSearch
brew services start opensearch

# Stop OpenSearch
brew services stop opensearch

# Restart OpenSearch
brew services restart opensearch

# Run in foreground (for debugging)
opensearch
```

### Verify Installation
```bash
# Check if running
curl -XGET https://localhost:9200 -ku 'admin:admin'

# List installed plugins
opensearch-plugin list

# Check cluster health
curl -XGET https://localhost:9200/_cluster/health?pretty -ku 'admin:admin'
```

### ML Commons Operations
```bash
# Check ML Commons status
curl -XGET https://localhost:9200/_plugins/_ml/profile -ku 'admin:admin'

# Deploy a model (example)
curl -XPOST https://localhost:9200/_plugins/_ml/models/_upload \
  -H 'Content-Type: application/json' \
  -ku 'admin:admin' \
  -d '{
    "name": "huggingface/sentence-transformers/all-MiniLM-L6-v2",
    "version": "1.0.1",
    "model_format": "TORCH_SCRIPT"
  }'
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

### Port Conflicts
If port 9200 is already in use:
```bash
# Find what's using port 9200
lsof -i :9200

# Change port in opensearch.yml
echo "http.port: 9201" >> /opt/homebrew/etc/opensearch/opensearch.yml
```

### Memory Issues
OpenSearch requires significant memory. Adjust JVM heap size:
```bash
# Edit jvm.options
nano /opt/homebrew/etc/opensearch/jvm.options

# Set heap size (example: 4GB)
-Xms4g
-Xmx4g
```

## Building from Source

To modify formulas or contribute:
```bash
# Clone this tap
git clone https://github.com/yourusername/homebrew-opensearch
cd homebrew-opensearch

# Edit formulas
nano Formula/opensearch-ml-commons.rb

# Test locally
brew install --build-from-source Formula/opensearch-ml-commons.rb
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