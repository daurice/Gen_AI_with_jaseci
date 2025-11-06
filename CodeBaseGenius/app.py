# --------------------------------------------------------------
#  Codebase Genius – Gemini + Jaseci Streamlit App
# --------------------------------------------------------------
#  Author: Doris Mugah
#  Description:
#    Generates beautiful documentation from any public GitHub repo
#    using Google Gemini 1.5 Flash and a Jaseci backend.
# --------------------------------------------------------------

import streamlit as st
import requests
import os
from dotenv import load_dotenv
import re

# --------------------------------------------------------------
#  Load Environment Variables
# --------------------------------------------------------------
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
SENDER_EMAIL = os.getenv("SENDER_EMAIL")
SENDER_PASSWORD = os.getenv("SENDER_PASSWORD")
SENDER_NAME = os.getenv("SENDER_NAME")
BASE_URL = os.getenv("JASECI_BASE_URL", "http://localhost:8000")

# --------------------------------------------------------------
#  Validate Environment Variables
# --------------------------------------------------------------
missing_vars = [
    var for var in ["GEMINI_API_KEY", "SENDER_EMAIL", "SENDER_PASSWORD"]
    if not os.getenv(var)
]

if missing_vars:
    st.error(
        f"""
        ⚠️ Missing environment variables: {', '.join(missing_vars)}

        Please add them to your `.env` file, for example:
        ```
        GEMINI_API_KEY=your-gemini-api-key
        SENDER_EMAIL=your-email@example.com
        SENDER_PASSWORD=your-password
        SENDER_NAME=Your Name
        JASECI_BASE_URL=http://localhost:8000
        ```
        """
    )
    st.stop()

# --------------------------------------------------------------
#  Streamlit Page Configuration
# --------------------------------------------------------------
st.set_page_config(
    page_title="Codebase Genius",
    page_icon="🧠",
    layout="centered",
)

# --------------------------------------------------------------
#  Custom Styles
# --------------------------------------------------------------
st.markdown(
    """
    <style>
        .main > div {max-width: 950px; padding: 2rem;}
        .stTextInput > div > div > input {font-size: 1.1rem; padding: 0.8rem;}
        .stButton > button {height: 3rem; font-weight: 600;}
        .output-box {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 12px;
            border: 1px solid #e0e0e0;
            font-family: 'Courier New', monospace;
            white-space: pre-wrap;
        }
        .footer {
            text-align: center;
            margin-top: 3rem;
            color: #666;
            font-size: 0.9rem;
        }
    </style>
    """,
    unsafe_allow_html=True,
)

# --------------------------------------------------------------
#  UI Header
# --------------------------------------------------------------
st.title("🧠 Codebase Genius")
st.caption(
    f"Generate **beautiful documentation** from public GitHub repos — powered by **Gemini** and **Jaseci**\n\n"
    f"Logged in as **{SENDER_NAME or SENDER_EMAIL}**"
)

# --------------------------------------------------------------
#  Input Section
# --------------------------------------------------------------
url = st.text_input(
    "GitHub Repo URL",
    placeholder="https://github.com/username/repository",
    help="Public repositories only. Large repos may take 60–90 seconds.",
)

col1, col2 = st.columns([1, 4])
with col1:
    generate = st.button(" Generate Docs", type="primary", use_container_width=True)
with col2:
    st.markdown("<br>", unsafe_allow_html=True)
    st.caption("**Gemini 1.5 Flash** • Fast & Smart")

# --------------------------------------------------------------
#  Main Logic
# --------------------------------------------------------------
def is_valid_github_url(url):
    pattern = r"^https?://(www\.)?github\.com/[^/]+/[^/]+/?$"
    return re.match(pattern, url.strip()) is not None

if generate and url:
    with st.spinner("Cloning repo, analyzing code, writing documentation…"):
        try:
            # Step 1: Login to Jaseci
            login_url = f"{BASE_URL}/user/login"
            login_payload = {"email": SENDER_EMAIL, "password": SENDER_PASSWORD}
            login_resp = requests.post(login_url, json=login_payload, timeout=20)
            login_resp.raise_for_status()

            token = login_resp.json().get("token")
            if not token:
                raise ValueError("Login failed — no token returned. Check your credentials.")

            # Step 2: Call Jaseci walker
            walker_url = f"{BASE_URL}/walker/Supervisor/generate_documentation"
            headers = {"Authorization": f"Bearer {token}"}
            payload = {"url": url.strip()}

            resp = requests.post(walker_url, json=payload, headers=headers, timeout=180)
            resp.raise_for_status()
            data = resp.json()

            # Step 3: Handle response
            reports = data.get("reports", [])
            if not reports:
                st.error("No response received from Jaseci server.")
                st.stop()

            docs_md = reports[0].get("docs", "")
            output_path = reports[0].get("output_path", "docs.md")

            if docs_md.strip():
                st.success("✅ Documentation generated successfully!")
                st.markdown("---")
                with st.container():
                    st.markdown('<div class="output-box">', unsafe_allow_html=True)
                    st.markdown(docs_md)
                    st.markdown('</div>', unsafe_allow_html=True)

                st.download_button(
                    label="📥 Download docs.md",
                    data=docs_md,
                    file_name=os.path.basename(output_path),
                    mime="text/markdown",
                    use_container_width=True,
                )
            else:
                st.warning("Documentation generated, but content is empty.")

        except requests.exceptions.ConnectionError:
            st.error(
                "🚫 Cannot connect to the Jaseci server.\n\n"
                "Make sure your backend is running:\n```bash\njac serve main.jac\n```"
            )
        except requests.exceptions.Timeout:
            st.error("⏳ The request timed out. Try again with a smaller repository.")
        except requests.exceptions.HTTPError as e:
            st.error(f"❌ Server error: {e.response.status_code}")
            try:
                st.code(e.response.text, language="json")
            except Exception:
                pass
        except ValueError as e:
            st.error(f"⚠️ Authentication error: {str(e)}")
        except Exception as e:
            st.error(f"🔥 Unexpected error: {str(e)}")

# --------------------------------------------------------------
#  Footer
# --------------------------------------------------------------
st.markdown("---")
st.markdown(
    """
    <div class="footer">
        Built with ❤️ using <strong>Gemini</strong> + <strong>Jaseci</strong> • 
        <a href="https://github.com/daurice/Codebase-Genius" target="_blank">View on GitHub</a>
    </div>
    """,
    unsafe_allow_html=True,
)
