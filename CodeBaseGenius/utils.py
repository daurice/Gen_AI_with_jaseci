import os
import git
import tempfile
import ast
import graphviz
import logging
from typing import List, Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Directories to ignore when mapping the repository
IGNORE_DIRS = {'.git', 'node_modules', '__pycache__', '.venv', 'venv', 'dist', 'build'}
# File extensions to analyze
PYTHON_EXT = {'.py'}
JAC_EXT = {'.jac'} # Jac parsing would require a dedicated parser
SUPPORTED_EXT = PYTHON_EXT.union(JAC_EXT)

def clone_repo(url: str) -> Dict[str, str]:
    """
    Clones a public GitHub repository to a temporary directory.

    Args:
        url: The URL of the GitHub repository.

    Returns:
        A dictionary containing the local path to the cloned repo
        and the repo name, or an error message.
    """
    try:
        temp_dir = tempfile.mkdtemp(prefix="codebase_genius_")
        repo_name = url.split('/')[-1].replace('.git', '')
        repo_path = os.path.join(temp_dir, repo_name)
        
        logging.info(f"Cloning {url} into {repo_path}...")
        git.Repo.clone_from(url, repo_path)
        logging.info(f"Successfully cloned repo: {repo_name}")
        
        return {"status": "success", "path": repo_path, "name": repo_name}
    except git.exc.GitCommandError as e:
        logging.error(f"Error cloning repo {url}: {e}")
        return {"status": "error", "message": f"Failed to clone repo. Is it public? Error: {e}"}
    except Exception as e:
        logging.error(f"An unexpected error occurred during cloning: {e}")
        return {"status": "error", "message": f"An unexpected error occurred: {e}"}

def generate_file_tree(start_path: str) -> str:
    """
    Generates a string representation of the file tree, ignoring specified directories.

    Args:
        start_path: The root path of the repository to traverse.

    Returns:
        A string representing the file tree.
    """
    tree_str = ""
    for root, dirs, files in os.walk(start_path, topdown=True):
        # Filter out ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        
        level = root.replace(start_path, '').count(os.sep)
        indent = ' ' * 4 * level
        tree_str += f"{indent}├── {os.path.basename(root)}/\n"
        
        sub_indent = ' ' * 4 * (level + 1)
        for f in files:
            tree_str += f"{sub_indent}└── {f}\n"
    return tree_str

def get_file_content(file_path: str) -> Dict[str, str]:
    """
    Reads the content of a file.

    Args:
        file_path: The absolute path to the file.

    Returns:
        A dictionary with file content or an error message.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        return {"status": "success", "content": content}
    except FileNotFoundError:
        return {"status": "error", "message": "File not found."}
    except UnicodeDecodeError:
        return {"status": "error", "message": "Could not decode file (not UTF-8)."}
    except Exception as e:
        return {"status": "error", "message": f"Error reading file: {e}"}

def find_code_files(start_path: str) -> List[str]:
    """
    Finds all supported source code files in the repository.

    Args:
        start_path: The root path of the repository.

    Returns:
        A list of relative paths to supported code files.
    """
    code_files = []
    for root, dirs, files in os.walk(start_path, topdown=True):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        
        for file in files:
            if any(file.endswith(ext) for ext in SUPPORTED_EXT):
                relative_path = os.path.relpath(os.path.join(root, file), start_path)
                code_files.append(relative_path)
    return code_files

class PythonCodeParser(ast.NodeVisitor):
    """
    Parses Python code using AST to extract classes, functions, and calls.
    """
    def __init__(self):
        self.structure = {
            "classes": [],
            "functions": [],
            "imports": [],
            "calls": [] # Note: This will be simple, top-level calls
        }
        self.current_class = None

    def visit_Import(self, node):
        for alias in node.names:
            self.structure["imports"].append(alias.name)
        self.generic_visit(node)

    def visit_ImportFrom(self, node):
        self.structure["imports"].append(node.module)
        self.generic_visit(node)

    def visit_ClassDef(self, node):
        class_info = {
            "name": node.name,
            "methods": [],
            "inherits": [base.id for base in node.bases if isinstance(base, ast.Name)]
        }
        self.current_class = class_info
        for item in node.body:
            if isinstance(item, ast.FunctionDef):
                class_info["methods"].append(self._parse_function(item))
        self.structure["classes"].append(class_info)
        self.current_class = None
        # Don't visit children further, we handled methods
        
    def visit_FunctionDef(self, node):
        if self.current_class is None: # It's a standalone function
            self.structure["functions"].append(self._parse_function(node))
        # We don't call generic_visit here to avoid nested function defs being added twice
        # But we do want to find calls *within* this function
        for item in node.body:
            self.visit(item)

    def _parse_function(self, node: ast.FunctionDef) -> Dict[str, Any]:
        return {
            "name": node.name,
            "args": [arg.arg for arg in node.args.args],
            "docstring": ast.get_docstring(node)
        }

    def visit_Call(self, node):
        call_name = ""
        if isinstance(node.func, ast.Name):
            call_name = node.func.id
        elif isinstance(node.func, ast.Attribute):
            call_name = node.func.attr
        
        if call_name:
            self.structure["calls"].append(call_name)
        self.generic_visit(node)

def parse_python_code(content: str) -> Dict[str, Any]:
    """
    Parses Python code content and returns a structured dictionary.

    Args:
        content: The Python code as a string.

    Returns:
        A dictionary with the parsed structure or an error.
    """
    try:
        tree = ast.parse(content)
        parser = PythonCodeParser()
        parser.visit(tree)
        return {"status": "success", "data": parser.structure}
    except SyntaxError as e:
        logging.warning(f"Syntax error parsing Python file: {e}")
        return {"status": "error", "message": f"Syntax error: {e}"}
    except Exception as e:
        logging.error(f"Error parsing Python AST: {e}")
        return {"status": "error", "message": f"AST parsing failed: {e}"}

def generate_diagram(graph_data: Dict[str, Any], output_path: str) -> Dict[str, str]:
    """
    Generates a PNG diagram from graph data using Graphviz.

    Args:
        graph_data: The Code Context Graph data.
        output_path: The full path to save the .png file.

    Returns:
        A dictionary with the path to the generated image or an error.
    """
    dot = graphviz.Digraph(comment='Code Context Graph')
    dot.attr(rankdir='LR', splines='ortho', concentrate='true')

    # Add modules as subgraphs
    for module_name, module_data in graph_data.get("modules", {}).items():
        with dot.subgraph(name=f"cluster_{module_name}") as c:
            c.attr(label=module_name, style='filled', color='lightgrey')
            
            # Add classes
            for class_obj in module_data.get("classes", []):
                class_name = class_obj["name"]
                c.node(class_name, class_name, shape='box', style='filled', color='lightblue')
                
                # Add methods
                for method in class_obj.get("methods", []):
                    method_name = f"{class_name}.{method['name']}"
                    c.node(method_name, method['name'] + "()", shape='ellipse')
                    c.edge(class_name, method_name, arrowhead='none')

            # Add functions
            for func in module_data.get("functions", []):
                func_name = func["name"]
                c.node(func_name, func_name + "()", shape='ellipse', style='filled', color='lightgreen')

    # Add calls (this is a simplified example)
    # A real implementation would need to resolve full function paths
    for from_func, to_func in graph_data.get("calls", []):
         # Check if nodes exist before creating edge
        if from_func in dot.body_map and to_func in dot.body_map:
            dot.edge(from_func, to_func, label='calls')

    # Add inheritance
    for child, parent in graph_data.get("inheritance", []):
         if child in dot.body_map and parent in dot.body_map:
            dot.edge(parent, child, label='inherits', arrowhead='onormal')

    try:
        # Ensure the directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Render the graph
        # We save as PNG, as SVG can be complex to embed and size
        output_format = 'png'
        rendered_path = dot.render(output_path, format=output_format, cleanup=True)
        
        logging.info(f"Diagram generated: {rendered_path}")
        return {"status": "success", "path": rendered_path}
    except Exception as e:
        logging.error(f"Failed to generate diagram: {e}")
        # Check if Graphviz executables are in PATH
        if "No such file or directory" in str(e) or "command not found" in str(e):
             return {"status": "error", "message": "Graphviz 'dot' command not found. Please install Graphviz and ensure it's in your system's PATH."}
        return {"status": "error", "message": f"Failed to render diagram: {e}"}

def save_documentation(repo_name: str, content: str) -> Dict[str, str]:
    """
    Saves the generated markdown documentation to ./outputs/repo_name/docs.md

    Args:
        repo_name: The name of the repository.
        content: The markdown content to save.

    Returns:
        A dictionary with the save path or an error.
    """
    try:
        output_dir = os.path.join("outputs", repo_name)
        os.makedirs(output_dir, exist_ok=True)
        save_path = os.path.join(output_dir, "docs.md")
        
        with open(save_path, 'w', encoding='utf-8') as f:
            f.write(content)
            
        logging.info(f"Documentation saved to {save_path}")
        return {"status": "success", "path": save_path}
    except Exception as e:
        logging.error(f"Failed to save documentation: {e}")
        return {"status": "error", "message": f"Could not write file: {e}"}
