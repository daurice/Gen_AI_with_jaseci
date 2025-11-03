import py_module from "utils.py" as py_utils;
import from repo_mapper; # Import node definitions

# -----------------
# GRAPH NODES & EDGES
# (Code Context Graph - CCG)
# -----------------

node CodeContextGraph {
    # This node acts as the root for all code analysis of a repo
    has name: str;
}

node Module {
    has path: str; # Relative path
    has content: str;
}

node Class {
    has name: str;
    has docstring: str;
}

node Function {
    has name: str;
    has args: list;
    has arg_types: dict;
    has return_type: str;
    has docstring: str;
    has calls: list; # List of strings of what it calls
}

# -----------------
# GRAPH EDGES
# -----------------

edge Imports { }      # Connects Module to Module (or Module to external lib name)
edge Calls { 
    has call_str: str;
}        # Connects Function to Function/Method
edge Defines { }      # Connects Module to Class/Function
edge Inherits { }     # Connects Class to Class
edge Contains { }     # Connects Class to Function (method)

# -----------------
# AGENT / WALKER
# -----------------

walker CodeAnalyzer {
    
    can build_ccg(repo: node::Repository, ccg: node::CodeContextGraph) {
        log_info(here, "CodeAnalyzer: Building Code Context Graph (CCG)...");
        code_files = py_utils.find_code_files(repo.local_path);
        
        all_modules = {}; # Store spawned modules for linking
        all_ast_data = {}; # Store AST data for second pass (linking)
        all_elements = {}; # Map element name (e.g., "mod.Class") to node

        # -----------------
        # First Pass: Create all nodes
        # -----------------
        log_info(here, "CodeAnalyzer: Pass 1 - Creating nodes...");
        for file_path in code_files {
            full_path = repo.local_path + "/" + file_path;
            content_res = py_utils.get_file_content(full_path);
            
            if content_res["status"] == "success" {
                module_node = spawn ccg node::Module(
                    path = file_path,
                    content = content_res["content"]
                );
                ccg +[edge::Defines(label=file_path)]+> module_node;
                all_modules[file_path] = module_node;
                all_elements[file_path] = module_node;

                # Parse the code
                if file_path.endswith(".py") {
                    ast_res = py_utils.parse_python_code(content_res["content"], file_path);
                    if ast_res["status"] == "success" {
                        ast_data = ast_res["data"];
                        all_ast_data[file_path] = ast_data;

                        # Create Class nodes
                        for class_info in ast_data["classes"] {
                            class_name = class_info["name"];
                            class_id = file_path + "::" + class_name;
                            class_node = spawn module_node node::Class(
                                name = class_name,
                                docstring = str(class_info["docstring"])
                            );
                            module_node +[edge::Defines(label=class_name)]+> class_node;
                            all_elements[class_id] = class_node;

                            # Create Method (Function) nodes
                            for method_info in class_info["methods"] {
                                method_name = method_info["name"];
                                method_id = class_id + "::" + method_name;
                                method_node = spawn class_node node::Function(
                                    name = method_name,
                                    args = method_info["args"],
                                    arg_types = method_info["arg_types"],
                                    return_type = str(method_info["return_type"]),
                                    docstring = str(method_info["docstring"]),
                                    calls = method_info["calls"]
                                );
                                class_node +[edge::Contains(label=method_name)]+> method_node;
                                all_elements[method_id] = method_node;
                            }
                        }
                        
                        # Create Function nodes
                        for func_info in ast_data["functions"] {
                            func_name = func_info["name"];
                            func_id = file_path + "::" + func_name;
                            func_node = spawn module_node node::Function(
                                name = func_info["name"],
                                args = func_info["args"],
                                arg_types = func_info["arg_types"],
                                return_type = str(func_info["return_type"]),
                                docstring = str(func_info["docstring"]),
                                calls = func_info["calls"]
                            );
                            module_node +[edge::Defines(label=func_name)]+> func_node;
                            all_elements[func_id] = func_node;
                        }
                    }
                }
                # TODO: Add Jac parser logic here
            }
        }

        # -----------------
        # Second Pass: Create edges (Inheritance, Calls)
        # -----------------
        log_info(here, "CodeAnalyzer: Pass 2 - Creating edges...");
        
        for file_path, ast_data in all_ast_data.items() {
            # --- Link Inheritance ---
            for class_info in ast_data["classes"] {
                child_id = file_path + "::" + class_info["name"];
                child_class_node = all_elements.get(child_id);
                
                if child_class_node {
                    for base_name in class_info["inherits"] {
                        # This is a simplification. We look for the base class
                        # by name *anywhere* in the scanned elements.
                        # A full implementation would check imports.
                        parent_node = null;
                        for (id, node) in all_elements.items() {
                            if node.kind == "Class" and node.context["name"] == base_name {
                                parent_node = node;
                                break;
                            }
                        }
                        
                        if parent_node {
                            child_class_node +[edge::Inherits()]+> parent_node;
                        }
                    }
                }
            }
            
            # --- Link Calls ---
            # This is complex. We'll link calls we can find *within* the repo.
            
            # Get all functions/methods from this file
            file_funcs = [all_elements[id] for id in all_elements.keys() if id.startswith(file_path) and all_elements[id].kind == "Function"];

            for func_node in file_funcs {
                from_id = jid(func_node); # Get Jac ID
                
                for call_str in func_node.context["calls"] {
                    # Try to resolve call_str
                    # e.g., "self.other_method" -> find in same class
                    # e.g., "util_func" -> find in same module or via imports
                    
                    target_node = null;

                    # Case 1: self.method
                    if call_str.startswith("self.") {
                        method_name = call_str.split(".")[1];
                        # Find the class this function belongs to
                        class_node = [func_node <--(edge::Contains)- (node::Class)];
                        if class_node {
                            # Look for method in same class
                            target_node_list = [class_node[0] --(edge::Contains)--> (node::Function, name == method_name)];
                            if target_node_list {
                                target_node = target_node_list[0];
                            }
                        }
                    } 
                    # Case 2: local function call
                    else {
                        # Look for function in same module
                        mod_node = [func_node <--(edge::Defines)- (node::Module)];
                        if mod_node {
                             target_node_list = [mod_node[0] --(edge::Defines)--> (node::Function, name == call_str)];
                             if target_node_list {
                                 target_node = target_node_list[0];
                             }
                        }
                    }
                    
                    # TODO: Add more heuristics (imports, etc.)
                    
                    if target_node {
                        func_node +[edge::Calls(call_str=call_str)]+> target_node;
                    }
                }
            }
        }

        log_info(here, "CodeAnalyzer: CCG Build Complete.");
        report ccg;
    }

    # API for querying the graph
    can find_callers(ccg: node::CodeContextGraph, func_name: str) -> list {
        # Finds all functions that call a function with `func_name`
        callers = [];
        target_funcs = [ccg --> (node::Function, name == func_name)];
        for func in target_funcs {
            incoming_calls = [func <--(edge::Calls)- (node::Function)];
            for caller in incoming_calls {
                callers.append(caller.context["name"]);
            }
        }
        report callers;
    }
}

