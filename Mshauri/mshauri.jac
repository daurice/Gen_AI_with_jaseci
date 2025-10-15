import mshauri_nodes;
import from byllm.llm{Model}

glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);
glob free_limit = 5;
glob kra_deadlines = {"income_tax": "2026-06-30", "vat": "2026-07-20"};

# ============================================================================
# UTILITY WALKERS - Core graph operations
# ============================================================================

walker find_user_by_email(email:str) {
    
    # Find and return user node by email
    can visit root, user;
    
    visit {
        if here isa user and here.email == email {
            return here;
        }
        # Continue traversing to child nodes
        visit [-->];
    }
    return None;
}

walker get_root {
    """Get the root node of the graph"""
    can visit root;
    
    visit {
        if here isa root {
            return here;
        }
        visit [-->];
    }
    return here;
}

# ============================================================================
# LANGUAGE DETECTION
# ============================================================================

walker detect_language(text: str) -> str {
    """Detect the language of the given text using LLM"""
    prompt = "Detect the language of the following text: " + text + 
             ". Respond with the language code only (e.g., 'en' for English, 'sw' for Swahili).";
    language = llm.chat(prompt);
    return language.strip();
}

# ============================================================================
# USER MANAGEMENT
# ============================================================================

walker add_user_to_jac(user_name: str, email: str, phoneno: str, 
                       business_type: str, location: str, language: str) {
    """Register a new user in the system"""
    can visit root, user;
    
    # First check if user already exists
    existing_user = spawn find_user_by_email(email=email);
    if existing_user is not None {
        return {"status": "error", "message": "User already exists"};
    }
    
    # Find root node to attach new user
    visit {
        if here isa root {
            # Create new user node
            new_user = spawn node::user(
                name=user_name,
                email=email,
                phoneno=phoneno,
                business_type=business_type,
                location=location,
                language=language
            );
            # Connect user to root
            here ++> new_user;
            return {"status": "success", "message": "User added successfully", "email": email};
        }
        visit [-->];
    }
    
    return {"status": "error", "message": "Root node not found"};
}

walker upgrade_to_premium(email: str) {
    """Upgrade user to premium tier"""
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return {"status": "error", "message": "User doesn't exist"};
    }
    
    user_node.is_premium = True;
    return {"status": "success", "message": "User upgraded to premium successfully"};
}

# ============================================================================
# TRANSACTION MANAGEMENT
# ============================================================================

walker add_transaction(email: str, transactions_list: list) {
    """Add transactions for a user"""
    # Find user
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return {"status": "error", "message": "User doesn't exist"};
    }
    
    # Check free user limit
    if !user_node.is_premium and 
       user_node.entries_count + len(transactions_list) > free_limit {
        return {
            "status": "error", 
            "message": "Free user limit reached. Please upgrade to premium.",
            "current_count": user_node.entries_count,
            "limit": free_limit
        };
    }
    
    # Validation lists
    valid_types = ["income", "sales", "expenses"];
    valid_categories = ["food", "transport", "utilities", "salary", "rent", "other"];
    
    added_transactions = [];
    errors = [];
    
    # Process each transaction
    for t in transactions_list {
        # Validate transaction
        if t.get("trans_type") not in valid_types {
            errors.append("Invalid transaction type: " + str(t.get("trans_type")));
            continue;
        }
        if t.get("category") not in valid_categories {
            errors.append("Invalid category: " + str(t.get("category")));
            continue;
        }
        if t.get("amount", 0) <= 0 {
            errors.append("Invalid amount: " + str(t.get("amount")));
            continue;
        }
        
        # Create transaction node
        trans_node = spawn node::transactions(
            trans_type=t.get("trans_type"),
            description=t.get("description", ""),
            amount=t.get("amount"),
            category=t.get("category"),
            date=t.get("date", "")  # Will use default if empty
        );
        
        # Connect transaction to user
        user_node ++> trans_node;
        added_transactions.append(trans_node.jid);
    }
    
    # Update entry count
    user_node.entries_count += len(added_transactions);
    
    if len(errors) > 0 {
        return {
            "status": "partial",
            "message": "Some transactions added with errors",
            "added": len(added_transactions),
            "errors": errors
        };
    }
    
    return {
        "status": "success",
        "message": "Transactions successfully added",
        "count": len(added_transactions)
    };
}

walker get_user_transactions(email: str) -> list {
    """Get all transactions for a user"""
    can visit user, transactions;
    
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return [];
    }
    
    # Collect all transaction nodes connected to user
    trans_list = [];
    
    visit(user_node) {
        visit [-->] {
            if here isa transactions {
                trans_list.append({
                    "id": here.jid,
                    "type": here.trans_type,
                    "description": here.description,
                    "amount": here.amount,
                    "category": here.category,
                    "date": here.date
                });
            }
        }
    }
    
    return trans_list;
}

# ============================================================================
# REPORTING & SUMMARIES
# ============================================================================

walker get_user_summary(email: str, period: str) -> str {
    """Generate AI-powered financial summary for a given period"""
    can visit user, transactions;
    
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return "User doesn't exist";
    }
    
    # Get all transactions
    all_transactions = spawn get_user_transactions(email=email);
    
    if len(all_transactions) == 0 {
        return "No transactions found for this user";
    }
    
    # Filter by period (simplified - you'll need proper date library)
    filtered_transactions = [];
    
    # For now, include all transactions
    # TODO: Implement proper date filtering based on period
    filtered_transactions = all_transactions;
    
    # Generate summary using LLM
    prompt = "Generate a financial summary in " + user_node.language + 
             " for the following transactions for period " + period + ": " + 
             str(filtered_transactions) + 
             ". Include total income, expenses, and net balance.";
    
    summary = llm.chat(prompt);
    return summary;
}

walker export_report(email: str, format: str) -> str {
    """Export financial report in specified format (PDF/Excel)"""
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return "User doesn't exist";
    }
    
    # Check if premium user for Excel export
    if format.lower() == "excel" and !user_node.is_premium {
        return "Excel export is a premium feature. Please upgrade.";
    }
    
    # Get all transactions
    transactions = spawn get_user_transactions(email=email);
    
    if len(transactions) == 0 {
        return "No transactions to export";
    }
    
    # Generate report using LLM
    prompt = "Generate a financial report in " + format + 
             " format for the following transactions: " + str(transactions) + 
             ". Include headers, totals by category, and summary statistics.";
    
    report = llm.chat(prompt);
    return report;
}

# ============================================================================
# REMINDERS
# ============================================================================

walker send_reminder(email: str, message: str, date: str = "") {
    """Create and attach reminder to user"""
    can visit user, reminders;
    
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return {"status": "error", "message": "User doesn't exist"};
    }
    
    # Create reminder node
    reminder_node = spawn node::reminders(
        message=message,
        date=date,  # Will use default if empty
        sent=False
    );
    
    # Connect reminder to user
    user_node ++> reminder_node;
    
    return {
        "status": "success",
        "message": "Reminder created successfully",
        "reminder_id": reminder_node.jid
    };
}

walker get_user_reminders(email: str) -> list {
    """Get all reminders for a user"""
    can visit user, reminders;
    
    user_node = spawn find_user_by_email(email=email);
    
    if user_node is None {
        return [];
    }
    
    reminder_list = [];
    
    visit(user_node) {
        visit [-->] {
            if here isa reminders {
                reminder_list.append({
                    "id": here.jid,
                    "message": here.message,
                    "date": here.date,
                    "sent": here.sent
                });
            }
        }
    }
    
    return reminder_list;
}

# ============================================================================
# ADMIN FUNCTIONS
# ============================================================================

walker get_all_users() -> list {
    """Get all users in the system"""
    can visit root, user;
    
    user_list = [];
    
    visit {
        if here isa user {
            user_list.append({
                "name": here.name,
                "email": here.email,
                "business_type": here.business_type,
                "location": here.location,
                "is_premium": here.is_premium,
                "entries_count": here.entries_count
            });
        }
        visit [-->];
    }
    
    return user_list;
}

walker get_premium_users() -> list {
    """Get all premium users"""
    all_users = spawn get_all_users();
    premium_users = [];
    
    for u in all_users {
        if u.get("is_premium") == True {
            premium_users.append(u);
        }
    }
    
    return premium_users;
}

walker get_user_count() -> int {
    """Count total users in system"""
    all_users = spawn get_all_users();
    return len(all_users);
}

walker get_kra_deadlines() -> dict {
    """Return KRA tax deadlines"""
    return kra_deadlines;
}

walker admin_dashboard() {
    """Admin dashboard with system statistics"""
    total_users = spawn get_user_count();
    premium_users = spawn get_premium_users();
    
    return {
        "status": "success",
        "total_users": total_users,
        "premium_users": len(premium_users),
        "free_users": total_users - len(premium_users),
        "kra_deadlines": kra_deadlines
    };
}

# ============================================================================
# GRAPH DEFINITION
# ============================================================================

graph mshauri_graph {
    has anchor root_node;
    
    spawn {
        root_node = spawn node::root();
    }
}

