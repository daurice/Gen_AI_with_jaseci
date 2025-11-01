import from datetime { datetime }
import from pathlib { Path }
import from subprocess { run, PIPE }
import from json { loads, dumps }
import from typing { List, Dict, Optional }
import from os { getenv, makedirs, remove }
import from shutil { rmtree }
import from uuid { uuid4 }

# --- External Python Helpers (via py_module) ---
py_module git_clone {
    def clone_repo(url: str, dest: str) -> str {
        cmd = ["git", "clone", "--depth", "1", url, dest];
        result = run(cmd, capture_output=True, text=True);
        if result.returncode != 0 {
            return f"Clone failed: {result.stderr}";
        }
        return "Cloned successfully";
    }
}

py_module tree_sitter_parser {
    from tree_sitter import Language, Parser
    from tree_sitter_python import language as PY_LANG
    from tree_sitter_javascript import language as JS_LANG

    PY = Language(PY_LANG())
    JS = Language(JS_LANG())
    PARSER = Parser()

    def parse_file(content: str, lang: str) -> Optional[dict] {
        if lang == "python":
            PARSER.set_language(PY)
        elif lang == "javascript":
            PARSER.set_language(JS)
        else:
            return null;

        tree = PARSER.parse(bytes(content, "utf8"))
        root = tree.root_node

        def extract_functions(node):
            funcs = []
            if node.type in ["function_definition", "method_definition"]:
                name_node = node.child_by_field_name("name")
                name = name_node.text.decode("utf8") if name_node else "anonymous"
                funcs.append({"type": "function", "name": name, "start": node.start_point, "end": node.end_point})
            for child in node.children:
                funcs.extend(extract_functions(child))
            return funcs

        return {
            "functions": extract_functions(root),
            "classes": []  # extend later
        }
    }
}

# --- Nodes ---
node Repo {
    has url: str;
    has name: str;
    has cloned_at: str = str(datetime.now());
    has local_path: str;
}

node FileNode {
    has path: str;
    has content: str = "";
    has language: str = "";
    has is_entrypoint: bool = false;
}

node FunctionNode {
    has name: str;
    has file: FileNode;
    has start_line: int;
    has end_line: int;
}

edge Calls { from FunctionNode to FunctionNode }
edge DefinedIn { from FunctionNode to FileNode }

node CCG {
    has built_at: str;
}

node DocSection {
    has title: str;
    has content: str;
    has order: int;
}

# --- Agents as Nodes with Walkers ---
node CodeGenius {
    has active_repo: Optional[Repo] = null;

    def route_task(task: str, context: str) -> str by llm(
        method="ReAct",
        tools=([self.clone_and_map, self.analyze_code, self.generate_docs, self.get_status])
    );

    def clone_and_map(repo_url: str) -> str {
        repo_name = repo_url.split("/")[-1].replace(".git", "");
        temp_dir = f"./temp_repos/{repo_name}_{uuid4().hex[:8]}";
        makedirs(temp_dir, exist_ok=true);

        result = git_clone.clone_repo(repo_url, temp_dir);
        if "failed" in result.lower():
            return result;

        repo = Repo(url=repo_url, name=repo_name, local_path=temp_dir);
        self ++> repo;
        self.active_repo = repo;

        # Build file tree
        walker build_tree {
            root = here.active_repo;
            path = Path(root.local_path);
            for p in path.rglob("*"):
                if p.is_file() and not any(ignored in str(p) for ignored in [".git", "node_modules", "__pycache__", ".venv"]):
                    lang = ""
                    if p.suffix in [".py"]: lang = "python"
                    elif p.suffix in [".js", ".ts"]: lang = "javascript"
                    elif p.suffix in [".jac"]: lang = "jac"

                    is_entry = p.name in ["main.py", "app.py", "index.js", "server.js", "README.md"]
                    file_node = FileNode(path=str(p.relative_to(path)), language=lang, is_entrypoint=is_entry)
                    if lang in ["python", "javascript"]:
                        try {
                            file_node.content = p.read_text(encoding="utf8")
                        }
                        except: pass
                    root ++> file_node;
            }
        }
        build_tree();

        # Summarize README
        readme_files = [f for f in repo --> (`?FileNode) if "readme" in f.path.lower()]
        summary = "No README found."
        if readme_files:
            content = readme_files[0].content
            if len(content) > 3000: content = content[:3000]
            summary = llm(prompt=f"Summarize this README in 3 bullets:\n\n{content}")["response"]

        return f"Repo cloned and mapped.\n\n**README Summary:**\n{summary}\n\nReady for analysis.";
    }

    def analyze_code() -> str {
        repo = self.active_repo;
        if not repo: return "No active repo.";

        entry_files = [f for f in repo --> (`?FileNode) if f.is_entrypoint and f.content]
        total = len(entry_files)
        analyzed = 0

        for file in entry_files:
            if not file.content: continue
            parse_result = tree_sitter_parser.parse_file(file.content, file.language)
            if not parse_result: continue

            for func in parse_result["functions"]:
                func_node = FunctionNode(
                    name=func["name"],
                    start_line=func["start"][0],
                    end_line=func["end"][0]
                )
                file ++> func_node with DefinedIn;
                analyzed += 1

        ccg = CCG(built_at=str(datetime.now()));
        repo ++> ccg;

        return f"Analyzed {analyzed} functions across {total} entrypoint files. CCG built.";
    }

    def generate_docs() -> str {
        repo = self.active_repo;
        if not repo: return "No repo.";

        files = [repo --> (`?FileNode)]
        functions = [repo --> (`?FunctionNode)]
        readme_summary = "No README."

        readme_file = next((f for f in files if "readme" in f.path.lower()), null)
        if readme_file and readme_file.content:
            readme_summary = llm(prompt=f"Extract project name, description, install, usage in bullet points:\n\n{readme_file.content[:4000]}")["response"]

        # Group functions by file
        func_by_file = {}
        for func in functions:
            file = func <-- (`?DefinedIn)
            if file:
                path = file[0].path
                func_by_file.setdefault(path, []).append(func)

        # Generate API Reference
        api_ref = ""
        for path, funcs in func_by_file.items():
            api_ref += f"### `{path}`\n\n"
            for f in funcs:
                api_ref += f"- **`{f.name}()`** (lines {f.start_line}-{f.end_line})\n"
            api_ref += "\n"

        # Diagram (Mermaid)
        mermaid_calls = "graph TD;\n"
        call_id = 0
        for func in functions[:10]:  # limit for demo
            call_id += 1
            mermaid_calls += f"    F{call_id}[{func.name}]\n"

        final_md = f"""# {repo.name} Documentation

## Overview
{readme_summary}

## Installation
```bash
git clone {repo.url}
cd {repo.name}
# Follow README