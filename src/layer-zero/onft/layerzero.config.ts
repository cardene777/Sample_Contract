import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'

import type { OAppEdgeConfig, OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const amoyContract: OmniPointHardhat = {
    eid: EndpointId.AMOY_V2_TESTNET,
    contractName: 'MyONFT721',
}

const holeskyContract: OmniPointHardhat = {
    eid: EndpointId.HOLESKY_V2_TESTNET,
    contractName: 'MyONFT721',
}

const DEFAULT_EDGE_CONFIG: OAppEdgeConfig = {
    enforcedOptions: [
        {
            msgType: 1,
            optionType: ExecutorOptionType.LZ_RECEIVE,
            gas: 100_000,
            value: 0,
        },
        {
            msgType: 2,
            optionType: ExecutorOptionType.COMPOSE,
            index: 0,
            gas: 100_000,
            value: 0,
        },
    ],
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: amoyContract,
        },
        {
            contract: holeskyContract,
        },
    ],
    connections: [
        {
            from: amoyContract,
            to: holeskyContract,
            config: DEFAULT_EDGE_CONFIG,
        },
        {
            from: holeskyContract,
            to: amoyContract,
            config: DEFAULT_EDGE_CONFIG,
        },
    ],
}

export default config
