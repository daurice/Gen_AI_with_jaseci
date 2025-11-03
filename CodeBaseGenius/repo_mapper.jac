
node RepoMapper {
    def clone_repo(url: str) -> str {
        temp_dir = mkdtemp();
        GitRepo.clone_from(url, temp_dir);
        return temp_dir;
    }

    def build_file_tree(local_path: str) -> str {
        tree = "";
        for (root, dirs, files) in walk(local_path){
                  level = root.replace(local_path, '').count(path.sep);
            indent = ' ' * 4 * level;
            tree += f"{indent}{path.basename(root)}/\n";
            sub_indent = ' ' * 4 * (level + 1);
            for f in files{
                if f.startswith('.') or 'node_modules' in root{ continue; }
                tree += f"{sub_indent}{f}\n";
            }
                
        }
      

        return tree;
    }

    def find_readme(local_path: str) -> str {
        for name in ["README.md", "README.rst", "README.txt"]{
            p = path.join(local_path, name);
            if path.exists(p){
                with open(p, "r") as f{return f.read();
                } 
                break;
                }
            }
             return "No README found.";
        }
       
    

    def summarize_readme(content: str) -> str by llm(
        prompt="Summarize the following README into a concise overview:"
    );

    can execute with generate_documentation entry {
        repo = visitor.repo;
        repo.local_path = self.clone_repo(repo.url);
        repo.file_tree  = self.build_file_tree(repo.local_path);
        repo.readme_summary = self.summarize_readme(
            self.find_readme(repo.local_path)
        );
    }
}

sem RepoMapper.summarize_readme = "High‑level project purpose, key features and quick‑start instructions.";
