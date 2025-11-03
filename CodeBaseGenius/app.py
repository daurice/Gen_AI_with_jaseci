
import streamlit as st, requests, json

st.set_page_config(page_title="Codebase Genius", layout="wide")
st.title("Codebase Genius")

url = st.text_input("Public GitHub repo URL", placeholder="https://github.com/owner/name")

if st.button("Generate Documentation") and url:
    with st.spinner("Cloning → analysing → writing…"):
        r = requests.post(
            "http://localhost:8000/walker/generate_documentation",
            json={"url": url}
        )
        if r.status_code == 200:
            rep = r.json()["reports"][0]
            st.markdown(rep["docs"])
            st.download_button(
                "Download docs.md",
                rep["docs"],
                "docs.md",
                "text/markdown"
            )
        else:
            st.error("Error generating docs.")
