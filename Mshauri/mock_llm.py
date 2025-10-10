from jaseci.actions.live_actions import jaseci_action

@jaseci_action()
def mock_llm_chat(prompt: str) -> str:
    if "Detect the language" in prompt:
        return "en" if "hello" in prompt.lower() else "sw"
    if "Generate a financial summary" in prompt:
        return "Summary: Total income $1000, expenses $500."
    if "Generate a financial report" in prompt:
        return "Report: Transactions processed successfully."
    return "Mock response"