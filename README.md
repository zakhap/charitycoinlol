# CharityCoin

CharityCoin is a smart contract system built on Ethereum, designed to create a token that supports charitable causes. It is built using Solidity and leverages the OpenZeppelin library for secure, standard compliant ERC20 tokens and reentrancy protection.

## Contracts

### CharityCoin

This is the main token contract. It inherits from OpenZeppelin's ERC20 and ReentrancyGuard contracts. The constructor takes in the total supply of tokens, the name and symbol of the token, and arrays of holders and their corresponding percentages of the total supply. It ensures that the lengths of the holders and percentages arrays match and that the percentages add up to 100. Tokens are minted to the holders based on their percentages.

### IWETH

This is an interface for the Wrapped Ether (WETH) contract. It includes the deposit function, which is payable and allows Ether to be wrapped, and the balanceOf function, which returns the WETH balance of a given account.

### IUniV3

This is an interface for the Uniswap V3 Factory contract. It includes the createPool function, which creates a new liquidity pool for a pair of tokens and returns the address of the pool.

### LiquidityProvider

This contract is responsible for providing liquidity to the CharityCoin token. It inherits from OpenZeppelin's ReentrancyGuard and Ownable contracts. The constructor takes in a charity fee percentage, a charity address, and the addresses of the Uniswap V3 Factory and WETH contracts. It includes functions for registering a token, calculating the price of a token, and buying and selling tokens.

### CharityCoinDeployer

This contract is responsible for deploying new instances of the CharityCoin contract. It inherits from OpenZeppelin's ReentrancyGuard contract. The constructor takes in a charity address and the addresses of the Uniswap V3 Factory and WETH contracts. It includes a function for creating a new CharityCoin token, which emits an event when a new token is created.

## Deployment

The contract is deployed using Hardhat's deployment system. The deployment script is located in `packages/hardhat/deploy/00_deploy_your_contract.ts`. It deploys the CharityCoinDeployer contract using the deployer account and logs the address of the deployed contract.

## Usage

To use this system, deploy the CharityCoinDeployer contract and call the createCharityToken function with the desired parameters. This will create a new CharityCoin token and a corresponding LiquidityProvider contract. The LiquidityProvider contract will initially own 95% of the token supply, and the remaining 5% will be sent to the charity address. Users can then buy and sell tokens through the LiquidityProvider contract, with a portion of each transaction being sent to the charity address.
