// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {ICompoundTimelock} from
  "@openzeppelin/contracts/governance/extensions/GovernorTimelockCompound.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {Propose} from "script/Propose.s.sol";
import {IGovernorAlpha} from "src/interfaces/IGovernorAlpha.sol";
import {PooltogetherGovernorTest} from "test/helpers/PooltogetherGovernorTest.sol";

abstract contract ProposalTest is PooltogetherGovernorTest {
  //----------------- State and Setup ----------- //

  IGovernorAlpha governorAlpha = IGovernorAlpha(GOVERNOR_ALPHA);
  IERC20 usdcToken = IERC20(USDC_ADDRESS);
  ICompoundTimelock timelock = ICompoundTimelock(payable(TIMELOCK));
  uint256 initialProposalCount;
  uint256 upgradeProposalId;

  // As defined in the GovernorAlpha ProposalState Enum
  uint8 constant PENDING = 0;
  uint8 constant ACTIVE = 1;
  uint8 constant DEFEATED = 3;
  uint8 constant SUCCEEDED = 4;
  uint8 constant QUEUED = 5;
  uint8 constant EXECUTED = 7;

  function setUp() public virtual override {
    PooltogetherGovernorTest.setUp();

    initialProposalCount = governorAlpha.proposalCount();

    Propose _proposeScript = new Propose();
    upgradeProposalId = _proposeScript.run(governorBravo);
  }

  //--------------- HELPERS ---------------//

  function _assumeReceiver(address _receiver) internal {
    assumePayable(_receiver);
    vm.assume(
      // We don't want the receiver to be the Timelock, as that would make our
      // assertions less meaningful -- most of our tests want to confirm that
      // proposals can cause tokens to be sent *from* the timelock to somewhere
      // else.
      _receiver != TIMELOCK
      // We also can't have the receiver be the zero address because POOL
      // blocks transfers to the zero address -- see line 329:
      // https://etherscan.io/address/0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e#code
      && _receiver > address(0)
    );
    assumeNoPrecompiles(_receiver);
  }

  function _randomERC20Token(uint256 _seed) internal view returns (IERC20 _token) {
    if (_seed % 2 == 0) _token = IERC20(POOL_TOKEN);
    if (_seed % 2 == 1) _token = usdcToken;
  }

  function _upgradeProposalStartBlock() internal view returns (uint256) {
    (,,, uint256 _startBlock,,,,,) = governorAlpha.proposals(upgradeProposalId);
    return _startBlock;
  }

  function _upgradeProposalEndBlock() internal view returns (uint256) {
    (,,,, uint256 _endBlock,,,,) = governorAlpha.proposals(upgradeProposalId);
    return _endBlock;
  }

  function _upgradeProposalEta() internal view returns (uint256) {
    (,, uint256 _eta,,,,,,) = governorAlpha.proposals(upgradeProposalId);
    return _eta;
  }

  function _jumpToActiveUpgradeProposal() internal {
    vm.roll(_upgradeProposalStartBlock() + 1);
  }

  function _jumpToUpgradeVoteComplete() internal {
    vm.roll(_upgradeProposalEndBlock() + 1);
  }

  function _jumpPastProposalEta() internal {
    vm.roll(block.number + 1); // move up one block so we're not in the same block as when queued
    vm.warp(_upgradeProposalEta() + 1); // jump past the eta timestamp
  }

  function _delegatesVoteOnUpgradeProposal(bool _support) internal {
    for (uint256 _index = 0; _index < delegates.length; _index++) {
      vm.prank(delegates[_index].addr);
      governorAlpha.castVote(upgradeProposalId, _support);
    }
  }

  function _passUpgradeProposal() internal {
    _jumpToActiveUpgradeProposal();
    _delegatesVoteOnUpgradeProposal(true);
    _jumpToUpgradeVoteComplete();
  }

  function _defeatUpgradeProposal() internal {
    _jumpToActiveUpgradeProposal();
    _delegatesVoteOnUpgradeProposal(false);
    _jumpToUpgradeVoteComplete();
  }

  function _passAndQueueUpgradeProposal() internal {
    _passUpgradeProposal();
    governorAlpha.queue(upgradeProposalId);
  }

  function _upgradeToBravoGovernor() internal {
    _passAndQueueUpgradeProposal();
    _jumpPastProposalEta();
    governorAlpha.execute(upgradeProposalId);
  }

  function _queueAndVoteAndExecuteProposalWithAlphaGovernor(
    address[] memory _targets,
    uint256[] memory _values,
    string[] memory _signatures,
    bytes[] memory _calldatas,
    bool isGovernorAlphaAdmin
  ) internal {
    // Submit the new proposal
    vm.prank(PROPOSER);
    uint256 _newProposalId =
      governorAlpha.propose(_targets, _values, _signatures, _calldatas, "Proposal for old Governor");

    // Pass and execute the new proposal
    (,,, uint256 _startBlock, uint256 _endBlock,,,,) = governorAlpha.proposals(_newProposalId);
    vm.roll(_startBlock + 1);
    for (uint256 _index = 0; _index < delegates.length; _index++) {
      vm.prank(delegates[_index].addr);
      governorAlpha.castVote(_newProposalId, true);
    }
    vm.roll(_endBlock + 1);

    if (!isGovernorAlphaAdmin) {
      vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
      governorAlpha.queue(_newProposalId);
      return;
    }

    governorAlpha.queue(_newProposalId);
    vm.roll(block.number + 1);
    (,, uint256 _eta,,,,,,) = governorAlpha.proposals(_newProposalId);
    vm.warp(_eta + 1);

    governorAlpha.execute(_newProposalId);

    // Ensure the new proposal is now executed
    assertEq(governorAlpha.state(_newProposalId), EXECUTED);
  }
}
