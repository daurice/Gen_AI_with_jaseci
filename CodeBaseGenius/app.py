
import streamlit as st
import requests

st.set_page_config(page_title="Codebase Genius", layout="wide")

st.title("📚 Codebase Genius")

repo_url = st.text_input("Enter Public GitHub Repository URL:")

if st.button("Generate Documentation"):
    if repo_url:
        with st.spinner("Generating..."):
            res = requests.post("http://localhost:8000/walker/generate_documentation", json={"url": repo_url})
            if res.status_code == 200:
                data = res.json().get("reports", [{}])[0]
                st.markdown(data.get("docs", "No docs generated."))
                st.download_button("Download Docs", data.get("docs", ""), "docs.md")
            else:
                st.error("Error generating docs.")