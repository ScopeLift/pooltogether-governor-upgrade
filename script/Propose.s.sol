// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ICompoundTimelock} from
  "@openzeppelin/contracts/governance/extensions/GovernorTimelockCompound.sol";

import {PooltogetherGovernor} from "src/PooltogetherGovernor.sol";
import {IGovernorAlpha} from "src/interfaces/IGovernorAlpha.sol";

contract Deploy is Script {
  IGovernorAlpha constant GOVERNOR_ALPHA =
    IGovernorAlpha(0xB3a87172F555ae2a2AB79Be60B336D2F7D0187f0);
  address constant PROPOSER = 0xe0e7b7C5aE92Fe94D2ae677D81214D6Ad7A11C27; // lonser.eth

  function propose(PooltogetherGovernor _newGovernor) internal returns (uint256 _proposalId) {
    address[] memory _targets = new address[](2);
    uint256[] memory _values = new uint256[](2);
    string[] memory _signatures = new string [](2);
    bytes[] memory _calldatas = new bytes[](2);

    _targets[0] = GOVERNOR_ALPHA.timelock();
    _values[0] = 0;
    _signatures[0] = "setPendingAdmin(address)";
    _calldatas[0] = abi.encode(address(_newGovernor));

    _targets[1] = address(_newGovernor);
    _values[1] = 0;
    _signatures[1] = "__acceptAdmin()";
    _calldatas[1] = "";

    return GOVERNOR_ALPHA.propose(
      _targets, _values, _signatures, _calldatas, "Upgrade to Governor Bravo"
    );
  }

  /// @dev After the new Governor is deployed on mainnet, this can move from a parameter to a const
  function run(PooltogetherGovernor _newGovernor) public returns (uint256 _proposalId) {
    // The expectation is the key loaded here corresponds to the address of the `proposer` above.
    // When running as a script, broadcast will fail if the key is not correct.
    uint256 _proposerKey = vm.envUint("PROPOSER_PRIVATE_KEY");
    vm.rememberKey(_proposerKey);

    vm.startBroadcast(PROPOSER);
    _proposalId = propose(_newGovernor);
    vm.stopBroadcast();
  }
}
