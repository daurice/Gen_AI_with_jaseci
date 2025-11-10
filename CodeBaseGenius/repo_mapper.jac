include repository;  

import from os {path}
import from git {Repo as GitRepo}
import from tempfile {mkdtemp}


# ------------------------------------------------------------
# 1. Walker
# ------------------------------------------------------------
walker RepoMapper {
    has repo: Repository;

    def clone_repo(url: str) -> str {
        temp_dir = mkdtemp();
        GitRepo.clone_from(url, temp_dir);
        return temp_dir;
    }

    def build_file_tree(local_path: str) -> str {
        return build_tree_helper(local_path, local_path, 0);
    }

    def build_tree_helper(full_path: str, base_path: str, level: int) -> str {
        result = "";
        indent = "    " * level;
        result = result + f"{indent}{path.basename(full_path)}/\n";

        sub_indent = "    " * (level + 1);

        items = os.listdir(full_path);
        i = 0;
        while i < len(items) {
            item = items[i];

            if item.startswith(".") {
                i = i + 1;
                continue;
            }

            item_path = path.join(full_path, item);
            if "node_modules" in item_path {
                i = i + 1;
                continue;
            }

            if path.isdir(item_path) {
                result = result + build_tree_helper(item_path, base_path, level + 1);
            } else {
                result = result + f"{sub_indent}{item}\n";
            }

            i = i + 1;
        }
        return result;
    }

    def find_readme(local_path: str) -> str {
        for name in ["README.md", "README.rst", "README.txt"] {
            p = path.join(local_path, name);
            if path.exists(p) {
                with open(p, "r") as f { return f.read(); }
            }
        }
        return "No README found.";
    }

    def summarize_readme(content: str) -> str by llm(
        prompt="Summarize this README in 3 bullet points:"
    );

    can execute with root entry {
        repo.local_path = self.clone_repo(repo.url);
        repo.file_tree = self.build_file_tree(repo.local_path);
        repo.readme_summary = self.summarize_readme(
            self.find_readme(repo.local_path)
        );
    }
}