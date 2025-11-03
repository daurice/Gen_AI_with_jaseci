node DocGenie {
    def mermaid_diagram(ccg: dict) -> str by llm(
        prompt="Convert the CCG dict into a Mermaid classDiagram / flowchart:"
    );

    def generate_docs(readme: str, tree: str, ccg: dict) -> str by llm(
        method="ReAct",
        tools=([self.mermaid_diagram])
    );

    can execute with generate_documentation entry {
        repo = visitor.repo;
        repo.docs = self.generate_docs(
            repo.readme_summary,
            repo.file_tree,
            repo.ccg
        );
    }
}

sem DocGenie.mermaid_diagram = "Return ONLY the Mermaid code block (```mermaid … ```).";
sem DocGenie.generate_docs = """
Produce a clean Markdown doc with:
# Project Overview
# File Structure
# API Reference (tables + Mermaid diagrams)
""";
