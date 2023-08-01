import json
import requests
from os import getenv

# import qsharp
# from MITRE.QSD.L12 import MainOp


polygon_key = getenv('POLYGON_KEY')
if polygon_key is None:
    raise ValueError('Invalid API key')

ticker = 'AAPL'
start_date = '2023-07-01'
end_date = '2023-08-01'


request = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/range/1/day/{start_date}/{end_date}?adjusted=true&sort=asc&limit=400&apiKey={polygon_key}"

response = requests.get(request)
data = response.json()
if data["status"] not in ("OK", "DELAYED"):
    raise Exception(f"c: {data['status']}")

with open('data.json', 'w') as f:
    json.dump(data, f, indent=4)

# Call MainOp
# print(MainOp.simulate(volatility=0.1, drift=0.1))