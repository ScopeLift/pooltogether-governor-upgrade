// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

contract DeployInput {
  // These are based on the current values for Governor Alpha
  uint256 constant INITIAL_VOTING_DELAY = 1;
  uint256 constant INITIAL_VOTING_PERIOD = 28_800;
  uint256 constant INITIAL_PROPOSAL_THRESHOLD = 1_000e18;
}
