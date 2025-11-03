import from datetime { datetime }

def get_current_datetime() -> str {
    return str(datetime.now().strftime("%Y-%m-%d %H:%M:%S"));
}

def sanitize_filename(name: str) -> str {
    return name.replace("/", "_").replace("\\", "_").replace(" ", "_");
}