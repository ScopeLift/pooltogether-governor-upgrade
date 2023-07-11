// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {PooltogetherGovernorTest} from "test/PooltogetherGovernorTest.sol";

abstract contract BravoGovernorDeployTest is PooltogetherGovernorTest {
  function testFuzz_deployment(uint256 _blockNumber) public {
    assertEq(governorBravo.name(), "Pooltogether Governor Bravo");
    assertEq(address(governorBravo.token()), POOL_TOKEN);
    // These values were all copied directly from the mainnet alpha governor at:
    //   0xDbD27635A534A3d3169Ef0498beB56Fb9c937489
    assertEq(INITIAL_VOTING_DELAY, 1);
    assertEq(INITIAL_VOTING_PERIOD, 28_800);
    assertEq(INITIAL_PROPOSAL_THRESHOLD, 1_000e18);
    // forgefmt: disable-end
    assertEq(governorBravo.votingDelay(), INITIAL_VOTING_DELAY);
    assertEq(governorBravo.votingPeriod(), INITIAL_VOTING_PERIOD);
    assertEq(governorBravo.proposalThreshold(), INITIAL_PROPOSAL_THRESHOLD);
    assertEq(governorBravo.quorum(_blockNumber), QUORUM);
    assertEq(governorBravo.timelock(), TIMELOCK);
    assertEq(governorBravo.COUNTING_MODE(), "support=bravo&quorum=for,abstain&params=fractional");
  }
}

// TODO: Should we make this work better with scopelint. Wrap the
// inherited methods?
//
// Constructor should handle this and we should have use deployed
// as a flag.
contract is BravoGovernorDeployTest {
  function _useDeployedGovernorBravo() internal pure override returns (bool) {
    return false;
  }
}