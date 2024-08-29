// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC3475 } from "../interfaces/IERC3475.sol";

contract ERC3475Compatible is IERC1155, ERC1155Burnable, ERC1155Supply, Ownable {
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

    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {
        // 初期化コードは省略
    }

    function mint(address account, uint256 tokenId, uint256 amount, bytes memory data) public onlyOwner {
        _mint(account, tokenId, amount, data);
    }

    function burn(address account, uint256 tokenId, uint256 amount) public override {
        _burn(account, tokenId, amount);
    }

    function setClassAndNonce(uint256 classId, uint256 nonceId, IERC3475.Values memory values) public onlyOwner {
        uint256 tokenId = _getTokenId(classId, nonceId);
        _classes[classId].nonces[nonceId]._values[tokenId] = values;
    }

    function getTokenId(uint256 classId, uint256 nonceId) public pure returns (uint256) {
        return _getTokenId(classId, nonceId);
    }

    function nonceMetadata(uint256 classId, uint256 metadataId) external view returns (IERC3475.Metadata memory) {
        return _classes[classId]._nonceMetadata[metadataId];
    }

    function classValues(uint256 classId, uint256 metadataId) external view returns (IERC3475.Values memory) {
        return _classes[classId]._values[metadataId];
    }

    function nonceValues(uint256 classId, uint256 nonceId, uint256 metadataId) external view returns (IERC3475.Values memory) {
        return _classes[classId].nonces[nonceId]._values[metadataId];
    }

    function _getTokenId(uint256 classId, uint256 nonceId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(classId, nonceId)));
    }

    // IERC1155関数の実装
    function balanceOf(address account, uint256 id) public view override(ERC1155, IERC1155) returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        (uint256 classId, uint256 nonceId) = _parseTokenId(id);
        return _classes[classId].nonces[nonceId]._balances[account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view override(ERC1155, IERC1155) returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public override(ERC1155, IERC1155) {
        require(operator != msg.sender, "ERC1155: setting approval status for self");
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view override(ERC1155, IERC1155) returns (bool) {
        return _isApprovedForAll(account, operator);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override(ERC1155, IERC1155) {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFromCustom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override(ERC1155, IERC1155) {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFromCustom(from, to, ids, amounts, data);
    }

    // 内部関数
    function _safeTransferFromCustom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: transfer to the zero address");
        (uint256 classId, uint256 nonceId) = _parseTokenId(id);

        Nonce storage nonce = _classes[classId].nonces[nonceId];
        require(nonce._balances[from] >= amount, "ERC1155: insufficient balance for transfer");

        nonce._balances[from] -= amount;
        nonce._balances[to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function _safeBatchTransferFromCustom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            (uint256 classId, uint256 nonceId) = _parseTokenId(id);

            Nonce storage nonce = _classes[classId].nonces[nonceId];
            require(nonce._balances[from] >= amount, "ERC1155: insufficient balance for transfer");

            nonce._balances[from] -= amount;
            nonce._balances[to] += amount;
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheckCustom(msg.sender, from, to, ids, amounts, data);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal override {
        require(owner != operator, "ERC1155: setting approval status for self");
        operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _isApprovedForAll(address account, address operator) internal view returns (bool) {
        return operatorApprovals[account][operator];
    }

    function _parseTokenId(uint256 tokenId) internal pure returns (uint256 classId, uint256 nonceId) {
        bytes32 data = bytes32(tokenId);
        classId = uint256(data >> 128);
        nonceId = uint256(data);
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private override {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheckCustom(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override(ERC1155, ERC1155Supply) {
        // Custom logic here, if needed

        // Call each base class's _update method explicitly
        ERC1155._update(from, to, ids, values);
    }
}
