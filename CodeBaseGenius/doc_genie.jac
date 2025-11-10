include repository;  

walker DocGenie {
    has repo: Repository;

    def mermaid_diagram(ccg: dict) -> str {
        lines = [];

        keys = ccg.keys();
        i = 0;
        while i < len(keys) {
            cls = keys[i];
            info = ccg[cls];

            line = f"class {cls} {{\n";

            if info.has_key("methods") {
                methods = info["methods"];
                j = 0;
                while j < len(methods) {
                    m = methods[j];
                    line = line + f"  +{m}\n";
                    j = j + 1;
                }
            }

            line = line + "}";
            lines = lines + [line];

            i = i + 1;
        }

        diagram = "```mermaid classDiagram\n" + "\n".join(lines) + "\n```";
        return diagram;
    }

    def generate_docs(readme: str, tree: str, ccg: dict) -> str by llm(
        prompt="""
You are a technical writer. Write a **complete markdown documentation** for the
repo using the information below. Return **only** the markdown, no extra text.

--- README SUMMARY ---
{readme}

--- FILE TREE ---
{tree}

--- CLASS / FUNCTION MAP ---
{ccg}

--- MERMAID DIAGRAM (include this verbatim) ---
{mermaid}

**Guidelines**
- Start with a short intro (1-2 sentences).
- Add a **File Tree** section (copy the tree verbatim).
- Add a **Code Overview** section with the mermaid diagram.
- List every public class / function with a short description.
- End with a **Setup / Run** section if a README mentions it.
""",
        mermaid=self.mermaid_diagram(ccg)
    );

    can execute with root entry {
        repo.docs = self.generate_docs(
            repo.readme_summary,
            repo.file_tree,
            repo.ccg
        );
    }
}