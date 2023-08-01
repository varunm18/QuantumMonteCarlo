import json
import math
import sys

import numpy as np

QUANTUM = False
if len(sys.argv) > 1:
    if sys.argv[1] == '-q':
        import qsharp
        from QMC import MainOp  # type: ignore
        QUANTUM = True
    else:
        raise ValueError('Invalid command-line argument')


with open('data.json', 'r') as f:
    data = json.load(f)

prices = list(map(lambda d: d['c'], data['results']))
# print(prices)

num_trading_days = len(prices)

log_returns = []
for i in range(1, len(prices)):
    log_returns.append(math.log(prices[i] / prices[i - 1]))

volatility = np.std(log_returns)*math.sqrt(num_trading_days)

daily_drift = np.mean(log_returns)
annual_drift = daily_drift * num_trading_days

print(f"Volatility: {volatility}")
print(f"Daily drift: {daily_drift}")
print(f"Annual drift: {annual_drift}")

if QUANTUM:
    values = {}
    for _ in range(100):
        val = tuple(MainOp.simulate(volatility=volatility, drift=annual_drift))
        values[val] = values.get(val, 0) + 1

    print(values)