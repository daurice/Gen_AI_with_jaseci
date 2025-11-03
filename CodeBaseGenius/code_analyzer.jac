node CodeAnalyzer {
    has parser: Parser;

    post init {
        self.parser = Parser();
        self.parser.set_language(PYTHON_LANGUAGE);
    }

     
    def parse_file(file_path: str) -> dict {
        if not (file_path.endswith('.py') or file_path.endswith('.jac')) {
            return {};
        }
        with open(file_path, "r") as f: code = f.read();
        return llm(prompt=f"Extract classes, functions and call‑relationships from:\n{code}");
    }

    def build_ccg(local_path: str, file_tree: str) -> dict by llm(
        method="ReAct",
        tools=([self.parse_file])
    );

    can execute with generate_documentation entry {
        repo = visitor.repo;
        repo.ccg = self.build_ccg(repo.local_path, repo.file_tree);
    }
}

sem CodeAnalyzer.build_ccg = """
Start from entry‑point files (main.py, app.py, *.jac).  
Parse each file, collect classes / functions / calls.  
Return a dict like:
{
  "entities": {"name": {"type":"class|func","file":...,"calls":[...],"inherits":...}},
  "relations": [...]
}
""";
