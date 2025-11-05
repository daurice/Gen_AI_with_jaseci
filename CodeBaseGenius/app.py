# app.py
import streamlit as st
import requests
import json
import time

st.set_page_config(page_title="Codebase Genius", layout="wide")
st.title("Codebase Genius")
st.caption("Auto-generate documentation from any public GitHub repo")

url = st.text_input(
    "GitHub Repo URL",
    placeholder="https://github.com/jaseci-labs/jaseci"
)

if st.button("Generate Documentation") and url:
    with st.spinner("Working... This may take 30–90 seconds"):
        try:
            response = requests.post(
                "http://localhost:8000/walker/generate_documentation",
                json={"url": url},
                timeout=180
            )
            response.raise_for_status()
            data = response.json()

            # Debug: Show raw response
            with st.expander("Raw API Response"):
                st.json(data)

            # Extract report
            reports = data.get("reports", [])
            if not reports:
                st.error("No reports returned. Check backend.")
                st.stop()

            report = reports[0]
            docs = report.get("docs", "")
            if not docs.strip():
                st.warning("Docs generated but empty.")
            else:
                st.success("Documentation generated!")
                st.markdown(docs)

                st.download_button(
                    "Download docs.md",
                    docs,
                    "docs.md",
                    "text/markdown"
                )

        except requests.exceptions.ConnectionError:
            st.error("Cannot connect to backend. Is `jac serve main.jac` running?")
        except requests.exceptions.Timeout:
            st.error("Request timed out. Try a smaller repo.")
        except requests.exceptions.HTTPError as e:
            st.error(f"HTTP Error: {e}")
            st.code(response.text)
        except Exception as e:
            st.error(f"Unexpected error: {e}")