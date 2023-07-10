// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

contract DeployInput {
  // TODO Reach out to Pooltogether and update these numbers based on what they want.
  uint256 constant INITIAL_VOTING_DELAY = 3600; // 12 hours
  uint256 constant INITIAL_VOTING_PERIOD = 28_800;
  uint256 constant INITIAL_PROPOSAL_THRESHOLD = 1_000e18;
}
