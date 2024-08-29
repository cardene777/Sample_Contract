// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC6551RegistryBase } from "../functions/ERC6551RegistryBase.sol";
import { Storage as ERC6551Storage } from "../storage/Storage.sol";
import { Schema as ERC6551Schema } from "../storage/Schema.sol";

contract ERC6551RegistryExtention is ERC6551RegistryBase {
    constructor() ERC6551RegistryBase() {}

    function accounts(address account) public view returns (bool) {
        ERC6551Schema.GlobalState storage s = ERC6551Storage.state();
        return s.accounts[account];
    }

    function tokenIdToAccount(uint256 tokenId) public view returns (address) {
        ERC6551Schema.GlobalState storage s = ERC6551Storage.state();
        return s.tokenIdToAccount[tokenId];
    }

    function accountToTokenId(address account) public view returns (uint256) {
        ERC6551Schema.GlobalState storage s = ERC6551Storage.state();
        return s.accountToTokenId[account];
    }
}
