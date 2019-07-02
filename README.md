# BouncerProxy contract
> "With economic incentive" for miners.
Bouncer identity proxy smart contract that executes meta transactions for etherless accounts.

A way for etherless accounts to transact with the blockchain through an identity proxy without paying any gas.

In this game there are mainly three actors playing:
- the etherless account
- the miner (basically the account that will pay the blockchain fee)
- the bouncer proxy smart contract

The etherless accounts needs to sign an hashed message which contains:
- the bouncer proxy contract address
- its address
- the receiver of the transaction that will be broadcasted by the so called miner
- the transaction object field value
- the transaction object field data
- an asset to be used as miner reward (e.g ETH or ERC20 token)
- the amount of the asset used as miner reward
- the etherless account nonce stored in the bouncer proxy contract

A simple scenario would be an account which owns its bouncer proxy contract and eventually allows whitelisted accounts to use it.
The proxy contract could be funded by some ETH or ERC20s and could use its assets as reward to incetivize other accounts to mine the meta transactions.

## Quick start
- `$ yarn`
- `$ yarn test:dev`

In the test an account is able to interact with a smart contract without paying any gas and rewards the transaction miner.

This repository aims to help the understanding of meta transactions and is inspired by the work of [@austingriffith](https://twitter.com/austingriffith) that can be found on [Github](https://github.com/austintgriffith/bouncer-proxy).