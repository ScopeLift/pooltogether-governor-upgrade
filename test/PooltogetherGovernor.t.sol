// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {PooltogetherGovernorTest} from "test/helpers/PooltogetherGovernorTest.sol";

contract Constructor is PooltogetherGovernorTest {
  function testFuzz_CorrectlySetsAllConstructorArgs(uint256 _blockNumber) public {
    assertEq(governorBravo.name(), "Pooltogether Governor Bravo");
    assertEq(address(governorBravo.token()), POOL_TOKEN);
    assertEq(governorBravo.votingDelay(), INITIAL_VOTING_DELAY);
    assertEq(governorBravo.votingPeriod(), INITIAL_VOTING_PERIOD);
    assertEq(governorBravo.proposalThreshold(), INITIAL_PROPOSAL_THRESHOLD);
    assertEq(governorBravo.quorum(_blockNumber), QUORUM);
    assertEq(governorBravo.timelock(), TIMELOCK);
    assertEq(governorBravo.COUNTING_MODE(), "support=bravo&quorum=for,abstain&params=fractional");
  }
}
