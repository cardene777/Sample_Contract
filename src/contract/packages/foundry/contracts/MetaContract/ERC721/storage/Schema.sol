// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Schema {
    /// @custom:storage-location erc7201:ecdysisxyz.erc721.globalstate
    struct GlobalState {
        string name;
        string symbol;
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        uint256 totalSupply;
    }
}
