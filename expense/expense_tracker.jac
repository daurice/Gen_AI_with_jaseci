"""An Expense Tracker Application"""

import random;
import datetime;
import from byllm.llm { Model }

# glob llm = Model(model_name="gpt-4o", verbose=False);
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

"""Generate a summary of expenses"""
def summarize_expenses(expenses: list) -> str by llm();

walker ExpenseTracker {
    has amount: float = 200.0;
    has category: str = "Food";
    has description: str = "coffee and snacks";

    can start with `root entry;
    can add_expense with expense entry;
    can view_summary with expense entry;
}

node expense {
    has amount: float;
    has category: str;
    has description: str;
    has timestamp: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");
}

# Will run when in CLI mode (not in cloud)
with entry:__main__ {
    root spawn ExpenseTracker();
}