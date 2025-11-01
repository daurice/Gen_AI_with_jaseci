## `app.py` – **Streamlit Frontend**

import streamlit as st
import requests
import os

st.set_page_config(page_title="CodeBase Genius", layout="wide")
BASE_URL = "http://localhost:8000"

st.title("CodeBase Genius")
st.markdown("Generate beautiful documentation from any GitHub repo.")

url = st.text_input("GitHub Repository URL", placeholder="https://github.com/user/repo")

col1, col2, col3, col4 = st.columns(4)
with col1:
    if st.button("Clone & Map"):
        if url:
            with st.spinner("Cloning..."):
                res = requests.post(f"{BASE_URL}/walker/submit_url", json={"url": url})
                if res.ok:
                    st.success("Cloned!")
                    st.info(res.json()["reports"][0]["response"])
                else:
                    st.error("Failed to clone.")
        else:
            st.warning("Enter URL")

with col2:
    if st.button("Analyze Code"):
        with st.spinner("Parsing..."):
            res = requests.post(f"{BASE_URL}/walker/analyze")
            if res.ok:
                st.success("Analysis complete!")
                st.info(res.json()["reports"][0]["response"])

with col3:
    if st.button("Generate Docs"):
        with st.spinner("Writing docs..."):
            res = requests.post(f"{BASE_URL}/walker/generate")
            if res.ok:
                st.success("Docs generated!")
                msg = res.json()["reports"][0]["response"]
                st.markdown(msg)

with col4:
    if st.button("Status"):
        res = requests.post(f"{BASE_URL}/walker/status")
        if res.ok:
            st.json(res.json()["reports"][0]["response"], expanded=False)

st.markdown("---")
st.caption("Powered by Jac + Tree-sitter + LLM Agents")