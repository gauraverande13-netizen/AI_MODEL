import pyttsx3

engine = pyttsx3.init()
engine.setProperty('rate', 170)

def speak_text(text: str):
    """Speaks out the provided text."""
    print(f"\nAI: {text}")
    engine.say(text)
    engine.runAndWait()