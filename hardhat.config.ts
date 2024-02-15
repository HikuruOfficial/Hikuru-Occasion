import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades"


// const config: HardhatUserConfig = {
//   defaultNetwork: "localhost",
//   networks: {
//     localhost: {
//       url: "http://127.0.0.1:8545" // Replace with your local node's RPC URL if different
//     },
//     blast_sepolia: {
//       url: 'https://sepolia.blast.io',
//       accounts: [`${process.env.PRIVATE_KEY}`]
//     },
//   },
//   solidity: {
//     version: "0.8.21",
//     settings: {
//       evmVersion: "paris",
//       optimizer: {
//         enabled: true,
//         runs: 1000,
//       },
//     },
//   },
//   etherscan: {
//     apiKey: {
//       blast_sepolia: "blast_sepolia", // apiKey is not required, just set a placeholder
//     },
//     customChains: [
//       {
//         network: "blast_sepolia",
//         chainId: 168587773,
//         urls: {
//           apiURL: "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
//           browserURL: "https://testnet.blastscan.io"
//         }
//       }
//     ]
//   },
  
// };

const config: HardhatUserConfig = {
  defaultNetwork: "localhost",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545" // Replace with your local node's RPC URL if different
    },
    blast_sepolia: {
      url: 'https://sepolia.blast.io',
      accounts: [`${process.env.PRIVATE_KEY}`]
    },
  },
  solidity: {
    version: "0.8.20",
    settings: {
      evmVersion: "paris",
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  etherscan: {
    apiKey: {
      blast_sepolia: "blast_sepolia", // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: "blast_sepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
          browserURL: "https://testnet.blastscan.io"
        }
      }
    ]
  },
  
};


export default config;
