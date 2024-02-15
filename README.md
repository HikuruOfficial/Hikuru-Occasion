# HikuruQuestsFactoryV1_2

HikuruQuestsFactoryV1_2 is a blockchain-based questing system that leverages smart contract technology to create, manage, and participate in quests. Built on the Ethereum network, it integrates ERC-20, ERC-721, and ERC-1155 tokens for rewards, making it a versatile platform for decentralized quest and gaming applications.

## Features

- **Quest Creation:** Users can create quests with custom start and end times, rewards, and participation limits.
- **Reward System:** Supports various types of rewards, including native tokens, ERC-20 tokens, and ERC-1155 tokens for both individual and random winner rewards.
- **Referral System:** Incorporates a referral system to incentivize users to invite others to participate in quests.
- **Yield and Gas Claiming:** Integration with the IBlast interface for claiming yield and gas, optimizing contract interactions and transactions.
- **Upgradeable:** Utilizes UUPS (Universal Upgradeable Proxy Standard) for easy and secure contract upgrades.

## Quick Start

### Prerequisites

- Node.js installed (version 12+ recommended)
- Hardhat installed for compiling and deploying contracts
- An Ethereum wallet with testnet or mainnet ETH for deploying contracts

### Installation

1. Clone the repository:

```bash
git clone https://github.com/your-repository/HikuruQuestsFactory.git
cd HikuruQuestsFactory
```

2. Install dependencies:

```bash
npm install
```

3. Compile the smart contracts:

```bash
npx hardhat compile
```

### Deploying the Contract

1. Create a `.env` file in the root directory with your Ethereum wallet private key and Alchemy/RPC URL:

```
PRIVATE_KEY=your_private_key_here
ALCHEMY_URL=https://eth-mainnet.alchemyapi.io/v2/your_api_key_here
```

2. Deploy to the desired network (e.g., Rinkeby testnet):

```bash
npx hardhat run scripts/deploy.ts --network blast_sepolia
```

## Usage

### Creating a Quest

Use the `questCreation` function to create a new quest. Specify the reward type, start/end times, maximum participation, reward per user, and total reward pool:

```solidity
function questCreation(
    uint256 _questsRewardType,
    uint256 _startTime,
    uint256 _endTime,
    ...
) external payable
```

### Participating in a Quest

Participants can join a quest using the `acceptanceParticipation` function, optionally providing a referral address:

```solidity
function acceptanceParticipation(uint256 _hikuruQid, address _referral) external
```

### Claiming Rewards

The contract owner or quest creator can distribute rewards to winners using internal functions triggered by the quest's completion criteria.

## Interface

The contract exposes various public and external functions for interacting with quests, including creating, modifying, participating in, and querying quest details.

## Security

This project utilizes OpenZeppelin's upgradeable contracts for added security and upgradeability. Always ensure safe contract interaction practices.

## Contributing

Contributions are welcome! Please read the contributing guidelines before starting any work.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE) file for details.
