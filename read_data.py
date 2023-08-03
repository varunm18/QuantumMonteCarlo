import json
import math
import sys

import numpy as np

# region constants
TRADING_YEAR = 252  # trading days/year

SIMULATIONS = 1000

NUM_STEPS = 2
NUM_OUTPUT_QUBITS = 5
MEASURING_MAX = True
# endregion


QUANTUM = False
if len(sys.argv) > 1:
    if sys.argv[1] == '-q':
        import qsharp
        from QMC import MainOp  # type: ignore
        QUANTUM = True
    else:
        raise ValueError('Invalid command-line argument')


# load data
with open('data.json', 'r') as f:
    data = json.load(f)

prices = list(map(lambda d: d['c'], data['results']))
assert len(prices) == data['resultsCount']

num_trading_days = len(prices)
trading_years = num_trading_days / TRADING_YEAR


# calculate volatility and drift
log_returns = np.log(np.divide(prices[1:], prices[:-1]))

mean_log_returns = np.mean(log_returns)
variance = np.sqrt(np.sum((log_returns-mean_log_returns)**2)/(len(prices)-2))
volatility = variance/(trading_years**0.5)

target_drift = (mean_log_returns + variance**2/2)/trading_years

print(f"Trading days: {num_trading_days}")
print(f"Volatility: {volatility}")
print(f"Target drift: {target_drift}")


# Predicted price results
u = math.exp(volatility*math.sqrt(trading_years/NUM_STEPS))
d = 1/u
max_price = prices[-1] * math.pow(u, NUM_STEPS)
min_price = prices[-1] * math.pow(d, NUM_STEPS)
print(f"Predicted price range: {min_price} - {max_price}")

if QUANTUM:
    if MEASURING_MAX:
        print("Measuring max")

    probs = {}
    for _ in range(SIMULATIONS):
        result = tuple(
            MainOp.simulate(
                volatility=volatility,
                drift=target_drift,
                totalTime=trading_years,
                steps=NUM_STEPS,
                numOutput=NUM_OUTPUT_QUBITS,
                measureMax=MEASURING_MAX,
            )
        )
        result = int(''.join(map(str, result)), 2)
        angle = 2*math.pi * result * 2**(-NUM_OUTPUT_QUBITS)
        if angle > math.pi:
            angle = 2*math.pi - angle

        prob = math.pow(math.sin(angle/2), 2)

        for k in probs:
            if abs(k - prob) < 1e-3:  # account for floating point error
                prob = k
                break
        probs[prob] = probs.get(prob, 0) + 1

    for prob, occurrences in probs.items():
        print(f"We have {occurrences / SIMULATIONS * 100}% confidence regarding a {prob * 100}% chance of measuring the perceived outcome")

