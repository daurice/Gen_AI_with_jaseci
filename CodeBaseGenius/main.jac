# Import agents
import from repo_mapper;
import from code_analyzer;
import from doc_genie;

# Import nodes
import from repo_mapper { Repository, FileTree, Readme };
import from code_analyzer { CodeContextGraph };

# Import Python utils
#import py_module from "utils.py" as py_utils;
include utils;
import os;

# -----------------
# SUPERVISOR AGENT
# -----------------

# The Supervisor orchestrates the other agents to generate documentation
walker Supervisor {
    has url: str;
    has repo_node: node::Repository = null;

    can generate_documentation with `root entry {
        log_info(here, f"Supervisor: Starting documentation for {self.url}");
        
        # 1. Clone Repo
        # We use `visit` here because we need the `repo_node` to continue.
        visit here walker::RepoMapper(url = self.url);
        clone_report = visitor.report;
        
        if clone_report["status"] == "error" {
            log_error(here, f"Supervisor: Clone failed. {clone_report['message']}");
            report clone_report;
            disengage;
        }
        
        self.repo_node = clone_report["repo_node"];
        log_info(here, f"Supervisor: Repo cloned to {self.repo_node.local_path}");

        # 2. Run Mapping & Analysis (in parallel)
        log_info(here, "Supervisor: Spawning RepoMapper and CodeAnalyzer...");
        
        # Spawn RepoMapper to map files and summarize README
        spawn self.repo_node walker::RepoMapper.map_files(repo=self.repo_node);
        spawn self.repo_node walker::RepoMapper.summarize_readme(repo=self.repo_node);
        
        # Spawn CodeAnalyzer to build the CCG
        ccg_node = spawn self.repo_node node::CodeContextGraph(name=self.repo_node.name);
        spawn ccg_node walker::CodeAnalyzer.build_ccg(repo=self.repo_node, ccg=ccg_node);
        
        # 3. Wait for results
        # `yield` waits for all spawned walkers (map_files, summarize_readme, build_ccg)
        # that were spawned from this walker's context to complete.
        yield; 
        
        # Retrieve the results (nodes) from the graph
        tree_result = [self.repo_node --> (node::FileTree)];
        readme_result = [self.repo_node --> (node::Readme)];
        
        if not tree_result or not readme_result {
            log_error(here, "Supervisor: Failed to retrieve mapping results.");
            report {"status": "error", "message": "Failed to map repository."};
            disengage;
        }

        log_info(here, "Supervisor: Mapping and Analysis complete.");
        
        # 4. Generate Documentation
        log_info(here, "Supervisor: Spawning DocGenie to assemble final document...");
        
        # We `visit` DocGenie to wait for the final report
        visit ccg_node walker::DocGenie.assemble_documentation(
            repo = self.repo_node,
            tree = tree_result[0],
            readme = readme_result[0],
            ccg = ccg_node
        );
        
        doc_report = visitor.report;
        
        if doc_report["status"] == "success" {
            log_info(here, f"Supervisor: Documentation generated successfully at {doc_report['path']}");
        } else {
            log_error(here, f"Supervisor: Documentation generation failed. {doc_report['message']}");
        }
        
        # 5. Clean up temporary directory
        log_info(here, f"Supervisor: Cleaning up {self.repo_node.local_path}");
        py_utils.cleanup_dir(self.repo_node.local_path);
        
        report doc_report;
    }
}


# -----------------
# API WALKERS
# -----------------

# This walker is exposed via the HTTP server
# It takes a URL and kicks off the Supervisor
walker generate_docs {
    has url: str;
    
    # This spec makes the walker public (no auth required)
    obj __specs__ {
        static has auth: bool = False;
    }

    can execute with `root entry {
        if not self.url or not self.url.startswith("https://github.com/") {
            log_warning(here, "API: Invalid URL received.");
            report {"status": "error", "message": "Invalid or missing 'url'. Must be a public https://github.com/ URL."};
            disengage;
        }

        log_info(here, f"API: Received request for {self.url}");
        
        # We `visit` the supervisor to wait for the entire process
        # to complete before sending an HTTP response.
        visit here walker::Supervisor(url = self.url);
        
        # The report from the Supervisor is passed back as the API response
        report visitor.report;
    }
}

# Walker to serve generated documentation
walker get_doc {
    has repo_name: str;
    
    obj __specs__ {
        static has auth: bool = False;
    }
    
    can execute with `root entry {
        if not self.repo_name {
            report {"status": "error", "message": "Missing 'repo_name'."};
            disengage;
        }
        
        # Sanitize repo_name to prevent directory traversal
        repo_name = os.path.basename(self.repo_name);

        doc_path = os.path.join("outputs", repo_name, "docs.md");
        content = py_utils.get_file_content(doc_path);
        
        report content;
    }
}

# Walker to get a list of generated docs
walker list_docs {
    obj __specs__ {
        static has auth: bool = False;
    }
    
    can execute with `root entry {
        output_dir = "outputs";
        if not os.path.exists(output_dir) {
            report [];
            disengage;
        }
        
        try {
            repos = [d for d in os.listdir(output_dir) if os.path.isdir(os.path.join(output_dir, d))];
            report repos;
        } catch Exception as e {
            report {"status": "error", "message": str(e)};
        }
    }
}

