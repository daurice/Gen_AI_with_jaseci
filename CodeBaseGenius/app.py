import streamlit as st
import requests
import os
import time

# --- PAGE CONFIG ---
st.set_page_config(
    page_title="Codebase Genius",
    layout="wide",
)

# --- CONSTANTS ---
BASE_URL = "http://localhost:8000"
GENERATE_ENDPOINT = f"{BASE_URL}/walker/generate_docs"
LIST_ENDPOINT = f"{BASE_URL}/walker/list_docs"
GET_DOC_ENDPOINT = f"{BASE_URL}/walker/get_doc"
# This is the directory Streamlit serves static files from
# We assume streamlit is run from the `agentic_codebase_genius` dir
OUTPUT_DIR = "outputs" 

# --- CSS STYLING ---
st.markdown("""
    <style>
        /* Main container */
        .main .block-container {
            padding-top: 2rem;
            padding-bottom: 2rem;
            max-width: 1000px;
            margin: 0 auto;
        }
        .stTabs [data-baseweb="tab-list"] {
            padding-top: 1rem;
        }
        /* Markdown container for docs */
        .doc-container {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 1.5rem 2rem;
            background-color: #ffffff;
        }
        /* Make images responsive */
        .doc-container img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            border: 1px solid #ddd;
        }
        h1 {
            color: #333;
        }
    </style>
""", unsafe_allow_html=True)

# --- SESSION STATE ---
if 'generated_docs' not in st.session_state:
    st.session_state.generated_docs = []
if 'last_generated' not in st.session_state:
    st.session_state.last_generated = ""

def fetch_generated_docs():
    """Fetches the list of already generated documents."""
    try:
        res = requests.post(LIST_ENDPOINT)
        if res.status_code == 200 and isinstance(res.json().get("report"), list):
            st.session_state.generated_docs = res.json()["report"][0]
        else:
            st.session_state.generated_docs = []
    except requests.exceptions.ConnectionError:
        st.error("Could not connect to the Jac server. Is it running at `http://localhost:8000`?")
        st.session_state.generated_docs = []
    except Exception as e:
        st.error(f"Error listing docs: {e}")
        st.session_state.generated_docs = []

# Fetch docs on first load
if not st.session_state.generated_docs:
    fetch_generated_docs()

# --- UI TABS ---
# Determine which tab to pre-select
if st.session_state.last_generated:
    try:
        default_tab_index = 1
        default_repo_index = st.session_state.generated_docs.index(st.session_state.last_generated)
    except ValueError:
        default_tab_index = 0
        default_repo_index = 0
    st.session_state.last_generated = "" # Clear flag
else:
    default_tab_index = 0
    default_repo_index = 0

tab1, tab2 = st.tabs(["🚀 Generate Documentation", "📚 View Generated Docs"])


# ========================
#   GENERATION INTERFACE
# ========================
with tab1:
    st.title("Codebase Genius 🤖")
    st.markdown("Enter a public GitHub repository URL to generate its documentation. The system will clone, analyze, and produce a full markdown report with an architecture diagram.")

    with st.form(key="repo_form"):
        repo_url = st.text_input(
            "GitHub URL",
            placeholder="e.g., https://github.com/Jaseci-Labs/jac",
        )
        submit_button = st.form_submit_button("Analyze Repository", use_container_width=True, type="primary")

    if submit_button:
        if not repo_url or not repo_url.startswith("https://github.com/"):
            st.error("Please enter a valid public GitHub URL (must start with `https://github.com/`).")
        else:
            repo_name = repo_url.split('/')[-1].replace('.git', '')
            with st.spinner(f"Analyzing {repo_name}... This may take several minutes..."):
                try:
                    start_time = time.time()
                    payload = {"url": repo_url}
                    # Set a long timeout
                    res = requests.post(GENERATE_ENDPOINT, json=payload, timeout=600) # 10 min timeout
                    end_time = time.time()
                    
                    if res.status_code == 200:
                        report = res.json().get("report", [{}])[0]
                        if report.get("status") == "success":
                            st.success(f"Documentation for `{repo_name}` generated successfully in {end_time - start_time:.2f} seconds!")
                            st.balloons()
                            st.subheader("Generation Report")
                            with st.container(border=True):
                                st.markdown(f"**Saved to:** `{report.get('path')}`")
                            
                            # Refresh doc list and set flag to switch tabs
                            fetch_generated_docs()
                            st.session_state.last_generated = repo_name
                            time.sleep(1) # Give a moment for the user to see the success
                            st.rerun() # Rerun to switch tabs
                        else:
                            st.error(f"Error: {report.get('message', 'Unknown error')}")
                    else:
                        st.error(f"Server Error (Code {res.status_code}): {res.text}")
                
                except requests.exceptions.ConnectionError:
                    st.error("Connection Failed: Could not connect to the Jac server. Please ensure it is running at `http://localhost:8000`.")
                except requests.exceptions.ReadTimeout:
                    st.error("Request Timed Out: The analysis took longer than 10 minutes. The server might have failed or is still working. Check the server logs.")
                except Exception as e:
                    st.error(f"An unexpected error occurred: {e}")

# ========================
#   VIEWER INTERFACE
# ========================
with tab2:
    st.header("📚 View Generated Documentation")
    
    col1, col2 = st.columns([3, 1])
    with col1:
        if not st.session_state.generated_docs:
            st.info("No documentation has been generated yet. Use the 'Generate' tab to analyze a repository.")
            selected_repo = None
        else:
            selected_repo = st.selectbox(
                "Select Repository",
                options=st.session_state.generated_docs,
                index=default_repo_index,
                label_visibility="collapsed"
            )
    with col2:
        if st.button("Refresh List 🔄", use_container_width=True):
            fetch_generated_docs()
            if not st.session_state.generated_docs:
                st.toast("No generated documents found.")
            st.rerun()
        
    if selected_repo:
        try:
            payload = {"repo_name": selected_repo}
            res = requests.post(GET_DOC_ENDPOINT, json=payload)
            
            if res.status_code == 200:
                report = res.json().get("report", [{}])[0]
                if report.get("status") == "success":
                    content = report.get("content", "No content found.")
                    st.markdown(f"## Viewing: `{selected_repo}`")
                    with st.container():
                        st.markdown(
                            content, 
                            unsafe_allow_html=True,
                        )
                else:
                    st.error(f"Could not load documentation: {report.get('message')}")
                    if "File not found" in report.get('message', ''):
                        st.warning("This document may have been deleted. Please refresh the list.")
            else:
                st.error(f"Server error fetching doc: {res.status_code}")
        
        except Exception as e:
            st.error(f"Failed to load documentation: {e}")

