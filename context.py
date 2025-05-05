import os

#!/usr/bin/env python3

def add_file_to_md(md_lines, rel_path):
    """Append the file header and its content to md_lines."""
    if not os.path.isfile(rel_path):
        return  # skip if not a file
    md_lines.append(f"## {rel_path}\n")
    try:
        with open(rel_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        content = f"Error reading file: {e}"
    md_lines.append("```")
    md_lines.append(content.rstrip())
    md_lines.append("```\n")

def add_directory_to_md(md_lines, dir_name):
    """Walk through a directory recursively and add all files."""
    if not os.path.isdir(dir_name):
        return
    for root, _, files in os.walk(dir_name):
        for fname in sorted(files):
            # Create a relative path to the project root.
            rel_path = os.path.join(root, fname)
            add_file_to_md(md_lines, rel_path)

def main():
    # List to store markdown lines.
    md_lines = ["# Project Files\n"]
    
    # 1. Add Makefile in root.
    makefile_path = "Makefile"
    md_lines.append("## Makefile (in root)\n")
    if os.path.isfile(makefile_path):
        try:
            with open(makefile_path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception as e:
            content = f"Error reading Makefile: {e}"
        md_lines.append("```")
        md_lines.append(content.rstrip())
        md_lines.append("```\n")
    else:
        md_lines.append("Makefile not found in the root directory.\n")
    
    # 2. Add all files in the src folder.
    md_lines.append("## Files in src folder\n")
    add_directory_to_md(md_lines, "src")
    
    # 3. Add all files in the scripts folder.
    md_lines.append("## Files in scripts folder\n")
    add_directory_to_md(md_lines, "scripts")
    
    # Write markdown to file.
    output_file = "project_contents.md"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines))
    
    print(f"Markdown file generated: {output_file}")

if __name__ == "__main__":
    main()
