
# Codebase Genius

This is a multi-agent Jac application for generating high-quality documentation from a GitHub repository.

## Main Files
- `main.jac` - Supervisor walker and entry point
- `repo_mapper.jac` - RepoMapper agent
- `code_analyzer.jac` - CodeAnalyzer agent
- `doc_genie.jac` - DocGenie agent
- `utils.jac` - Utility functions
- `.env` - Environment variables (OPENAI_API_KEY, etc.)
- `outputs/` - Generated docs

## Setup
1. Install Python 3.12+
2. Install Jaseci: pip install jaseci
3. Install dependencies: pip install -r requirements.txt
4. Build tree-sitter: Follow tree-sitter docs to build python language.
5. Set OPENAI_API_KEY in .env
6. Run: jac serve main.jac

## Usage
Call the walker via API: POST /walker/generate_documentation 

See app.py for Streamlit frontend.
