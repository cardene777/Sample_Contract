// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Schema {
    /// @custom:storage-location erc7201:ecdysisxyz.erc721.globalstate
    struct GlobalState {
        // tba => is tba
        mapping(address => bool) accounts;
        // tokenId => tba
        mapping(uint256 => address) tokenIdToAccount;
        // tba => tokenId
        mapping(address => uint256) accountToTokenId;

        uint256 state;
    }
}
