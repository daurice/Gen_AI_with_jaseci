import markdown
from py_modules.code_parser import get_llm_summary

def summarize_readme(readme_path: str) -> str:
    if not readme_path or not os.path.exists(readme_path):
        return "No README found."
    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()
    html = markdown.markdown(content)
    text = ' '.join(html.split())
    if len(text) > 3000:
        text = text[:3000]
    prompt = f"Summarize this project README in 3–5 concise sentences:\n\n{text}"
    return get_llm_summary(prompt)