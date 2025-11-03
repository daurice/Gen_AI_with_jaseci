import os
import shutil
from git import Repo
from typing import Dict, List
import pathlib

def clone_repo(url: str, dest: str) -> str:
    """Clone GitHub repo to temp dir and return root path."""
    if os.path.exists(dest):
        shutil.rmtree(dest)
    Repo.clone_from(url, dest, depth=1)
    return dest

def build_file_tree(root: str, ignore_dirs=[".git", "node_modules", "__pycache__", ".venv"]) -> Dict:
    tree = {"type": "dir", "name": os.path.basename(root) or "root", "path": root, "children": []}
    for item in sorted(os.listdir(root)):
        item_path = os.path.join(root, item)
        if any(ignored in item_path for ignored in ignore_dirs):
            continue
        if os.path.isdir(item_path):
            tree["children"].append(build_file_tree(item_path, ignore_dirs))
        else:
            if item.endswith(('.py', '.jac', '.md', '.txt')):
                tree["children"].append({"type": "file", "name": item, "path": item_path})
    return tree

def find_readme(root: str) -> str:
    for file in os.listdir(root):
        if file.lower().startswith("readme") and file.lower().endswith(".md"):
            return os.path.join(root, file)
    return ""