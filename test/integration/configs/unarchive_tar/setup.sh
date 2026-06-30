#!/bin/sh
mkdir -p /tmp/unarchive_src
echo "unarchive test content" > /tmp/unarchive_src/extracted_file.txt
tar -czf /tmp/test_archive.tar.gz -C /tmp/unarchive_src extracted_file.txt
rm -rf /tmp/unarchive_src
