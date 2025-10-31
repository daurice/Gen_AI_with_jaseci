#main.jac
#Entry point: HTTP API server + orchestration

import implementation as impl;

walker init {
    has port = 8000;
    can http.serve;
}

walker generate_docs {
    has url;
    has temp_dir, repo_name, output_path;

    # Validate GitHub URL
    if (!url.matches(r"https://github\.com/[\w\-\.]+/[\w\-\.]+(\.git)?$")) {
        report {"error": "Invalid GitHub URL"};
        -> exit;
    }

    repo_name = url.split("/")[-1].replace(".git", "");
    temp_dir = "/tmp/cbg_" + std.uuid();
    output_path = f"./outputs/{repo_name}/docs.md";

    # Step 1: Clone & map repo
    spawn impl.repo_mapper.clone_and_map(url, temp_dir) -> tree, readme;

    # Step 2: Supervisor plans
    plan = spawn impl.supervisor.plan(tree, readme);

    # Step 3: Build CCG
    ccg = spawn impl.code_analyzer.build_ccg(temp_dir, plan);

    # Step 4: Generate docs
    docs_md = spawn impl.doc_genie.generate(ccg, tree, readme, repo_name);

    # Save
    std.file.makedirs(f"./outputs/{repo_name}", exist_ok=true);
    std.file.write(output_path, docs_md);

    report {
        "status": "success",
        "repo": repo_name,
        "documentation": output_path,
        "download": f"/download?repo={repo_name}"
    };
}

walker download {
    has repo;
    path = f"./outputs/{repo}/docs.md";
    if (std.file.exists(path)) {
        -> http.send_file(path, "docs.md");
    } else {
        report {"error": "Documentation not found"};
    }
}