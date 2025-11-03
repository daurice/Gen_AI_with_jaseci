import from byllm.llm { Model }
import from py_modules.repo_cloner { clone_repo, build_file_tree, find_readme }
import from py_modules.readme_summarizer { summarize_readme }
import from py_modules.code_parser { extract_functions_and_classes, get_parser }
import from py_modules.graph_builder { CodeContextGraph }
import from utils { get_current_datetime, sanitize_filename }
include utils;

glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);
glob ccg = CodeContextGraph();

node Repo {
    has url: str;
    has clone_path: str;
    has tree: dict;
    has readme_summary: str;
    has name: str;
}

node File {
    has path: str;
    has content: str;
    has language: str;
    has symbols: list = [];
}

node Documentation {
    has markdown: str = "";
    has diagrams: list = [];
}

walker code_genius {
    has repo_url: str = "";
    has session_id: str = "";
    has repo: Repo = null;
    has doc: Documentation = null;

    can start with entry {
        if not self.repo_url.startswith("https://github.com/"):
            report {"error": "Invalid GitHub URL"};
            disengage;

        repo_name = self.repo_url.split("/")[-1].replace(".git", "");
        clone_dir = f"/tmp/codegenius_{sanitize_filename(repo_name)}";
        try {
            clone_path = clone_repo(self.repo_url, clone_dir);
            tree = build_file_tree(clone_path);
            readme_path = find_readme(clone_path);
            readme_summary = summarize_readme(readme_path);

            self.repo = spawn Repo(
                url=self.repo_url,
                clone_path=clone_path,
                tree=tree,
                readme_summary=readme_summary,
                name=repo_name
            );
            self.doc = spawn Documentation();
            visit --> (`?repo_mapper);
        } except e {
            report {"error": str(e)};
        }
    }
}

walker repo_mapper {
    can map with entry {
        repo = visitor.repo;
        report {
            "stage": "mapping",
            "tree": repo.tree,
            "readme": repo.readme_summary
        };
        visit --> (`?code_analyzer);
    }
}

walker code_analyzer {
    has priority_files: list = ["main.py", "app.py", "__init__.py", "index.jac"];
    has processed: set = {};

    def should_analyze(filepath: str) -> bool {
        ext = filepath.split(".")[-1];
        return ext in ["py", "jac"];

    def analyze_file(filepath: str) {
        if filepath in self.processed:
            return;
        self.processed.add(filepath);

        with open(filepath, "r") as f:
            code = f.read();
        parser = get_parser(filepath);
        if not parser:
            return;

        symbols = extract_functions_and_classes(code, parser);
        file_node = spawn File(path=filepath, content=code, language=filepath.split(".")[-1], symbols=symbols);
        here ++> file_node;

        for sym in symbols:
            node_id = f"{filepath}:{sym['name']}";
            ccg.add_node(filepath, sym['name'], sym['type'], sym['line']);
    }

    can analyze with entry {
        repo = visitor.repo;
        root = repo.clone_path;

        # Priority first
        for pri in self.priority_files:
            path = f"{root}/{pri}";
            if os.path.exists(path):
                self.analyze_file(path);

        # Then traverse tree
        def walk_dir(dir_path: str) {
            for item in os.listdir(dir_path):
                full = f"{dir_path}/{item}";
                if os.path.isdir(full):
                    walk_dir(full);
                elif self.should_analyze(full):
                    self.analyze_file(full);
        }
        walk_dir(root);

        # TODO: Build call graph via LLM + static analysis hybrid
        report {"stage": "analysis_complete", "files_analyzed": len(self.processed)};
        visit --> (`?doc_genie);
    }
}

walker doc_genie {
    def generate_diagram(graph_data: dict) -> str {
        import pygraphviz as pgv
        G = pgv.AGraph(directed=True)
        for node in graph_data['nodes']:
            G.add_node(node['id'], label=node['data']['name'], shape="box")
        for link in graph_data['links']:
            if link['data']['relationship'] == "calls":
                G.add_edge(link['source'], link['target'], label="calls")
        dot_path = f"./outputs/{visitor.repo.name}/callgraph.dot";
        png_path = dot_path.replace(".dot", ".png");
        os.makedirs(os.path.dirname(dot_path), exist_ok=True);
        G.draw(png_path, prog="dot")
        return f"![Call Graph]({png_path})"

    can generate with entry {
        repo = visitor.repo;
        doc = visitor.doc;
        output_dir = f"./outputs/{repo.name}";
        os.makedirs(output_dir, exist_ok=True);

        md = f"# {repo.name} Documentation\n\n";
        md += f"**Generated on:** {get_current_datetime()}\n\n";
        md += f"## Project Overview\n{repo.readme_summary}\n\n";

        md += "## File Structure\n```text\n";
        def print_tree(node: dict, indent: str = "") {
            if node['type'] == 'dir':
                md += f"{indent}+ {node['name']}/\n";
                for child in node['children']:
                    print_tree(child, indent + "  ");
            else:
                md += f"{indent}- {node['name']}\n";
        }
        print_tree(repo.tree);
        md += "```\n\n";

        md += "## API Reference\n";
        files = [here --> (`?File)];
        for f in files:
            if f.language == 'py':
                md += f"### `{f.path}`\n";
                for sym in f.symbols:
                    md += f"- **{sym['type']}** `{sym['name']}` (Line {sym['line']})\n";

        # Diagram
        graph_data = ccg.to_dict();
        if len(graph_data['nodes']) > 1:
            diagram_md = self.generate_diagram(graph_data);
            md += "\n## Call Graph\n" + diagram_md + "\n";

        doc.markdown = md;
        doc_path = f"{output_dir}/docs.md";
        with open(doc_path, "w") as f:
            f.write(md);

        report {
            "stage": "complete",
            "documentation_path": doc_path,
            "message": "Documentation generated successfully!"
        };
    }
}

walker get_documentation {
    can get with `root entry {
        repos = [root --> (`?Repo)];
        if not repos:
            report {"error": "No repository processed"};
            disengage;
        latest = repos[-1];
        doc_path = f"./outputs/{latest.name}/docs.md";
        if os.path.exists(doc_path):
            with open(doc_path, "r") as f:
                content = f.read();
            report {"markdown": content, "repo": latest.name};
        else:
            report {"error": "Documentation not found"};
    }
}

with entry {
    # Ensure output dir
    os.makedirs("./outputs", exist_ok=True);
}