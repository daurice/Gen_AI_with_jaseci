import py_module from "utils.py" as py_utils;
import from byllm.llm { Model };

glob llm = Model(model_name="gemini/gemini-2.0-flash");

# -----------------
# NODES
# -----------------

node Repository {
    has url: str;
    has local_path: str;
    has name: str;
}

node FileTree {
    has structure: str;
}

node Readme {
    has content: str;
    has summary: str;
}

# -----------------
# AGENT / WALKER
# -----------------

walker RepoMapper {
    has url: str;

    can clone_repo with `root entry {
        log_info(here, "RepoMapper: Starting clone...");
        clone_result = py_utils.clone_repo(self.url);

        if clone_result["status"] == "error" {
            log_error(here, clone_result["message"]);
            report {"status": "error", "message": clone_result["message"]};
            disengage;
        }

        repo_node = spawn here node::Repository(
            url = self.url,
            local_path = clone_result["path"],
            name = clone_result["name"]
        );
        log_info(here, "RepoMapper: Clone complete.");
        report {"status": "success", "repo_node": repo_node};
    }

    can map_files(repo: node::Repository) {
        log_info(here, "RepoMapper: Generating file tree...");
        tree_str = py_utils.generate_file_tree(repo.local_path);
        
        file_tree_node = spawn repo node::FileTree(structure = tree_str);
        log_info(here, "RepoMapper: File tree generated.");
        report file_tree_node;
    }

    can summarize_readme(repo: node::Repository) {
        log_info(here, "RepoMapper: Processing README...");
        readme_path = repo.local_path + "/README.md";
        readme_content = py_utils.get_file_content(readme_path);

        if readme_content["status"] == "error" {
            log_warning(here, "No README.md found or readable. Skipping summary.");
            readme_node = spawn repo node::Readme(
                content = "",
                summary = "No README.md file found."
            );
            report readme_node;
        } else {
            log_info(here, "RepoMapper: Summarizing README content...");
            summary = self.gen_summary(readme_content["content"]);
            readme_node = spawn repo node::Readme(
                content = readme_content["content"],
                summary = summary
            );
            log_info(here, "RepoMapper: README summary complete.");
            report readme_node;
        }
    }

    # LLM ability to summarize
    def gen_summary(readme_text: str) -> str by llm(
        prompt="Summarize the following README.md content into a concise project overview. Focus on what the project does and its main purpose. Max 1-2 paragraphs."
    );
}
