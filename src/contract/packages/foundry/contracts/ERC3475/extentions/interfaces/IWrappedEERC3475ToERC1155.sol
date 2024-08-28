// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWrappedEERC3475ToERC1155 {
    // STRUCTURE
    /**
     * @dev Values structure of the Metadata
     */
    struct Values {
        string stringValue;
        uint uintValue;
        address addressValue;
        bool boolValue;
    }
    /**
     * @dev structure allows to define particular bond metadata (ie the values in the class as well as nonce inputs).
     * @notice 'title' defining the title information,
     * @notice '_type' explaining the data type of the title information added (eg int, bool, address),
     * @notice 'description' explains little description about the information stored in the bond",
     */
    struct Metadata {
        string title;
        string _type;
        string description;
    }
    /**
     * @dev structure that defines the parameters for specific issuance of bonds and amount which are to be transferred/issued/given allowance, etc.
     * @notice this structure is used to streamline the input parameters for functions of this standard with that of other Token standards like ERC20.
     * @classId is the class id of the bond.
     * @nonceId is the nonce id of the given bond class. This param is for distinctions of the issuing conditions of the bond.
     * @amount is the amount of the bond that will be transferred.
     */
    struct Transaction {
        uint256 classId;
        uint256 nonceId;
        uint256 _amount;
    }

    // Mint tokens
    function mint(
        address account,
        uint256 classId,
        uint256 nonceId,
        uint256 amount,
        bytes memory data
    ) external;

    // Burn tokens
    function burn(
        address account,
        uint256 classId,
        uint256 nonceId,
        uint256 amount
    ) external;

    // Transfer tokens from one address to another
    function safeTransferFrom(
        address from,
        address to,
        uint256 classId,
        uint256 nonceId,
        uint256 amount,
        bytes memory data
    ) external;

    // Transfer tokens from one address to another (with allowance)
    function transferFrom(
        address from,
        address to,
        Transaction[] calldata _transactions
    ) external;

    // Transfer allowance tokens from one address to another
    function transferAllowanceFrom(
        address from,
        address to,
        Transaction[] calldata _transactions
    ) external;

    // Approve tokens for spending
    function approve(
        address spender,
        Transaction[] calldata _transactions
    ) external;

    // Set approval for all tokens
    function setApprovalFor(
        address operator,
        bool approved
    ) external;

    // Redeem tokens
    function redeem(
        address from,
        Transaction[] calldata _transactions
    ) external;

    // Get the balance of tokens
    function balanceOf(
        address account,
        uint256 classId,
        uint256 nonceId
    ) external view returns (uint256);

    // Get the total supply of tokens
    function totalSupply(
        uint256 classId,
        uint256 nonceId
    ) external view returns (uint256);

    // Get metadata of a class
    function classMetadata(
        uint256 metadataId
    ) external view returns (Metadata memory);

    // Get metadata of a nonce
    function nonceMetadata(
        uint256 classId,
        uint256 metadataId
    ) external view returns (Metadata memory);

    // Get values of a class
    function classValues(
        uint256 classId,
        uint256 metadataId
    ) external view returns (Values memory);

    // Get values of a nonce
    function nonceValues(
        uint256 classId,
        uint256 nonceId,
        uint256 metadataId
    ) external view returns (Values memory);

    // Get progress of a nonce
    function getProgress(
        uint256 classId,
        uint256 nonceId
    ) external view returns (uint256 progressAchieved, uint256 progressRemaining);

    // Get allowance for a spender
    function allowance(
        address _owner,
        address spender,
        uint256 classId,
        uint256 nonceId
    ) external view returns (uint256);

    // Check if an operator is approved for an owner
    function isApprovedFor(
        address _owner,
        address operator
    ) external view returns (bool);

    // Events
    event Transfer(
        address indexed operator,
        address indexed from,
        address indexed to,
        Transaction[] _transactions
    );

    event ApprovalFor(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event Redeem(
        address indexed operator,
        address indexed from,
        Transaction[] _transactions
    );
}
