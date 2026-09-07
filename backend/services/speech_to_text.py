def listen_voice() -> str:
    """Microphone na hone par seedha terminal se input lega."""
    try:
        query = input("\nYou: ").strip()
        return query
    except Exception:
        return ""