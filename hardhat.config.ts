import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-abi-exporter';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-gas-reporter';
import 'hardhat-dependency-compiler';
import 'hardhat-log-remover';
import 'solidity-coverage';

import { HardhatUserConfig } from 'hardhat/config';

import * as forkTasks from './scripts/fork';
import networks from './hardhat.network';

const optimizerEnabled = !process.env.OPTIMIZER_DISABLED;

const config: HardhatUserConfig = {
    abiExporter: {
        path: './abis',
        clear: true,
        flat: true,
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
    },
    gasReporter: {
        currency: 'USD',
        gasPrice: 100,
        enabled: process.env.REPORT_GAS ? true : false,
        coinmarketcap: process.env.COINMARKETCAP_API_KEY,
        maxMethodDiff: 10,
    },
    mocha: {
        timeout: 30000,
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
    networks,
    dependencyCompiler: {
        paths: [
            '@openzeppelin/contracts/token/ERC20/IERC20.sol',
            '@niffl3rreturns/n3r-core/contracts/Ticket.sol',
            '@niffl3rreturns/n3r-core/contracts/PrizeDistributionBuffer.sol',
            '@niffl3rreturns/n3r-core/contracts/prize-pool/YieldSourcePrizePool.sol',
            '@niffl3rreturns/n3r-core/contracts/prize-strategy/PrizeSplitStrategy.sol',
            '@niffl3rreturns/n3r-core/contracts/interfaces/IReserve.sol',
            '@niffl3rreturns/n3r-core/contracts/interfaces/IStrategy.sol',
            '@niffl3rreturns/n3r-core/contracts/interfaces/IPrizeDistributionSource.sol',
            '@niffl3rreturns/n3r-core/contracts/interfaces/IPrizeDistributionBuffer.sol',
            '@niffl3rreturns/n3r-core/contracts/test/ERC20Mintable.sol',
            '@niffl3rreturns/n3r-core/contracts/test/ReserveHarness.sol',
            '@niffl3rreturns/n3r-core/contracts/test/TicketHarness.sol',
        ],
    },
    external: {
        contracts: [
            {
                artifacts: 'node_modules/@niffl3rreturns/n3r-core/artifacts/contracts/',
            },
        ],
    },
    solidity: {
        compilers: [
            {
                version: '0.8.6',
                settings: {
                    optimizer: {
                        enabled: optimizerEnabled,
                        runs: 2000,
                    },
                    evmVersion: 'berlin',
                },
            },
            {
                version: '0.7.6',
                settings: {
                    optimizer: {
                        enabled: optimizerEnabled,
                        runs: 2000,
                    },
                    evmVersion: 'berlin',
                },
            },
        ],
    },
    typechain: {
        outDir: './types',
        target: 'ethers-v5',
    },
};

forkTasks;

export default config;
