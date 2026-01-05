# Rename Files to Modification Date

A small shell script that renames files in a directory to their modification timestamp.

Target filename format:

\`\`\`
YYYY-MM-DD_HH-MM-SS.ext
\`\`\`

If the target name already exists, an increment is appended:

\`\`\`
YYYY-MM-DD_HH-MM-SS_1.ext
YYYY-MM-DD_HH-MM-SS_2.ext
\`\`\`

## Features

- Non-recursive: only files directly inside the given directory are processed
- Preserves file extensions
- Avoids collisions by appending an increment
- Supports dry runs

## Requirements

- macOS or Linux
- Standard command line tools: \`find\`, \`stat\`, \`date\`

## Usage

Make the script executable:

\`\`\`bash
chmod +x rename_files_to_mtime.sh
\`\`\`

Run on a directory:

\`\`\`bash
./rename_files_to_mtime.sh /path/to/files
\`\`\`

### Dry run

Prints planned changes without renaming:

\`\`\`bash
./rename_files_to_mtime.sh --dry-run /path/to/files
\`\`\`

### Skip confirmation prompt

\`\`\`bash
./rename_files_to_mtime.sh --yes /path/to/files
\`\`\`

## Notes

- Files without an extension will be renamed without one.
- The script uses file modification time (mtime). If you want EXIF-based timestamps for photos, use the separate script "Sort Photos By Year" (EXIF \`DateTimeOriginal\`).

## License

This project is licensed under the MIT License. See the \`LICENSE\` file for details.
