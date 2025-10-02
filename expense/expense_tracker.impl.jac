impl ExpenseTracker.start {
    if not [root --> (`?expense)] {
        next = root ++> expense(0.0, "Initial", "Starting expense tracker");
    } else {
        next = [root --> (`?expense)];
    }
    visit next;
}

impl ExpenseTracker.add_expense {
    if [-->] {
        visit [-->];
    } else {
        if self.amount <= 0 {
            print("Error: Amount must be positive.");
            here ++> expense(here.amount, here.category, here.description);
        } else {
            print(f"Added expense: ${self.amount} for {self.category} - {self.description}");
            here ++> expense(self.amount, self.category, self.description);
            disengage;
        }
    }
}

impl ExpenseTracker.view_summary {
    if [-->] {
        expenses = [];
        for exp in [-->] {
            expenses.append({
                "amount": exp.amount,
                "category": exp.category,
                "description": exp.description,
                "timestamp": exp.timestamp
            });
        }
        print(summarize_expenses(expenses));
        disengage;
    } else {
        print("No expenses recorded yet.");
        disengage;
    }
}