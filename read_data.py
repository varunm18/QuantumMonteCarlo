import json
import math
import sys

import numpy as np

# region constants
TRADING_YEAR = 252  # trading days/year

SIMULATIONS = 1000

PREDICT_TIME = 1/4  # years
NUM_STEPS = 3
NUM_OUTPUT_QUBITS = 3
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
avg = np.mean(prices)
devSum = 0
for i in range(len(prices)):
    deviation = prices[i] - avg
    squared = deviation**2

    devSum += squared

std = math.sqrt(devSum / (len(prices) + 1))
volatility = std/avg


combinedShift = 0
for i in range(1, len(prices)):
    priceShift = prices[i] - prices[i-1]
    ratio = priceShift / prices[i-1]

    combinedShift += ratio

target_drift = combinedShift / (len(prices) - 1) * (TRADING_YEAR * PREDICT_TIME / NUM_STEPS)


print(f"Trading days: {num_trading_days}")
print(f"Volatility: {volatility}")
print(f"Target drift: {target_drift}")


# Predicted price results
u = math.exp(volatility*math.sqrt(PREDICT_TIME/NUM_STEPS))
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
                totalTime=PREDICT_TIME,
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

