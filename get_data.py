import json
import requests

from os import getenv


polygon_key = getenv('POLYGON_KEY')
if polygon_key is None:
    raise ValueError('Invalid API key')

ticker = 'AAPL'
start_date = '2022-01-09'
end_date = '2023-01-09'


request = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/range/1/day/{start_date}/{end_date}?adjusted=true&sort=asc&limit=400&apiKey={polygon_key}"

response = requests.get(request)
data = response.json()
if data["status"] != "OK":
    raise Exception(f"Invalid request: {data['status']}")

with open('data.json', 'w') as f:
    json.dump(data, f, indent=4)
