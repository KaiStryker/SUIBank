# SUI Bank Smart Contract

## Overview
This project implements a basic bank smart contract on the SUI blockchain, allowing users to deposit and withdraw tokens using unique receipt NFTs.

## Prerequisites
- SUI SDK
- Rust
- Sui CLI

## Getting Started

### Installation
1. Clone the repository
2. Cd into repo
3. Build the project:
```bash
git clone https://github.com/KaiStryker/SUIBank.git
cd SUIBank
sui move build
```
## Running Tests
Execute the test suite using:
```bash
sui move test
```
## Available Tests
* Basic deposit and withdrawal
* Zero deposit prevention
* Insufficient bank balance handling
* Unauthorized withdrawal prevention
* Multiple deposit and withdrawal scenarios

## Contract Features
* Token deposits with unique receipt NFTs
* Withdrawal using original deposit receipts
* Event tracking for deposits and withdrawals
* Error handling for various edge cases

## Project Structure
* `Bank.move`: Main contract implementation
* `bank_test.move`: Comprehensive test suite

## Security Notes
* Only original depositor can withdraw and use receipt
* Receipt NFT is nontransferable
* Checks for minimum deposit amount
* Validates bank balance before withdrawals
