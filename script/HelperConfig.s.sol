// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


abstract contract CodeConstants {
    /* VRF mock values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint256 interval;
        uint256 entranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
        address linkTokenAddress;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }
    
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getOrCreateAnvilEthConfig() private returns (NetworkConfig memory) {
        // check to see if we set an active network config
        if (localNetworkConfig.vrfCoordinatorV2 != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: 0,  // might have to fix this
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,  // doesn't matter, our mock is just gonna work no matter what
            interval: 30, // seconds
            entranceFee: 0.01 ether, // 1e16
            callbackGasLimit: 500000, // 500000 gas
            vrfCoordinatorV2: address(vrfCoordinatorMock),
            linkTokenAddress: address(linkToken)
        });

        return localNetworkConfig;
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 60387374855069028812541229437907786033253565582378195832332737879858035578388, // see subscription at https://vrf.chain.link/
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // key hash next to vrfCoordinator address at https://vrf.chain.link
                interval: 30, // seconds
                entranceFee: 0.01 ether, // 1e16
                callbackGasLimit: 500000, // 500000 gas
                vrfCoordinatorV2: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // https://vrf.chain.link
                linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }
}
