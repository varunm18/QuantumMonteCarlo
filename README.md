# QuantumMonteCarlo

MIT's Beaverworks Summer Institute Final project

Implemented a Quantum Monte Carlo paper by Titos Matsakos and Stuart Nield(https://arxiv.org/pdf/2303.09682.pdf) using Q# and Python

### Details:
* Uses Polygon.io Stock API to get the price of stock over certain period of time and loads data into json file
* Reads data from json file and calculates the stock's volatility and drift
* Passes volatility and drift into quantum algorithm which is modeled after the QMC paper above
* Returns various percentages of a possiblity of the stock reaching max or min price and a confidence level in each after many iterations of quantum algoritm

Link to our presentation with results -> https://drive.google.com/file/d/10gqqixr_oAuNH9tQ_hswe8HIE5As7JEw/view?usp=sharing
