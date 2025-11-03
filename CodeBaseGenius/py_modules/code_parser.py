import tree_sitter
from tree_sitter import Language, Parser
import os

# Load languages
PY_LANGUAGE = Language('build/my-languages.so', 'python')
JAC_LANGUAGE = Language('build/my-languages.so', 'jac')
parser_py = Parser()
parser_py.set_language(PY_LANGUAGE)
parser_jac = Parser()
parser_jac.set_language(JAC_LANGUAGE)

def get_parser(filepath: str):
    if filepath.endswith(".py"):
        return parser_py
    elif filepath.endswith(".jac"):
        return parser_jac
    return None

def extract_functions_and_classes(code: str, parser) -> list:
    tree = parser.parse(bytes(code, "utf8"))
    root = tree.root_node
    items = []
    query_str = """
    (function_definition name: (identifier) @func.name)
    (class_definition name: (identifier) @class.name)
    """
    query = parser.language.query(query_str)
    captures = query.captures(root)
    for node, label in captures:
        name = node.text.decode("utf8")
        start = node.start_point
        end = node.end_point
        items.append({"type": "function" if "func" in label else "class", "name": name, "line": start[0]})
    return items

def get_llm_summary(prompt: str) -> str:
    # Placeholder – will be replaced by actual LLM call via Jac
    return "[LLM Summary Pending]"