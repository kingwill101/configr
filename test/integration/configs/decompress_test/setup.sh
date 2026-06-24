# First compress, then decompress test
#!/bin/sh
# Create source file
echo "decompress test content" > /tmp/configr_decompress_src.txt
# Create zip archive of it
cd /tmp && zip configr_compressed.zip configr_decompress_src.txt 2>/dev/null || true