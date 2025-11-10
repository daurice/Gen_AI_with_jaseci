# Repository data structure
node Repository {
    has url: str;
    has local_path: str = "";
    has file_tree: str = "";
    has readme_summary: str = "";
    has ccg: dict = {};
    has docs: str = "";
}