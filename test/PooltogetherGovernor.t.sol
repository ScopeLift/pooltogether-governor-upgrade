// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {IPOOL} from "src/interfaces/IPOOL.sol";
import {IGovernorAlpha} from "src/interfaces/IGovernorAlpha.sol";
import {PooltogetherGovernorTest} from "test/helpers/PooltogetherGovernorTest.sol";
import {ProposalTest} from "test/helpers/ProposalTest.sol";

contract Constructor is PooltogetherGovernorTest {
  function testFuzz_CorrectlySetsAllConstructorArgs(uint256 _blockNumber) public {
    assertEq(governorBravo.name(), "Pooltogether Governor Bravo");
    assertEq(address(governorBravo.token()), POOL_TOKEN);

    assertEq(governorBravo.votingDelay(), INITIAL_VOTING_DELAY);
    assertLt(governorBravo.votingDelay(), MAX_REASONABLE_TIME_PERIOD);

    assertEq(governorBravo.votingPeriod(), INITIAL_VOTING_PERIOD);
    assertLt(governorBravo.votingPeriod(), MAX_REASONABLE_TIME_PERIOD);

    assertEq(governorBravo.proposalThreshold(), INITIAL_PROPOSAL_THRESHOLD);

    assertEq(governorBravo.quorum(_blockNumber), QUORUM);
    assertEq(governorBravo.timelock(), TIMELOCK);
    assertEq(governorBravo.COUNTING_MODE(), "support=bravo&quorum=for,abstain&params=fractional");
  }
}

contract Propose is ProposalTest {
  function test_Proposal() public {
    // Proposal has been recorded
    assertEq(governorAlpha.proposalCount(), initialProposalCount + 1);

    // Proposal is in the expected state
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, PENDING);

    // Proposal actions correspond to Governor upgrade
    (
      address[] memory _targets,
      uint256[] memory _values,
      string[] memory _signatures,
      bytes[] memory _calldatas
    ) = governorAlpha.getActions(upgradeProposalId);
    assertEq(_targets.length, 2);
    assertEq(_targets[0], TIMELOCK);
    assertEq(_targets[1], address(governorBravo));
    assertEq(_values.length, 2);
    assertEq(_values[0], 0);
    assertEq(_values[1], 0);
    assertEq(_signatures.length, 2);
    assertEq(_signatures[0], "setPendingAdmin(address)");
    assertEq(_signatures[1], "__acceptAdmin()");
    assertEq(_calldatas.length, 2);
    assertEq(_calldatas[0], abi.encode(address(governorBravo)));
    assertEq(_calldatas[1], "");
  }

  function test_proposalActiveAfterDelay() public {
    _jumpToActiveUpgradeProposal();

    // Ensure proposal has become active the block after the voting delay
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, ACTIVE);
  }

  function testFuzz_ProposerCanCastVote(bool _willSupport) public {
    _jumpToActiveUpgradeProposal();
    uint256 _proposerVotes = IPOOL(POOL_TOKEN).getPriorVotes(PROPOSER, _upgradeProposalStartBlock());

    vm.prank(PROPOSER);
    governorAlpha.castVote(upgradeProposalId, _willSupport);

    IGovernorAlpha.Receipt memory _receipt = governorAlpha.getReceipt(upgradeProposalId, PROPOSER);
    assertEq(_receipt.hasVoted, true);
    assertEq(_receipt.support, _willSupport);
    assertEq(_receipt.votes, _proposerVotes);
  }

  function test_ProposalSucceedsWhenAllDelegatesVoteFor() public {
    _passUpgradeProposal();

    // Ensure proposal state is now succeeded
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, SUCCEEDED);
  }

  function test_ProposalDefeatedWhenAllDelegatesVoteAgainst() public {
    _defeatUpgradeProposal();

    // Ensure proposal state is now defeated
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, DEFEATED);
  }

  function test_ProposalCanBeQueuedAfterSucceeding() public {
    _passUpgradeProposal();
    governorAlpha.queue(upgradeProposalId);

    // Ensure proposal can be queued after success
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, QUEUED);

    (
      address[] memory _targets,
      uint256[] memory _values,
      string[] memory _signatures,
      bytes[] memory _calldatas
    ) = governorAlpha.getActions(upgradeProposalId);

    uint256 _eta = block.timestamp + timelock.delay();

    for (uint256 _index = 0; _index < _targets.length; _index++) {
      // Calculate hash of transaction in Timelock
      bytes32 _txHash = keccak256(
        abi.encode(_targets[_index], _values[_index], _signatures[_index], _calldatas[_index], _eta)
      );

      // Ensure transaction is queued in Timelock
      bool _isQueued = timelock.queuedTransactions(_txHash);
      assertEq(_isQueued, true);
    }
  }

  function test_ProposalCanBeExecutedAfterDelay() public {
    _passAndQueueUpgradeProposal();
    _jumpPastProposalEta();

    // Execute the proposal
    governorAlpha.execute(upgradeProposalId);

    // Ensure the proposal is now executed
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, EXECUTED);

    // Ensure the governorBravo is now the admin of the timelock
    assertEq(timelock.admin(), address(governorBravo));
  }
}
