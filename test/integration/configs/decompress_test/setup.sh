#!/bin/sh
# Create source file for decompress test
echo "decompress test content" > /tmp/configr_decompress_src.txt
# Create zip archive of it
cd /tmp && zip configr_compressed.zip configr_decompress_src.txt
