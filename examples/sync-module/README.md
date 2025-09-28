# Sync Module Example

This example demonstrates the various capabilities of the sync module for file synchronization between directories.

## Setup

1. Create the example directories and files:
```bash
# Create source directories
mkdir -p source_dir documents project configs media

# Create some test files
echo "Hello from source_dir" > source_dir/hello.txt
echo "Document content" > documents/doc1.txt
echo "Project file" > project/main.dart
echo "Config content" > configs/app.conf
echo "Media file" > media/image.jpg

# Create destination directories
mkdir -p destination_dir backup/documents backup/project backup/configs backup/media
```

## Running the Example

```bash
# Run the sync configuration
dart run ../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Basic Bidirectional Sync (`basic-sync`)
- Syncs files between `source_dir` and `destination_dir` in both directions
- Uses "newer" conflict resolution strategy
- Preserves file permissions and timestamps
- Does not delete orphaned files

### 2. Document Backup (`document-backup`)
- One-way sync from `documents` to `backup/documents`
- Excludes temporary files and system files
- Preserves file attributes
- Safe backup operation

### 3. Project Sync (`project-sync`)
- Selective sync of project files only
- Includes only source code and configuration files
- Excludes build artifacts and dependencies
- Deletes orphaned files in destination

### 4. Config Sync (`config-sync`)
- Strict source-to-destination sync
- Always prefers source files in conflicts
- Includes only configuration files
- Cleans up orphaned files

### 5. Media Sync (`media-sync`)
- Syncs media files with size-based conflict resolution
- Includes common media file extensions
- Does not preserve permissions (media files typically don't need them)
- Keeps orphaned files

## Testing Different Scenarios

### Test Conflict Resolution

1. Create conflicting files:
```bash
echo "Source version" > source_dir/conflict.txt
echo "Destination version" > destination_dir/conflict.txt
```

2. Run sync and see which version wins based on the conflict resolution strategy.

### Test Pattern Filtering

1. Create files that should be excluded:
```bash
echo "temp content" > documents/temp.tmp
echo "log content" > project/app.log
```

2. Run sync and verify these files are not synced.

### Test Orphan Deletion

1. Create a file in destination that doesn't exist in source:
```bash
echo "orphan content" > backup/documents/orphan.txt
```

2. Run sync with `delete_orphans: true` and verify the orphan is deleted.

## Expected Results

After running the sync configuration, you should see:

- Files synchronized between source and destination directories
- Statistics showing files processed, conflicts resolved, and errors encountered
- Detailed logs of sync operations
- Proper handling of different conflict resolution strategies
- Pattern-based filtering working correctly

## Monitoring and Logs

Check the `app.log` file for detailed information about:
- Sync operations performed
- Files processed
- Conflicts resolved
- Any errors encountered
- Performance statistics

## Cleanup

To clean up the example:
```bash
rm -rf source_dir destination_dir documents backup project configs media
rm -f lockfile.json app.log
```

## Customization

You can modify the configuration to:
- Change sync modes (bidirectional, source_to_dest, dest_to_source)
- Adjust conflict resolution strategies
- Modify include/exclude patterns
- Enable/disable orphan deletion
- Change attribute preservation settings

This example provides a comprehensive demonstration of the sync module's capabilities for various file synchronization scenarios.
