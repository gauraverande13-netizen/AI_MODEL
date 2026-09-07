from datetime import datetime
import pytz

def get_current_time(timezone: str = "Asia/Kolkata") -> str:
    """Returns the current date and time for a given timezone.
    Args:
        timezone: The target timezone string (default is 'Asia/Kolkata').
    """
    try:
        tz = pytz.timezone(timezone)
        return datetime.now(tz).strftime("%Y-%m-%d %I:%M %p")
    except Exception as e:
        return f"Error fetching time: {str(e)}"