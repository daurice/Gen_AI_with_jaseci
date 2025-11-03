include repo_mapper;
include code_analyzer;
include doc_genie;
include utils;

import from byllm.llm {Model}
import from git {Repo as GitRepo}
import from tree_sitter {Language, Parser}
import from os {walk, path, makedirs}
import from tempfile {mkdtemp}
import from dotenv {load_dotenv}
import os;

glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

# Tree‑sitter language (optional – works without it)
glob PYTHON_LANGUAGE = Language('build/my-languages.so', 'python');

node Repository {
    has url: str;
    has local_path: str = "";
    has file_tree: str = "";
    has readme_summary: str = "";
    has ccg: dict = {};
    has docs: str = "";
}

walker Supervisor {
    has url: str;
    has repo: Repository = null;

    can generate_documentation with root entry {
        if not self.url {
            report "No repository URL provided.";
            disengage;
        }

       # 1. create shared repo node
        self.repo = here ++> Repository(url=self.url);

        # 2. run the three agents in order
        visit here ++> RepoMapper();
        visit here ++> CodeAnalyzer();
        visit here ++> DocGenie();

        #  3. persist the markdown
        repo_name = self.url.split('/')[-1];
        out_dir   = f"./outputs/{repo_name}";
        makedirs(out_dir, exist_ok=True);
        with open(f"{out_dir}/docs.md", "w") as f {
            f.write(self.repo.docs);
        }

        report {
            "docs": self.repo.docs,
            "output_path": f"{out_dir}/docs.md"
        };
    }
}

with entry {
    load_dotenv();
}
