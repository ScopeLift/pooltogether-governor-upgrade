// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DeployInput} from "script/DeployInput.sol";
import {PoolTogetherGovernor} from "src/PoolTogetherGovernor.sol";

contract Deploy is DeployInput, Script {
  uint256 deployerPrivateKey;

  function setUp() public {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
  }

  function run() public returns (PoolTogetherGovernor) {
    vm.startBroadcast(deployerPrivateKey);
    PoolTogetherGovernor _governor =
    new PoolTogetherGovernor(INITIAL_VOTING_DELAY, INITIAL_VOTING_PERIOD, INITIAL_PROPOSAL_THRESHOLD);
    vm.stopBroadcast();

    return _governor;
  }
}
