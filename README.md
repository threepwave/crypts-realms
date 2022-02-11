```
/*****************************************************
0000000                                        0000000
0001100  Crypts and Caverns x Realms           0001100
0001100     Lure Adventurers to their demise   0001100
0003300                                        0003300
*****************************************************/
```

**This repository houses the code for our integration with Realms.** If you're looking for the main Crypts and Caverns contracts which are already deployed, [you'll find them here](https://github.com/threepwave/cryptsandcaverns).

# Project Structure
There are three main sections to the project:
* `contracts` - Contains all smart contracts and interfaces
* `scripts` - Contains scripts to develop and ad hoc test. For example, `mainnet/build.js` will deploy the staking contract, stake a dungeon, and verify that its owner is still correct.
* `test` - Contains tests for our contracts. Most tests will be integration tests and we will likely have 'edge case' tests such as staking/unstaking 1000 dungeons at a time. *TBD How we handle cross-chain tests from Mainnet->Starknet.*

# Mainnet Setup

Mainnet files are written in solidity and located in the `mainnet` folder of each section. 

We use [hardhat](https://github.com/nomiclabs/hardhat) to compile, test, and deploy contracts on the Ethereum blockchain.

Ethereum contracts end in `.sol` and are housed in the `./contracts/mainnet` folder.

1. Installation
```
npm install
```

2. Build / Compile
Start a local node in one terminal: `npm run node `
Run the build script: `npm run build` or `npm run buildwatch`

3. Test
```
npm run test
```

4. Deploy
*Uncomment out the 'deploy' lines in `hardhat.config.js`
```
npx hardhat deply --network rinkeby
```


# Starknet Setup on Mac M1

# Starknet / Cairo

Starknet is a Layer 2 that uses zkRollup technology to offer a low-gas, fast-transaction rollup built on top of ethereum. Transactions are batched and submitted to L1 over time.

Starknet uses the language 'Cairo' which is similar to Solidity but has its own quirks.

Starknet contracts end in `.cairo` and are housed in the `./contracts/starknet` folder.

We use hardhat and the [starknet-hardhat-plugin](https://github.com/Shard-Labs/starknet-hardhat-plugin) to compile and deploy Cairo contracts.


## Installation
1. Install hardhat and dependencies: `npm install`
2. Install [starknet-devnet](https://github.com/Shard-Labs/starknet-devnet) local node: `pip install starknet-devnet`
3. Install [cairo-lang](): `pip install cairo-lang`

For all of these on one line: `npm install; pip install starknet-devnet; pip install cairo-lang`

## Build / Compile
We use [`hardhat-starknet`](https://github.com/Shard-Labs/starknet-hardhat-plugin) to build and compile our Cairo contracts. 
1. Run `npm run nodestarknet` in a terminal to start a local node. This will listen for queries.
2. Run `npm run buildstarknet` in another terminal to compile and run cairo contracts.

## Deploy 
??? *(Fill in when we get here)*

## Test
1. Run `npm run nodestarknet` in a terminal to start a local node. This will listen for queries.
2. Run `npm run teststarknet` in another terminal to compile and run tests.




# Contributors
* [milan](https://twitter.com/milancermak)
* [threepwave](https://twitter.com/threepwave)