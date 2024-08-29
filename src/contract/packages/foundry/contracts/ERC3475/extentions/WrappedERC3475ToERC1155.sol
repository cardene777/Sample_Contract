// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IWrappedEERC3475ToERC1155} from "./interfaces/IWrappedEERC3475ToERC1155.sol";

contract WrappedEERC3475ToERC1155 is ERC1155, IWrappedEERC3475ToERC1155, Ownable {

    struct Nonce {
        mapping(uint256 => Values) _values;
        mapping(address => uint256) _balances;
        mapping(address => mapping(address => uint256)) _allowances;
        uint256 _activeSupply;
        uint256 _burnedSupply;
        uint256 _redeemedSupply;
    }

    struct Class {
        mapping(uint256 => Values) _values;
        mapping(uint256 => Metadata) _nonceMetadata;
        mapping(uint256 => Nonce) nonces;
    }

    mapping(uint256 => Class) internal _classes;
    mapping(uint256 => Metadata) _classMetadata;

    mapping(address => mapping(address => bool)) operatorApprovals;

    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {}

    function _generateTokenId(
        uint256 classId,
        uint256 nonceId
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(classId, nonceId)));
    }

    function mint(
        address account,
        uint256 classId,
        uint256 nonceId,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        uint256 tokenId = _generateTokenId(classId, nonceId);
        _mint(account, tokenId, amount, data);

        Nonce storage nonce = _classes[classId].nonces[nonceId];
        nonce._balances[account] += amount;
        nonce._activeSupply += amount;
    }

    function burn(
        address account,
        uint256 classId,
        uint256 nonceId,
        uint256 amount
    ) public {
        require(
            account == msg.sender || isApprovedForAll(account, msg.sender),
            "ERC1155: caller is not owner nor approved"
        );
        uint256 tokenId = _generateTokenId(classId, nonceId);
        _burn(account, tokenId, amount);

        Nonce storage nonce = _classes[classId].nonces[nonceId];
        nonce._balances[account] -= amount;
        nonce._activeSupply -= amount;
        nonce._burnedSupply += amount;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 classId,
        uint256 nonceId,
        uint256 amount,
        bytes memory data
    ) public {
        uint256 tokenId = _generateTokenId(classId, nonceId);
        safeTransferFrom(from, to, tokenId, amount, data);

        Nonce storage nonce = _classes[classId].nonces[nonceId];
        require(
            nonce._balances[from] >= amount,
            "ERC3475: not enough bond to transfer"
        );
        nonce._balances[from] -= amount;
        nonce._balances[to] += amount;
    }

    function transferFrom(
        address from,
        address to,
        Transaction[] calldata _transactions
    ) external {
        require(
            from != address(0),
            "ERC3475: can't transfer from the zero address"
        );
        require(
            to != address(0),
            "ERC3475: use burn() instead"
        );
        require(
            msg.sender == from ||
            isApprovedFor(from, msg.sender),
            "ERC3475: caller not owner or approved"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            _transferFrom(from, to, _transactions[i]);
        }
        emit Transfer(msg.sender, from, to, _transactions);
    }

    function transferAllowanceFrom(
        address from,
        address to,
        Transaction[] calldata _transactions
    ) external {
        require(
            from != address(0),
            "ERC3475: can't transfer from the zero address"
        );
        require(
            to != address(0),
            "ERC3475: use burn() instead"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            require(
                _transactions[i]._amount <= allowance(from, msg.sender, _transactions[i].classId, _transactions[i].nonceId),
                "ERC3475: transfer amount exceeds allowance"
            );
            _transferAllowanceFrom(msg.sender, from, to, _transactions[i]);
        }
        emit Transfer(msg.sender, from, to, _transactions);
    }

    function approve(
        address spender,
        Transaction[] calldata _transactions
    ) external {
        for (uint256 i = 0; i < _transactions.length; i++) {
            _classes[_transactions[i].classId]
            .nonces[_transactions[i].nonceId]
            ._allowances[msg.sender][spender] = _transactions[i]._amount;
        }
        emit ApprovalFor(msg.sender, spender, true);
    }

    function setApprovalFor(
        address operator,
        bool approved
    ) public {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalFor(msg.sender, operator, approved);
    }

    function redeem(
        address from,
        Transaction[] calldata _transactions
    ) external {
        require(
            from != address(0),
            "ERC3475: can't redeem from the zero address"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            (, uint256 progressRemaining) = getProgress(
                _transactions[i].classId,
                _transactions[i].nonceId
            );
            require(
                progressRemaining == 0,
                "ERC3475: Not redeemable"
            );
            _redeem(from, _transactions[i]);
        }
        emit Redeem(msg.sender, from, _transactions);
    }

    function _transferFrom(
        address from,
        address to,
        Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId].nonces[_transaction.nonceId];
        require(
            nonce._balances[from] >= _transaction._amount,
            "ERC3475: not enough bond to transfer"
        );

        nonce._balances[from] -= _transaction._amount;
        nonce._balances[to] += _transaction._amount;
    }

    function _transferAllowanceFrom(
        address operator,
        address from,
        address to,
        Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId].nonces[_transaction.nonceId];
        require(
            nonce._balances[from] >= _transaction._amount,
            "ERC3475: not allowed amount"
        );

        nonce._allowances[from][operator] -= _transaction._amount;
        nonce._balances[from] -= _transaction._amount;
        nonce._balances[to] += _transaction._amount;
    }

    function _redeem(
        address from,
        Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId].nonces[_transaction.nonceId];
        require(
            nonce._balances[from] >= _transaction._amount,
            "ERC3475: not enough bond to redeem"
        );

        nonce._balances[from] -= _transaction._amount;
        nonce._activeSupply -= _transaction._amount;
        nonce._redeemedSupply += _transaction._amount;
    }

    function balanceOf(
        address account,
        uint256 classId,
        uint256 nonceId
    ) public view returns (uint256) {
        uint256 tokenId = _generateTokenId(classId, nonceId);
        return balanceOf(account, tokenId);
    }

    function totalSupply(
        uint256 classId,
        uint256 nonceId
    ) public view returns (uint256) {
        Nonce storage nonce = _classes[classId].nonces[nonceId];
        return
            nonce._activeSupply + nonce._burnedSupply + nonce._redeemedSupply;
    }

    function classMetadata(
        uint256 metadataId
    ) external view returns (Metadata memory) {
        return _classMetadata[metadataId];
    }

    function nonceMetadata(
        uint256 classId,
        uint256 metadataId
    ) external view returns (Metadata memory) {
        return _classes[classId]._nonceMetadata[metadataId];
    }

    function classValues(
        uint256 classId,
        uint256 metadataId
    ) external view returns (Values memory) {
        return _classes[classId]._values[metadataId];
    }

    function nonceValues(
        uint256 classId,
        uint256 nonceId,
        uint256 metadataId
    ) external view returns (Values memory) {
        return _classes[classId].nonces[nonceId]._values[metadataId];
    }

    function getProgress(
        uint256 classId,
        uint256 nonceId
    )
        public
        view
        returns (uint256 progressAchieved, uint256 progressRemaining)
    {
        uint256 issuanceDate = _classes[classId]
            .nonces[nonceId]
            ._values[0]
            .uintValue;
        uint256 maturityDate = issuanceDate +
            _classes[classId].nonces[nonceId]._values[5].uintValue;

        progressAchieved = block.timestamp - issuanceDate;
        progressRemaining = block.timestamp < maturityDate
            ? maturityDate - block.timestamp
            : 0;
    }

    function allowance(
        address _owner,
        address spender,
        uint256 classId,
        uint256 nonceId
    ) public view returns (uint256) {
        Nonce storage nonce = _classes[classId].nonces[nonceId];
        return nonce._allowances[_owner][spender];
    }

    function isApprovedFor(
        address _owner,
        address operator
    ) public view returns (bool) {
        return operatorApprovals[_owner][operator];
    }
}
