import json
import math
import sys

import numpy as np

import click


# region variables
TOTAL_TIME = 1  # in years
NUM_STEPS = 2

SIMULATIONS = 1000

# endregion


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
assert len(prices) == data['resultsCount']

num_trading_days = len(prices)


log_returns = []
for i in range(1, len(prices)):
    log_returns.append(math.log(prices[i] / prices[i - 1]))

volatility = np.std(log_returns) * math.sqrt(num_trading_days)

daily_drift = np.mean(log_returns)
target_drift = daily_drift * num_trading_days

print(f"Volatility: {volatility}")
print(f"Daily drift: {daily_drift}")
print(f"Target drift: {target_drift}")


# Predicted price results
u = math.exp(volatility*math.sqrt(TOTAL_TIME/NUM_STEPS))
d = 1/u
max_price = prices[-1] * math.pow(u, NUM_STEPS)
min_price = prices[-1] * math.pow(d, NUM_STEPS)

if QUANTUM:
    thetaMap = {  # TODO: change to not be hardcoded
        (0, 0, 0): 0,
        (0, 0, 1): math.pi / 4,
        (0, 1, 0): 3/4 * math.pi,
        (0, 1, 1): math.pi,
        (1, 0, 0): 2*math.pi - 3/4*math.pi,
        (1, 0, 1): 2*math.pi - math.pi/2,
        (1, 1, 0): 2*math.pi - math.pi/4,
        (1, 1, 1): 2 * math.pi,
    }

    probs = {}
    for _ in range(SIMULATIONS):
        val = tuple(MainOp.simulate(volatility=volatility, drift=target_drift, totalTime=TOTAL_TIME, steps=NUM_STEPS))
        angle = thetaMap[val]
        prob = math.pow(math.sin(angle/2), 2)

        for k in probs:
            if abs(k - prob) < 1e-3:  # account for floating point error
                prob = k
                break
        probs[prob] = probs.get(prob, 0) + 1

    for prob, occurrences in probs.items():
        print(f"We have {occurrences / SIMULATIONS * 100}% confidence regarding a {prob * 100}% chance of measuring the perceived outcome")

