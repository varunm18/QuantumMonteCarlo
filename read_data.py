import json
import math
import sys

import numpy as np

import click

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
target_drift = daily_drift * num_trading_days

print(f"Volatility: {volatility}")
print(f"Daily drift: {daily_drift}")
print(f"Target drift: {target_drift}")

# Variables
totalTime = 1 # In years
steps = 2

# Predicted price results
maxPrice = prices[-1] * math.pow(math.e, (target_drift * totalTime))

if QUANTUM:
    thetaMap = {
        (0, 0, 0): 0,
        (0, 0, 1): math.pi / 4,
        (0, 1, 0): 3/4 * math.pi,
        (0, 1, 1): math.pi,
        (1, 0, 0): 2*math.pi - 3/4*math.pi,
        (1, 0, 1): 2*math.pi - math.pi/2,
        (1, 1, 0): 2*math.pi - math.pi/4,
        (1, 1, 1): 2 * math.pi,
    }

    simulations = 1000

    probs = {}
    for _ in range(simulations):
        val = tuple(MainOp.simulate(volatility=volatility, drift=target_drift, totalTime=totalTime, steps=steps))
        angle = thetaMap[val]
        prob = math.pow(math.sin(angle/2), 2)

        probs[prob] = probs.get(prob, 0) + 1
    
    for key, value in probs.items():
        print(f"We have {value / simulations * 100}% confidence regarding a {key * 100}% chance measuring the perceived outcome~")

    