// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC3475 } from "../interfaces/IERC3475.sol";

contract ERC1155WrappedERC3475 is ERC1155 {
    struct Nonce {
        mapping(uint256 => IERC3475.Values) _values;
        mapping(address => uint256) _balances;
        mapping(address => mapping(address => uint256)) _allowances;

        uint256 _activeSupply;
        uint256 _burnedSupply;
        uint256 _redeemedSupply;
    }

    struct Class {
        mapping(uint256 => IERC3475.Values) _values;
        mapping(uint256 => IERC3475.Metadata) _nonceMetadata;
        mapping(uint256 => Nonce) nonces;
    }

    mapping(uint256 => Class) internal _classes;
    mapping(uint256 => IERC3475.Metadata) _classMetadata;

    mapping(address => mapping(address => bool)) operatorApprovals;

    constructor(string memory uri) ERC1155(uri) {}

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data,
        IERC3475.Transaction[] calldata transactions
    ) public {
        _mint(account, id, amount, data);
        _issue(account, id, transactions);
    }

    function burn(
        address account,
        uint256 id,
        uint256 amount,
        IERC3475.Transaction[] calldata transactions
    ) public {
        _burn(account, id, amount);
        _burnERC3475(account, id, transactions);
    }

    function transfer(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        IERC3475.Transaction[] calldata transactions
    ) public {
        _safeTransferFrom(from, to, id, amount, data);
        _transferERC3475(from, to, id, transactions);
    }

    // ERC3475の各種内部処理を以下に実装

    function _issue(
        address _to,
        uint256 id,
        IERC3475.Transaction[] calldata transactions
    ) internal {
        uint256 len = transactions.length;
        for (uint256 i = 0; i < len; i++) {
            Nonce storage nonce = _classes[id].nonces[transactions[i].nonceId];
            nonce._balances[_to] += transactions[i]._amount;
            nonce._activeSupply += transactions[i]._amount;
        }
    }

    function _burnERC3475(
        address _from,
        uint256 id,
        IERC3475.Transaction[] calldata transactions
    ) internal {
        uint256 len = transactions.length;
        for (uint256 i = 0; i < len; i++) {
            Nonce storage nonce = _classes[id].nonces[transactions[i].nonceId];
            require(
                nonce._balances[_from] >= transactions[i]._amount,
                "ERC3475: not enough bond to burn"
            );
            nonce._balances[_from] -= transactions[i]._amount;
            nonce._activeSupply -= transactions[i]._amount;
            nonce._burnedSupply += transactions[i]._amount;
        }
    }

    function _transferERC3475(
        address _from,
        address _to,
        uint256 id,
        IERC3475.Transaction[] calldata transactions
    ) internal {
        uint256 len = transactions.length;
        for (uint256 i = 0; i < len; i++) {
            Nonce storage nonce = _classes[id].nonces[transactions[i].nonceId];
            require(
                nonce._balances[_from] >= transactions[i]._amount,
                "ERC3475: not enough bond to transfer"
            );
            nonce._balances[_from] -= transactions[i]._amount;
            nonce._balances[_to] += transactions[i]._amount;
        }
    }

    // 他のERC3475と同様のメタデータや供給量を管理する関数も実装できます。
}
