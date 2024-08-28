//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../contracts/ERC3475/extentions/WrappedEERC3475ToERC1155.sol";
import "./DeployHelpers.s.sol";

contract DeployScript is ScaffoldETHDeploy {
  error InvalidPrivateKey(string);

  function run() external {
    uint256 deployerPrivateKey = setupLocalhostEnv();
    if (deployerPrivateKey == 0) {
      revert InvalidPrivateKey(
        "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
      );
    }
    vm.startBroadcast(deployerPrivateKey);

    string memory uri = "https://example.com";

    WrappedEERC3475ToERC1155 wrappedEERC3475ToERC1155 = new WrappedEERC3475ToERC1155(uri);
    console.logString(
      string.concat(
        "WrappedEERC3475ToERC1155 deployed at: ", vm.toString(address(wrappedEERC3475ToERC1155))
      )
    );

    vm.stopBroadcast();

    /**
     * This function generates the file containing the contracts Abi definitions.
     * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
     * This function should be called last.
     */
    exportDeployments();
  }

  function test() public { }
}
