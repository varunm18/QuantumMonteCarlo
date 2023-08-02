import click
import json
import re
import requests

from os import getenv


@click.command()
@click.argument('ticker', required=True)
@click.argument('date', required=True, default='2022-01-01/2023-01-01')
def retrieve(ticker, date):
    """
    Retrieve stock data from Polygon.io
    
    TICKER: Stock ticker
    DATE: Date range in the format 'YYYY-MM-DD/YYYY-MM-DD' (start/end)
    """
    if ticker is None or date is None:
        raise ValueError('Invalid command-line argument')
    
    if re.search(r'\d{4}-\d{2}-\d{2}/\d{4}-\d{2}-\d{2}', date) is None:
        raise ValueError('Invalid date format')

    polygon_key = getenv('POLYGON_KEY')
    if polygon_key is None:
        raise ValueError('Invalid API key')

    ticker = 'AAPL'
    start_date, end_date = date.split('/')

    request = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/range/1/day/{start_date}/{end_date}?adjusted=true&sort=asc&limit=50000&apiKey={polygon_key}"

    response = requests.get(request)
    data = response.json()
    if data["status"] not in ("OK", "DELAYED"):
        raise Exception(f"c: {data['status']}")

    with open('data.json', 'w') as f:
        json.dump(data, f, indent=4)


if __name__ == '__main__':
    retrieve()