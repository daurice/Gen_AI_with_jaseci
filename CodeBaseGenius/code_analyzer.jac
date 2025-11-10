include repository;  

walker CodeAnalyzer {
    has repo: Repository;

    def parse_file(file_path: str) -> dict {
        if (not (file_path.ends_with(".py") or file_path.ends_with(".jac"))) {
            return {};
        }

        code = std.read(file_path);

        json_str = llm(
            prompt=f"""Extract classes and functions. Return ONLY valid JSON:

{{
  "classes": ["ClassName"],
  "functions": ["func(arg)"]
}}

Code:
{code}"""
        );

        # NO try/catch — 0.8.10 cannot handle it
        # Just eval and hope for the best
        return eval(json_str);
    }

    def build_ccg(local_path: str, tree: str) -> dict {
        ccg = {};

        lines = tree.split("\n");
        i = 0;
        while i < len(lines) {
            line = lines[i];
            trimmed = line.strip();

            if (trimmed.ends_with(".py") or trimmed.ends_with(".jac")) {
                indent_level = (len(line) - len(trimmed)) / 4;
                rel_parts = [];
                j = 0;
                while j < len(lines) {
                    l = lines[j];
                    l_trim = l.strip();
                    l_indent = (len(l) - len(l_trim)) / 4;

                    if l_indent <= indent_level and l_trim != "" {
                        rel_parts = rel_parts + [l_trim];
                    }
                    if l_trim == trimmed { break; }
                    j = j + 1;
                }

                rel_path = "/".join(rel_parts);
                full_path = path.join(local_path, rel_path);

                parsed = self.parse_file(full_path);
                ccg[trimmed] = parsed;
            }
            i = i + 1;
        }
        return ccg;
    }

    can execute with root entry {
        repo.ccg = self.build_ccg(repo.local_path, repo.file_tree);
    }
}