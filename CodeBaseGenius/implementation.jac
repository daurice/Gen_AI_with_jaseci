# implementation.jac
# All agents: RepoMapper, Supervisor, CodeAnalyzer, DocGenie


# 1. Repo Mapper
#========================================
walker repo_mapper {
    has url, dest;

    walker clone_and_map {
        has url, dest;
        has tree, readme;

        # Clone
        spawn here clone_repo(url, dest);

        # Build tree + summary
        spawn here build_tree_and_summary(dest) -> tree, readme;

        report tree, readme;
    }

    walker clone_repo {
        has url, dest;
        spawn py.git_clone.clone(url, dest);
    }

    walker build_tree_and_summary {
        has root_path;
        has tree, summary;

        tree = spawn here build_file_tree(root_path);
        summary = spawn here summarize_readme(root_path);

        report tree, summary;
    }

    walker build_file_tree {
        has path;
        root --> node::file_node;

        ignore = [".git", "node_modules", "__pycache__", ".venv", "dist", "build", ".idea"];
        entries = std.file.list(path);
        for entry in entries {
            if (entry.name in ignore) continue;

            child = spawn here ++> node::file_node {
                name = entry.name;
                path = entry.path;
                is_dir = entry.is_dir;
            };

            if (entry.is_dir) {
                spawn here @child build_file_tree(entry.path);
            }
        }
        report root;
    }

    walker summarize_readme {
        has root_path;
        readme_path = null;
        for file in std.file.list(root_path, recursive=true) {
            if (file.name.lower().startswith("readme.") || file.name.lower() == "readme") {
                readme_path = file.path;
                break;
            }
        }

        if (readme_path) {
            content = std.file.read(readme_path);
            lines = [l for l in content.split("\n") if l.strip() and (l.startswith("#") or len(l) < 200)];
            summary = "\n".join(lines[:8]);
        } else {
            summary = "No README found.";
        }
        report summary;
    }
}

# 2. Supervisor (Code Genius)
#========================================
walker supervisor {
    walker plan {
        has tree, readme;
        has plan;

        entry_points = [];
        for node in tree --> node::file_node {
            if (node.is_dir) continue;
            name = node.name.lower();
            if (name in ["main.py", "app.py", "__main__.py", "index.jac", "server.jac", "main.jac"]) {
                entry_points.append(node.path);
            }
        }

        if (!entry_points) {
            for node in tree --> node::file_node {
                if (node.path.ends_with((".py", ".jac")) && node.path.count("/") <= 2) {
                    entry_points.append(node.path);
                }
            }
        }

        plan = {
            "entry_points": entry_points,
            "readme_summary": readme
        };
        report plan;
    }
}

#3. Code Analyzer
#========================================
walker code_analyzer {
    walker build_ccg {
        has root_path, plan;
        root --> node::ccg_root;
        visited = set();
        queue = plan["entry_points"];

        while (queue) {
            file_path = queue.pop(0);
            if (file_path in visited) continue;
            visited.add(file_path);

            spawn here analyze_file(file_path, root_path);

            deps = spawn here get_dependents(file_path, root);
            for dep in deps {
                if (dep not in visited && dep not in queue) {
                    queue.append(dep);
                }
            }
        }

        report root;
    }

    walker analyze_file {
        has file_path, root_path;
        if (!file_path.ends_with((".py", ".jac"))) return;

        rel_path = file_path.replace(root_path + "/", "");
        content = std.file.read(file_path);
        ast = spawn py.tree_sitter_parser.parse(content, rel_path);

        for func in ast["functions"] {
            fnode = spawn here ++> node::function {
                name = func["name"];
                file = rel_path;
                line = func["line"];
            };
            for call in func["calls"] {
                spawn here ++> edge::calls --> node::function(name=call);
            }
        }

        for cls in ast["classes"] {
            cnode = spawn here ++> node::class {
                name = cls["name"];
                file = rel_path;
            };
            if (cls["base"]) {
                spawn here ++> edge::inherits --> node::class(name=cls["base"]);
            }
        }
    }

    walker get_dependents {
        has target_file, ccg;
        results = [];
        for node in ccg --> node::function {
            if (node.file == target_file) {
                for edge in node --> edge::calls --> node::function {
                    if (edge.target.file not in results) {
                        results.append(edge.target.file);
                    }
                }
            }
        }
        report results;
    }
}

# 4. DocGenie
#========================================
walker doc_genie {
    walker generate {
        has ccg, tree, readme, repo_name;
        has md = f"# {repo_name} Documentation\n\n";

        md += f"## Project Overview\n{readme}\n\n";
        md += "## File Structure\n```text\n";
        md += spawn here render_tree(tree);
        md += "```\n\n";

        functions = [n for n in ccg --> node::function];
        classes = [n for n in ccg --> node::class];

        if (classes) {
            md += "### Classes\n";
            for cls in classes {
                md += f"- `{cls.name}` (`{cls.file}`)\n";
            }
            md += "\n";
        }

        if (functions) {
            md += "### Functions\n";
            for func in functions {
                callers = spawn here get_callers(func.name, ccg);
                md += f"- `{func.name}()` → called by: {callers}\n";
            }
            md += "\n";
        }

        md += "## Call Graph\n```mermaid\n";
        md += "graph TD\n";
        seen = set();
        for edge in ccg --> edge::calls --> node::function {
            a = edge.source.name;
            b = edge.target.name;
            key = f"{a}->{b}";
            if (key not in seen) {
                md += f"    {a} --> {b}\n";
                seen.add(key);
            }
        }
        md += "```\n";

        report md;
    }

    walker render_tree {
        has root;
        lines = [];
        spawn here traverse(root, "", lines);
        report "\n".join(lines);
    }

    walker traverse {
        has node, prefix, lines;
        name = node.name + ("/" if node.is_dir else "");
        lines.append(prefix + name);
        children = [c for c in node --> node::file_node];
        for i, child in enumerate(children) {
            ext = "└── " if i == len(children)-1 else "├── ";
            spawn here @child traverse(child, prefix + ("    " if i == len(children)-1 else "│   ") + ext, lines);
        }
    }

    walker get_callers {
        has func_name, ccg;
        callers = [];
        for edge in ccg --> edge::calls --> node::function {
            if (edge.target.name == func_name) {
                callers.append(edge.source.name);
            }
        }
        report ", ".join(callers) or "none";
    }
}