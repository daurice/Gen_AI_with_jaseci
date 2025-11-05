# ------------------------------------------------------------
# 1. Load the node definition FIRST
# ------------------------------------------------------------
include repository;      # defines node Repository
include repo_mapper;     # defines walker RepoMapper
include code_analyzer;   # defines walker CodeAnalyzer
include doc_genie;       # defines walker DocGenie

# ------------------------------------------------------------
# 2. Python imports
# ------------------------------------------------------------
import from byllm.llm {Model}
import from git {Repo as GitRepo}
import from os {path}
import from tempfile {mkdtemp}
import from dotenv {load_dotenv}


# ------------------------------------------------------------
# 3. Global LLM instance
# ------------------------------------------------------------
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

# ------------------------------------------------------------
# 4. Supervisor walker (API endpoint)
# ------------------------------------------------------------
walker Supervisor {
    has url: str;
    has repo: Repository;

    can generate_documentation with root entry {
        if ( not self.url) {
            report {"error": "No URL supplied"};
            disengage;
        }

        # spawn the shared node
        self.repo = spawn Repository(url=self.url);

        # run the three agents in parallel (order does not matter after spawn)
        spawn RepoMapper(repo=self.repo);
        spawn CodeAnalyzer(repo=self.repo);
        spawn DocGenie(repo=self.repo);

        # write the final markdown file
        repo_name = self.url.split("/")[-1];
        out_dir   = f"./outputs/{repo_name}";
        out_path  = f"{out_dir}/docs.md";

        std.mkdir(out_dir, true, true);
        std.write(out_path, self.repo.docs);
        report [ {
            "docs": self.repo.docs,
            "output_path": out_path
        }];
    }
}

# ------------------------------------------------------------
# 5. Load .env at startup
# ------------------------------------------------------------
with entry {
    load_dotenv();
}