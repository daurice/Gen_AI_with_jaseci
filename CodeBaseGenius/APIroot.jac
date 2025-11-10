# ------------------------------------------------------------
# api_root.jac – shows the API catalogue
# ------------------------------------------------------------
walker ApiRoot {

    can list_endpoints with root entry {
        report {
            "message": "Jac API Server",
            "endpoints": {
                "POST /user/create":          "Create a new user",
                "POST /user/login":           "Authenticate and get token",
                "GET /functions":             "List all available functions",
                "GET /walkers":               "List all available walkers",
                "GET /function/<name>":       "Get function signature",
                "GET /walker/<name>":          "Get walker fields",
                "POST /function/<name>":      "Call a function",
                "POST /walker/<name>":        "Spawn a walker",
                "GET /page/<name>":            "Render HTML page for client function"
            }
        };
    }
}
