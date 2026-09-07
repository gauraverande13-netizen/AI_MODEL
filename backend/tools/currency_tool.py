import requests

def get_currency_exchange_rate(from_currency: str, to_currency: str) -> str:
    """Fetches the latest live exchange rate between two currencies.
    Args:
        from_currency: 3-letter source currency code (e.g., 'USD', 'EUR').
        to_currency: 3-letter target currency code (e.g., 'INR', 'USD').
    """
    base = from_currency.upper().strip()
    target = to_currency.upper().strip()
    url = f"https://api.frankfurter.dev/v1/latest?base={base}&symbols={target}"
    
    try:
        res = requests.get(url, timeout=5).json()
        if "rates" in res and target in res["rates"]:
            return f"1 {base} = {res['rates'][target]} {target}"
        return f"Rate not found for {base} to {target}."
    except Exception as e:
        return f"Failed to fetch exchange rate: {str(e)}"