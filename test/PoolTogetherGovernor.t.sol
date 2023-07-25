// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ERC20VotesComp} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {IPOOL} from "src/interfaces/IPOOL.sol";
import {IGovernorAlpha} from "src/interfaces/IGovernorAlpha.sol";
import {PoolTogetherGovernorTest} from "test/helpers/PoolTogetherGovernorTest.sol";
import {ProposalTest} from "test/helpers/ProposalTest.sol";
import {ProposalBuilder} from "test/helpers/Proposal.sol";
import {IV4PoolTogetherTokenFaucet} from "test/interfaces/IV4PoolTogetherTokenFaucet.sol";
import {IV3ConfigurableReserve} from "test/interfaces/IV3ConfigurableReserve.sol";
import {IStakePrizePool} from "test/interfaces/IStakePrizePool.sol";
import {IV3MultipleWinners} from "test/interfaces/IV3MultipleWinners.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract Constructor is PoolTogetherGovernorTest {
  function testFuzz_CorrectlySetsAllConstructorArgs(uint256 _blockNumber) public {
    assertEq(governorBravo.name(), "PoolTogether Governor Bravo");
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
  function test_GovernorUpgradeProposalIsSubmittedCorrectly() public {
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

  function test_UpgradeProposalActiveAfterDelay() public {
    _jumpToActiveUpgradeProposal();

    // Ensure proposal has become active the block after the voting delay
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, ACTIVE);
  }

  function testFuzz_UpgradeProposerCanCastVote(bool _willSupport) public {
    _jumpToActiveUpgradeProposal();
    uint256 _proposerVotes = IPOOL(POOL_TOKEN).getPriorVotes(PROPOSER, _upgradeProposalStartBlock());

    vm.prank(PROPOSER);
    governorAlpha.castVote(upgradeProposalId, _willSupport);

    IGovernorAlpha.Receipt memory _receipt = governorAlpha.getReceipt(upgradeProposalId, PROPOSER);
    assertEq(_receipt.hasVoted, true);
    assertEq(_receipt.support, _willSupport);
    assertEq(_receipt.votes, _proposerVotes);
  }

  function test_UpgradeProposalSucceedsWhenAllDelegatesVoteFor() public {
    _passUpgradeProposal();

    // Ensure proposal state is now succeeded
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, SUCCEEDED);
  }

  function test_UpgradeProposalDefeatedWhenAllDelegatesVoteAgainst() public {
    _defeatUpgradeProposal();

    // Ensure proposal state is now defeated
    uint8 _state = governorAlpha.state(upgradeProposalId);
    assertEq(_state, DEFEATED);
  }

  function test_UpgradeProposalCanBeQueuedAfterSucceeding() public {
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

  function test_UpgradeProposalCanBeExecutedAfterDelay() public {
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

  ////
  // Post proposal tests
  ////
  function testFuzz_OldGovernorSendsETHAfterProposalIsDefeated(uint128 _amount, address _receiver)
    public
  {
    _assumeReceiver(_receiver);

    // Counter-intuitively, the Governor (not the Timelock) must hold the ETH.
    // See the deployed GovernorAlpha, line 204:
    //   https://etherscan.io/address/0xB3a87172F555ae2a2AB79Be60B336D2F7D0187f0#code
    // The governor transfers ETH to the Timelock in the process of executing
    // the proposal. The Timelock then just passes that ETH along.
    vm.deal(address(governorAlpha), _amount);

    uint256 _receiverETHBalance = _receiver.balance;
    uint256 _governorETHBalance = address(governorAlpha).balance;

    // Defeat the proposal to upgrade the Governor
    _defeatUpgradeProposal();

    // Create a new proposal to send the ETH.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    _targets[0] = _receiver;
    _values[0] = _amount;

    _queueAndVoteAndExecuteProposalWithAlphaGovernor(
      _targets,
      _values,
      new string[](1), // No signature needed for an ETH send.
      new bytes[](1), // No calldata needed for an ETH send.
      true // GovernorAlpha is still the Timelock admin.
    );

    // Ensure the ETH has been transferred to the receiver
    assertEq(
      address(governorAlpha).balance,
      _governorETHBalance - _amount,
      "Governor alpha ETH balance is incorrect"
    );
    assertEq(_receiver.balance, _receiverETHBalance + _amount, "Receiver ETH balance is incorrect");
  }

  function testFuzz_OldGovernorCannotSendETHAfterProposalSucceeds(
    uint256 _amount,
    address _receiver
  ) public {
    _assumeReceiver(_receiver);

    // Counter-intuitively, the Governor must hold the ETH, not the Timelock.
    // See the deployed GovernorAlpha, line 204:
    //   https://etherscan.io/address/0xB3a87172F555ae2a2AB79Be60B336D2F7D0187f0#code
    // The governor transfers ETH to the Timelock in the process of executing
    // the proposal. The Timelock then just passes that ETH along.
    vm.deal(address(governorAlpha), _amount);

    uint256 _receiverETHBalance = _receiver.balance;
    uint256 _governorETHBalance = address(governorAlpha).balance;

    // Pass and execute the proposal to upgrade the Governor
    _upgradeToBravoGovernor();

    // Create a new proposal to send the ETH.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    _targets[0] = _receiver;
    _values[0] = _amount;

    _queueAndVoteAndExecuteProposalWithAlphaGovernor(
      _targets,
      _values,
      new string[](1), // No signature needed for an ETH send.
      new bytes[](1), // No calldata needed for an ETH send.
      false // GovernorAlpha is not the Timelock admin.
    );

    // Ensure no ETH has been transferred to the receiver
    assertEq(address(governorAlpha).balance, _governorETHBalance);
    assertEq(_receiver.balance, _receiverETHBalance);
  }

  function testFuzz_OldGovernorSendsTokenAfterProposalIsDefeated(
    uint256 _amount,
    address _receiver,
    uint256 _seed
  ) public {
    _assumeReceiver(_receiver);
    IERC20 _token = _randomERC20Token(_seed);

    uint256 _receiverTokenBalance = _token.balanceOf(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);
    // bound by the number of tokens the timelock currently controls
    _amount = bound(_amount, 0, _timelockTokenBalance);

    // Defeat the proposal to upgrade the Governor
    _defeatUpgradeProposal();

    // Craft a new proposal to send the token.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    string[] memory _signatures = new string [](1);
    bytes[] memory _calldatas = new bytes[](1);

    _targets[0] = address(_token);
    _values[0] = 0;
    _signatures[0] = "transfer(address,uint256)";
    _calldatas[0] = abi.encode(_receiver, _amount);

    _queueAndVoteAndExecuteProposalWithAlphaGovernor(
      _targets,
      _values,
      _signatures,
      _calldatas,
      true // GovernorAlpha is still the Timelock admin.
    );

    // Ensure the tokens have been transferred from the timelock to the receiver.
    assertEq(
      _token.balanceOf(TIMELOCK),
      _timelockTokenBalance - _amount,
      "Timelock token balance is incorrect"
    );
    assertEq(
      _token.balanceOf(_receiver),
      _receiverTokenBalance + _amount,
      "Receiver token balance is incorrect"
    );
  }

  function testFuzz_OldGovernorSendsSTETHAfterProposalIsDefeated(uint256 _amount, address _receiver)
    public
  {
    _assumeReceiver(_receiver);
    IERC20 _token = IERC20(STETH_ADDRESS);

    uint256 _receiverTokenBalance = _token.balanceOf(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);
    // Bound by the number of tokens the timelock currently controls
    // Steth suffers from an off by 2 issues which we have to correct
    // https://docs.lido.fi/guides/steth-integration-guide#1-2-wei-corner-case
    _amount = bound(_amount, 2, _timelockTokenBalance - 2);

    // Defeat the proposal to upgrade the Governor
    _defeatUpgradeProposal();

    // Craft a new proposal to send the token.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    string[] memory _signatures = new string [](1);
    bytes[] memory _calldatas = new bytes[](1);

    _targets[0] = address(_token);
    _values[0] = 0;
    _signatures[0] = "transfer(address,uint256)";
    _calldatas[0] = abi.encode(_receiver, _amount);

    _queueAndVoteAndExecuteProposalWithAlphaGovernor(
      _targets,
      _values,
      _signatures,
      _calldatas,
      true // GovernorAlpha is still the Timelock admin.
    );

    // Ensure the tokens have been transferred from the timelock to the receiver.
    //
    // Add and subtract 2 to handle the off by 2 error
    assertGe(
      _token.balanceOf(TIMELOCK),
      _timelockTokenBalance - _amount - 2,
      "Timelock token balance is to low"
    );
    assertLe(
      _token.balanceOf(TIMELOCK),
      _timelockTokenBalance - _amount + 2,
      "Timelock token balance is to high"
    );

    assertGe(
      _token.balanceOf(_receiver),
      _receiverTokenBalance + _amount - 2,
      "Receiver token balance is too low"
    );
    assertLe(
      _token.balanceOf(_receiver),
      _receiverTokenBalance + _amount + 2,
      "Receiver token balance is too high"
    );
  }

  function testFuzz_OldGovernorCanNotSendTokensAfterUpgradeCompletes(
    uint256 _amount,
    address _receiver,
    uint256 _seed
  ) public {
    _assumeReceiver(_receiver);
    IERC20 _token = _randomERC20Token(_seed);

    uint256 _receiverTokenBalance = _token.balanceOf(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);
    // bound by the number of tokens the timelock currently controls
    _amount = bound(_amount, 0, _timelockTokenBalance);

    // Pass and execute the proposal to upgrade the Governor
    _upgradeToBravoGovernor();

    // Craft a new proposal to send the token.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    string[] memory _signatures = new string [](1);
    bytes[] memory _calldatas = new bytes[](1);

    _targets[0] = address(_token);
    _values[0] = 0;
    _signatures[0] = "transfer(address,uint256)";
    _calldatas[0] = abi.encode(_receiver, _amount);

    _queueAndVoteAndExecuteProposalWithAlphaGovernor(
      _targets,
      _values,
      _signatures,
      _calldatas,
      false // GovernorAlpha is not the Timelock admin anymore.
    );

    // Ensure no tokens have been transferred from the timelock to the receiver.
    assertEq(_token.balanceOf(TIMELOCK), _timelockTokenBalance, "Timelock balance is incorrect");
    assertEq(_token.balanceOf(_receiver), _receiverTokenBalance, "Receiver balance is incorrect");
  }

  // Adding StEth to the _randomERC20 function causes other tests to fail so we pulled it out into a
  // separate test
  function testFuzz_OldGovernorCanNotSendSTETHAfterUpgradeCompletes(
    uint256 _amount,
    address _receiver
  ) public {
    _assumeReceiver(_receiver);
    IERC20 _token = IERC20(STETH_ADDRESS);

    uint256 _receiverTokenBalance = _token.balanceOf(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);
    _amount = bound(_amount, 0, _timelockTokenBalance);

    // Pass and execute the proposal to upgrade the Governor
    _upgradeToBravoGovernor();

    // Craft a new proposal to send the token.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    string[] memory _signatures = new string [](1);
    bytes[] memory _calldatas = new bytes[](1);

    _targets[0] = address(_token);
    _values[0] = 0;
    _signatures[0] = "transfer(address,uint256)";
    _calldatas[0] = abi.encode(_receiver, _amount);

    _queueAndVoteAndExecuteProposalWithAlphaGovernor(
      _targets,
      _values,
      _signatures,
      _calldatas,
      false // GovernorAlpha is not the Timelock admin anymore.
    );

    // Ensure no tokens have been transferred from the timelock to the receiver.
    assertEq(_token.balanceOf(TIMELOCK), _timelockTokenBalance, "Timelock balance is incorrect");
    assertEq(_token.balanceOf(_receiver), _receiverTokenBalance, "Receiver balance is incorrect");
  }

  ////
  // Bravo proposal tests
  ////
  function testFuzz_NewGovernorCanReceiveNewProposal(uint256 _poolAmount, address _poolReceiver)
    public
  {
    _assumeReceiver(_poolReceiver);
    _upgradeToBravoGovernor();
    _submitTokenSendProposalToGovernorBravo(POOL_TOKEN, _poolAmount, _poolReceiver);
  }

  function testFuzz_NewGovernorCanDefeatProposal(uint256 _amount, address _receiver, uint256 _seed)
    public
  {
    IERC20 _token = _randomERC20Token(_seed);
    _assumeReceiver(_receiver);

    _upgradeToBravoGovernor();

    (
      address[] memory _targets,
      uint256[] memory _values,
      bytes[] memory _calldatas,
      string memory _description
    ) = _buildTokenSendProposal(address(_token), _amount, _receiver);

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      _targets,
      _values,
      _calldatas,
      _description,
      (_amount % 2 == 1 ? AGAINST : ABSTAIN) // Randomize vote type.
    );

    // It should not be possible to queue the proposal
    vm.expectRevert("Governor: proposal not successful");
    governorBravo.queue(_targets, _values, _calldatas, keccak256(bytes(_description)));
  }

  function testFuzz_NewGovernorCanPassProposalToSendToken(
    uint256 _amount,
    address _receiver,
    uint256 _seed
  ) public {
    IERC20 _token = _randomERC20Token(_seed);
    _assumeReceiver(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);

    // bound by the number of tokens the timelock currently controls
    _amount = bound(_amount, 0, _timelockTokenBalance);
    uint256 _initialTokenBalance = _token.balanceOf(_receiver);

    _upgradeToBravoGovernor();

    (
      address[] memory _targets,
      uint256[] memory _values,
      bytes[] memory _calldatas,
      string memory _description
    ) = _buildTokenSendProposal(address(_token), _amount, _receiver);

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      _targets, _values, _calldatas, _description, FOR
    );

    // Ensure the tokens have been transferred
    assertEq(_token.balanceOf(_receiver), _initialTokenBalance + _amount);
    assertEq(_token.balanceOf(TIMELOCK), _timelockTokenBalance - _amount);
  }

  function testFuzz_NewGovernorCanPassProposalToSendETH(uint256 _amount, address _receiver) public {
    _assumeReceiver(_receiver);
    vm.deal(TIMELOCK, _amount);
    uint256 _timelockETHBalance = TIMELOCK.balance;
    uint256 _receiverETHBalance = _receiver.balance;

    _upgradeToBravoGovernor();

    // Craft a new proposal to send ETH.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    _targets[0] = _receiver;
    _values[0] = _amount;

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      _targets,
      _values,
      new bytes[](1), // There is no calldata for a plain ETH call.
      "Transfer some ETH via the new Governor",
      FOR // Vote/suppport type.
    );

    // Ensure the ETH was transferred.
    assertEq(_receiver.balance, _receiverETHBalance + _amount);
    assertEq(TIMELOCK.balance, _timelockETHBalance - _amount);
  }

  function testFuzz_NewGovernorCanPassProposalToSendETHWithNoDeal(
    uint256 _amount,
    address _receiver
  ) public {
    _assumeReceiver(_receiver);
    // The Timelock currently has approximately 30.4 ETH
    // https://etherscan.io/address/0x42cd8312D2BCe04277dD5161832460e95b24262E
    _amount = bound(_amount, 0, 30.4 ether);
    uint256 _timelockETHBalance = TIMELOCK.balance;
    uint256 _receiverETHBalance = _receiver.balance;

    _upgradeToBravoGovernor();

    // Craft a new proposal to send ETH.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    _targets[0] = _receiver;
    _values[0] = _amount;

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      _targets,
      _values,
      new bytes[](1), // There is no calldata for a plain ETH call.
      "Transfer some ETH via the new Governor",
      FOR // Vote/suppport type.
    );

    // Ensure the ETH was transferred.
    assertEq(_receiver.balance, _receiverETHBalance + _amount);
    assertEq(TIMELOCK.balance, _timelockETHBalance - _amount);
  }

  function testFuzz_NewGovernorCanPassProposalToSendETHWithTokens(
    uint256 _amountETH,
    uint256 _amountToken,
    address _receiver,
    uint256 _seed
  ) public {
    IERC20 _token = _randomERC20Token(_seed);
    _assumeReceiver(_receiver);

    vm.deal(TIMELOCK, _amountETH);
    uint256 _timelockETHBalance = TIMELOCK.balance;
    uint256 _receiverETHBalance = _receiver.balance;

    // Bound _amountToken by the number of tokens the timelock currently controls.
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);
    uint256 _receiverTokenBalance = _token.balanceOf(_receiver);
    _amountToken = bound(_amountToken, 0, _timelockTokenBalance);

    _upgradeToBravoGovernor();

    // Craft a new proposal to send ETH and tokens.
    address[] memory _targets = new address[](2);
    uint256[] memory _values = new uint256[](2);
    bytes[] memory _calldatas = new bytes[](2);

    // First call transfers tokens.
    _targets[0] = address(_token);
    _calldatas[0] =
      _buildProposalData("transfer(address,uint256)", abi.encode(_receiver, _amountToken));

    // Second call sends ETH.
    _targets[1] = _receiver;
    _values[1] = _amountETH;

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      _targets,
      _values,
      _calldatas,
      "Transfer tokens and ETH via the new Governor",
      FOR // Vote/suppport type.
    );

    // Ensure the ETH was transferred.
    assertEq(_receiver.balance, _receiverETHBalance + _amountETH);
    assertEq(TIMELOCK.balance, _timelockETHBalance - _amountETH);

    // Ensure the tokens were transferred.
    assertEq(_token.balanceOf(_receiver), _receiverTokenBalance + _amountToken);
    assertEq(_token.balanceOf(TIMELOCK), _timelockTokenBalance - _amountToken);
  }

  function testFuzz_NewGovernorFailedProposalsCantSendETH(uint256 _amount, address _receiver)
    public
  {
    _assumeReceiver(_receiver);
    vm.deal(TIMELOCK, _amount);
    uint256 _timelockETHBalance = TIMELOCK.balance;
    uint256 _receiverETHBalance = _receiver.balance;

    _upgradeToBravoGovernor();

    // Craft a new proposal to send ETH.
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    _targets[0] = _receiver;
    _values[0] = _amount;

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      _targets,
      _values,
      new bytes[](1), // There is no calldata for a plain ETH call.
      "Transfer some ETH via the new Governor",
      (_amount % 2 == 1 ? AGAINST : ABSTAIN) // Randomize vote type.
    );

    // Ensure ETH was *not* transferred.
    assertEq(_receiver.balance, _receiverETHBalance);
    assertEq(TIMELOCK.balance, _timelockETHBalance);
  }

  function testFuzz_NewGovernorCanUpdateSettingsViaSuccessfulProposal(
    uint256 _newDelay,
    uint256 _newVotingPeriod,
    uint256 _newProposalThreshold
  ) public {
    // The upper bounds are arbitrary here.
    _newDelay = bound(_newDelay, 0, 50_000); // about a week at 1 block per 12s
    _newVotingPeriod = bound(_newVotingPeriod, 1, 200_000); // about a month
    _newProposalThreshold = bound(_newProposalThreshold, 0, 42 ether);

    _upgradeToBravoGovernor();

    address[] memory _targets = new address[](3);
    uint256[] memory _values = new uint256[](3);
    bytes[] memory _calldatas = new bytes[](3);
    string memory _description = "Update governance settings";

    _targets[0] = address(governorBravo);
    _calldatas[0] = _buildProposalData("setVotingDelay(uint256)", abi.encode(_newDelay));

    _targets[1] = address(governorBravo);
    _calldatas[1] = _buildProposalData("setVotingPeriod(uint256)", abi.encode(_newVotingPeriod));

    _targets[2] = address(governorBravo);
    _calldatas[2] =
      _buildProposalData("setProposalThreshold(uint256)", abi.encode(_newProposalThreshold));

    // Submit the new proposal
    vm.prank(PROPOSER);
    uint256 _newProposalId = governorBravo.propose(_targets, _values, _calldatas, _description);

    // Ensure proposal is in the expected state
    IGovernor.ProposalState _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Pending);

    _jumpToActiveProposal(_newProposalId);

    _delegatesCastVoteOnBravoGovernor(_newProposalId, FOR);
    _jumpToVotingComplete(_newProposalId);

    // Ensure the proposal has succeeded
    _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Succeeded);

    // Queue the proposal
    governorBravo.queue(_targets, _values, _calldatas, keccak256(bytes(_description)));

    // Ensure the proposal is queued
    _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Queued);

    _jumpPastProposalEta(_newProposalId);

    // Execute the proposal
    governorBravo.execute(_targets, _values, _calldatas, keccak256(bytes(_description)));

    // Ensure the proposal is executed
    _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Executed);

    // Confirm that governance settings have updated.
    assertEq(governorBravo.votingDelay(), _newDelay);
    assertEq(governorBravo.votingPeriod(), _newVotingPeriod);
    assertEq(governorBravo.proposalThreshold(), _newProposalThreshold);
  }

  function testFuzz_NewGovernorCanPassMixedProposal(
    uint256 _amount,
    address _receiver,
    uint256 _seed
  ) public {
    IERC20 _token = _randomERC20Token(_seed);
    _assumeReceiver(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);

    // bound by the number of tokens the timelock currently controls
    _amount = bound(_amount, 0, _timelockTokenBalance);
    uint256 _initialTokenBalance = _token.balanceOf(_receiver);

    _upgradeToBravoGovernor();
    (
      uint256 _newProposalId,
      address[] memory _targets,
      uint256[] memory _values,
      bytes[] memory _calldatas,
      string memory _description
    ) = _submitTokenSendProposalToGovernorBravo(address(_token), _amount, _receiver);

    _jumpToActiveProposal(_newProposalId);

    // Delegates vote with a mix of For/Against/Abstain with For winning.
    vm.prank(delegates[0].addr);
    governorBravo.castVote(_newProposalId, FOR);
    vm.prank(delegates[1].addr);
    governorBravo.castVote(_newProposalId, FOR);
    vm.prank(delegates[2].addr);
    governorBravo.castVote(_newProposalId, FOR);
    vm.prank(delegates[3].addr);
    governorBravo.castVote(_newProposalId, AGAINST);
    vm.prank(delegates[4].addr);
    governorBravo.castVote(_newProposalId, ABSTAIN);
    vm.prank(delegates[5].addr);
    governorBravo.castVote(_newProposalId, AGAINST);

    // The vote should pass. We are asserting against the raw delegate voting
    // weight as a sanity check. In the event that the fork block is changed and
    // voting weights are materially different than they were when the test was
    // written, we want this assertion to fail.
    assertGt(
      delegates[0].votes + delegates[1].votes + delegates[2].votes, // FOR votes.
      delegates[3].votes + delegates[5].votes // AGAINST votes.
    );

    _jumpToVotingComplete(_newProposalId);

    // Ensure the proposal has succeeded
    IGovernor.ProposalState _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Succeeded);

    // Queue the proposal
    governorBravo.queue(_targets, _values, _calldatas, keccak256(bytes(_description)));

    _jumpPastProposalEta(_newProposalId);

    // Execute the proposal
    governorBravo.execute(_targets, _values, _calldatas, keccak256(bytes(_description)));

    // Ensure the proposal is executed
    _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Executed);

    // Ensure the tokens have been transferred
    assertEq(_token.balanceOf(_receiver), _initialTokenBalance + _amount);
    assertEq(_token.balanceOf(TIMELOCK), _timelockTokenBalance - _amount);
  }

  function testFuzz_NewGovernorCanDefeatMixedProposal(
    uint256 _amount,
    address _receiver,
    uint256 _seed
  ) public {
    IERC20 _token = _randomERC20Token(_seed);
    _assumeReceiver(_receiver);
    uint256 _timelockTokenBalance = _token.balanceOf(TIMELOCK);

    // bound by the number of tokens the timelock currently controls
    _amount = bound(_amount, 0, _timelockTokenBalance);

    _upgradeToBravoGovernor();
    (
      uint256 _newProposalId,
      address[] memory _targets,
      uint256[] memory _values,
      bytes[] memory _calldatas,
      string memory _description
    ) = _submitTokenSendProposalToGovernorBravo(address(_token), _amount, _receiver);

    _jumpToActiveProposal(_newProposalId);

    // Delegates vote with a mix of For/Against/Abstain with Against/Abstain winning.
    vm.prank(delegates[0].addr);
    governorBravo.castVote(_newProposalId, ABSTAIN);
    vm.prank(delegates[1].addr);
    governorBravo.castVote(_newProposalId, FOR);
    vm.prank(delegates[2].addr);
    governorBravo.castVote(_newProposalId, AGAINST);
    vm.prank(delegates[3].addr);
    governorBravo.castVote(_newProposalId, AGAINST);
    vm.prank(delegates[4].addr);
    governorBravo.castVote(_newProposalId, AGAINST);
    vm.prank(delegates[5].addr);
    governorBravo.castVote(_newProposalId, FOR);

    // The vote should fail. We are asserting against the raw delegate voting
    // weight as a sanity check. In the event that the fork block is changed and
    // voting weights are materially different than they were when the test was
    // written, we want this assertion to fail.
    assertLt(
      delegates[1].votes + delegates[5].votes, // FOR votes.
      delegates[2].votes + delegates[3].votes + delegates[4].votes // AGAINST votes.
    );

    _jumpToVotingComplete(_newProposalId);

    // Ensure the proposal has failed
    IGovernor.ProposalState _state = governorBravo.state(_newProposalId);
    assertEq(_state, IGovernor.ProposalState.Defeated);

    // It should not be possible to queue the proposal
    vm.expectRevert("Governor: proposal not successful");
    governorBravo.queue(_targets, _values, _calldatas, keccak256(bytes(_description)));
  }

  struct NewGovernorUnaffectedByVotesOnOldGovernorVars {
    uint256 alphaProposalId;
    address[] alphaTargets;
    uint256[] alphaValues;
    string[] alphaSignatures;
    bytes[] alphaCalldatas;
    string alphaDescription;
    uint256 bravoProposalId;
    address[] bravoTargets;
    uint256[] bravoValues;
    bytes[] bravoCalldatas;
    string bravoDescription;
  }

  function testFuzz_NewGovernorUnaffectedByVotesOnOldGovernor(
    uint256 _amount,
    address _receiver,
    uint256 _seed
  ) public {
    NewGovernorUnaffectedByVotesOnOldGovernorVars memory _vars;
    IERC20 _token = _randomERC20Token(_seed);
    _assumeReceiver(_receiver);

    _upgradeToBravoGovernor();

    // Create a new proposal to send the token.
    _vars.alphaTargets = new address[](1);
    _vars.alphaValues = new uint256[](1);
    _vars.alphaSignatures = new string [](1);
    _vars.alphaCalldatas = new bytes[](1);
    _vars.alphaDescription = "Transfer some tokens from the new Governor";

    _vars.alphaTargets[0] = address(_token);
    _vars.alphaSignatures[0] = "transfer(address,uint256)";
    _vars.alphaCalldatas[0] = abi.encode(_receiver, _amount);

    // Submit the new proposal to Governor Alpha, which is now deprecated.
    vm.prank(PROPOSER);
    _vars.alphaProposalId = governorAlpha.propose(
      _vars.alphaTargets,
      _vars.alphaValues,
      _vars.alphaSignatures,
      _vars.alphaCalldatas,
      _vars.alphaDescription
    );

    // Now construct and submit an identical proposal on Governor Bravo, which is active.
    (
      _vars.bravoProposalId,
      _vars.bravoTargets,
      _vars.bravoValues,
      _vars.bravoCalldatas,
      _vars.bravoDescription
    ) = _submitTokenSendProposalToGovernorBravo(address(_token), _amount, _receiver);

    assertEq(
      uint8(governorAlpha.state(_vars.alphaProposalId)),
      uint8(governorBravo.state(_vars.bravoProposalId))
    );

    _jumpToActiveProposal(_vars.bravoProposalId);

    // Defeat the proposal on Bravo.
    assertEq(governorBravo.state(_vars.bravoProposalId), IGovernor.ProposalState.Active);
    _delegatesCastVoteOnBravoGovernor(_vars.bravoProposalId, AGAINST);

    // Pass the proposal on Alpha.
    for (uint256 _index = 0; _index < delegates.length; _index++) {
      vm.prank(delegates[_index].addr);
      governorAlpha.castVote(_vars.alphaProposalId, true);
    }

    _jumpToVotingComplete(_vars.bravoProposalId);

    // Ensure the Bravo proposal has failed and Alpha has succeeded.
    assertEq(governorBravo.state(_vars.bravoProposalId), IGovernor.ProposalState.Defeated);
    assertEq(governorAlpha.state(_vars.alphaProposalId), uint8(IGovernor.ProposalState.Succeeded));

    // It should not be possible to queue either proposal, confirming that votes
    // on alpha do not affect votes on bravo.
    vm.expectRevert("Governor: proposal not successful");
    governorBravo.queue(
      _vars.bravoTargets,
      _vars.bravoValues,
      _vars.bravoCalldatas,
      keccak256(bytes(_vars.bravoDescription))
    );
    vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
    governorAlpha.queue(_vars.alphaProposalId);
  }
}

contract CastVoteWithReasonAndParams is ProposalTest {
  using FixedPointMathLib for uint256;

  // Store the id of a new proposal unrelated to governor upgrade.
  uint256 newProposalId;

  event VoteCastWithParams(
    address indexed voter,
    uint256 proposalId,
    uint8 support,
    uint256 weight,
    string reason,
    bytes params
  );

  function setUp() public virtual override(ProposalTest) {
    ProposalTest.setUp();

    _upgradeToBravoGovernor();

    (newProposalId,,,,) = _submitTokenSendProposalToGovernorBravo(
      address(DAI_ADDRESS),
      IERC20(DAI_ADDRESS).balanceOf(TIMELOCK),
      makeAddr("receiver for FlexVoting tests")
    );

    _jumpToActiveProposal(newProposalId);
  }

  function testFuzz_GovernorBravoSupportsCastingSplitVotes(
    uint256 _forVotePercentage,
    uint256 _againstVotePercentage,
    uint256 _abstainVotePercentage
  ) public {
    _forVotePercentage = bound(_forVotePercentage, 0.0e18, 1.0e18);
    _againstVotePercentage = bound(_againstVotePercentage, 0.0e18, 1.0e18 - _forVotePercentage);
    _abstainVotePercentage =
      bound(_abstainVotePercentage, 0.0e18, 1.0e18 - _forVotePercentage - _againstVotePercentage);

    // Attempt to split vote weight on this new proposal.
    uint256 _votingSnapshot = governorBravo.proposalSnapshot(newProposalId);
    uint256 _totalForVotes;
    uint256 _totalAgainstVotes;
    uint256 _totalAbstainVotes;
    for (uint256 _i; _i < delegates.length; _i++) {
      address _voter = delegates[_i].addr;
      uint256 _weight = IPOOL(POOL_TOKEN).getPriorVotes(_voter, _votingSnapshot);

      uint128 _forVotes = uint128(_weight.mulWadDown(_forVotePercentage));
      uint128 _againstVotes = uint128(_weight.mulWadDown(_againstVotePercentage));
      uint128 _abstainVotes = uint128(_weight.mulWadDown(_abstainVotePercentage));
      bytes memory _fractionalizedVotes = abi.encodePacked(_againstVotes, _forVotes, _abstainVotes);
      _totalForVotes += _forVotes;
      _totalAgainstVotes += _againstVotes;
      _totalAbstainVotes += _abstainVotes;

      // The accepted support types for Bravo fall within [0,2].
      uint8 _supportTypeDoesntMatterForFlexVoting = uint8(bound(_i, 0, 2));

      vm.expectEmit(true, true, true, true);
      emit VoteCastWithParams(
        _voter,
        newProposalId,
        _supportTypeDoesntMatterForFlexVoting, // Really: support type is ignored.
        _weight,
        "I do what I want",
        _fractionalizedVotes
      );

      // This call should succeed.
      vm.prank(_voter);
      governorBravo.castVoteWithReasonAndParams(
        newProposalId,
        _supportTypeDoesntMatterForFlexVoting,
        "I do what I want",
        _fractionalizedVotes
      );
    }

    // Ensure the votes were split.
    (uint256 _actualAgainstVotes, uint256 _actualForVotes, uint256 _actualAbstainVotes) =
      governorBravo.proposalVotes(newProposalId);
    assertEq(_totalForVotes, _actualForVotes);
    assertEq(_totalAgainstVotes, _actualAgainstVotes);
    assertEq(_totalAbstainVotes, _actualAbstainVotes);
  }

  struct VoteData {
    uint128 forVotes;
    uint128 againstVotes;
    uint128 abstainVotes;
  }

  function testFuzz_GovernorBravoSupportsCastingPartialSplitVotes(
    uint256 _firstVotePercentage,
    uint256 _forVotePercentage,
    uint256 _againstVotePercentage,
    uint256 _abstainVotePercentage
  ) public {
    // This is the % of total weight that will be cast the first time.
    _firstVotePercentage = bound(_firstVotePercentage, 0.1e18, 0.9e18);

    _forVotePercentage = bound(_forVotePercentage, 0.0e18, 1.0e18);
    _againstVotePercentage = bound(_againstVotePercentage, 0.0e18, 1.0e18 - _forVotePercentage);
    _abstainVotePercentage =
      bound(_abstainVotePercentage, 0.0e18, 1.0e18 - _forVotePercentage - _againstVotePercentage);

    uint256 _weight = IPOOL(POOL_TOKEN).getPriorVotes(
      PROPOSER, // The proposer is also the top delegate.
      governorBravo.proposalSnapshot(newProposalId)
    );

    // The accepted support types for Bravo fall within [0,2].
    uint8 _supportTypeDoesntMatterForFlexVoting = uint8(2);

    // Cast partial vote the first time.
    VoteData memory _firstVote;
    uint256 _voteWeight = _weight.mulWadDown(_firstVotePercentage);
    _firstVote.forVotes = uint128(_voteWeight.mulWadDown(_forVotePercentage));
    _firstVote.againstVotes = uint128(_voteWeight.mulWadDown(_againstVotePercentage));
    _firstVote.abstainVotes = uint128(_voteWeight.mulWadDown(_abstainVotePercentage));
    vm.prank(PROPOSER);
    governorBravo.castVoteWithReasonAndParams(
      newProposalId,
      _supportTypeDoesntMatterForFlexVoting,
      "My first vote",
      abi.encodePacked(_firstVote.againstVotes, _firstVote.forVotes, _firstVote.abstainVotes)
    );

    ( // Ensure the votes were recorded.
    uint256 _againstVotesCast, uint256 _forVotesCast, uint256 _abstainVotesCast) =
      governorBravo.proposalVotes(newProposalId);
    assertEq(_firstVote.forVotes, _forVotesCast);
    assertEq(_firstVote.againstVotes, _againstVotesCast);
    assertEq(_firstVote.abstainVotes, _abstainVotesCast);

    // Cast partial vote the second time.
    VoteData memory _secondVote;
    _voteWeight = _weight.mulWadDown(1e18 - _firstVotePercentage);
    _secondVote.forVotes = uint128(_voteWeight.mulWadDown(_forVotePercentage));
    _secondVote.againstVotes = uint128(_voteWeight.mulWadDown(_againstVotePercentage));
    _secondVote.abstainVotes = uint128(_voteWeight.mulWadDown(_abstainVotePercentage));
    vm.prank(PROPOSER);
    governorBravo.castVoteWithReasonAndParams(
      newProposalId,
      _supportTypeDoesntMatterForFlexVoting,
      "My second vote",
      abi.encodePacked(_secondVote.againstVotes, _secondVote.forVotes, _secondVote.abstainVotes)
    );

    ( // Ensure the new votes were recorded.
    _againstVotesCast, _forVotesCast, _abstainVotesCast) =
      governorBravo.proposalVotes(newProposalId);
    assertEq(_firstVote.forVotes + _secondVote.forVotes, _forVotesCast);
    assertEq(_firstVote.againstVotes + _secondVote.againstVotes, _againstVotesCast);
    assertEq(_firstVote.abstainVotes + _secondVote.abstainVotes, _abstainVotesCast);

    // Confirm nominal votes can co-exist with partial+fractional votes by
    // voting with the second largest delegate.
    uint256 _nominalVoterWeight = IPOOL(POOL_TOKEN).getPriorVotes(
      delegates[1].addr, governorBravo.proposalSnapshot(newProposalId)
    );
    vm.prank(delegates[1].addr);
    governorBravo.castVote(newProposalId, FOR);

    ( // Ensure the nominal votes were recorded.
    _againstVotesCast, _forVotesCast, _abstainVotesCast) =
      governorBravo.proposalVotes(newProposalId);
    assertEq(_firstVote.forVotes + _secondVote.forVotes + _nominalVoterWeight, _forVotesCast);
    assertEq(_firstVote.againstVotes + _secondVote.againstVotes, _againstVotesCast);
    assertEq(_firstVote.abstainVotes + _secondVote.abstainVotes, _abstainVotesCast);
  }

  function testFuzz_ProposalsCanBePassedWithSplitVotes(
    uint256 _forVotePercentage,
    uint256 _againstVotePercentage,
    uint256 _abstainVotePercentage
  ) public {
    _forVotePercentage = bound(_forVotePercentage, 0.0e18, 1.0e18);
    _againstVotePercentage = bound(_againstVotePercentage, 0.0e18, 1.0e18 - _forVotePercentage);
    _abstainVotePercentage =
      bound(_abstainVotePercentage, 0.0e18, 1.0e18 - _forVotePercentage - _againstVotePercentage);

    uint256 _weight = IPOOL(POOL_TOKEN).getPriorVotes(
      PROPOSER, // The proposer is also the top delegate.
      governorBravo.proposalSnapshot(newProposalId)
    );

    uint128 _forVotes = uint128(_weight.mulWadDown(_forVotePercentage));
    uint128 _againstVotes = uint128(_weight.mulWadDown(_againstVotePercentage));
    uint128 _abstainVotes = uint128(_weight.mulWadDown(_abstainVotePercentage));

    // The accepted support types for Bravo fall within [0,2].
    uint8 _supportTypeDoesntMatterForFlexVoting = uint8(2);

    vm.prank(PROPOSER);
    governorBravo.castVoteWithReasonAndParams(
      newProposalId,
      _supportTypeDoesntMatterForFlexVoting,
      "My vote",
      abi.encodePacked(_againstVotes, _forVotes, _abstainVotes)
    );

    ( // Ensure the votes were split.
    uint256 _actualAgainstVotes, uint256 _actualForVotes, uint256 _actualAbstainVotes) =
      governorBravo.proposalVotes(newProposalId);
    assertEq(_forVotes, _actualForVotes);
    assertEq(_againstVotes, _actualAgainstVotes);
    assertEq(_abstainVotes, _actualAbstainVotes);

    _jumpToVotingComplete(newProposalId);

    IGovernor.ProposalState _state = governorBravo.state(newProposalId);

    if (_forVotes >= governorBravo.quorum(block.number) && _forVotes > _againstVotes) {
      assertEq(_state, IGovernor.ProposalState.Succeeded);
    } else {
      assertEq(_state, IGovernor.ProposalState.Defeated);
    }
  }
}

contract _Execute is ProposalTest {
  function setUp() public virtual override(ProposalTest) {
    ProposalTest.setUp();
    _upgradeToBravoGovernor();
  }

  function _randomUniswapPosition(uint256 _seed) internal pure returns (uint256 _token) {
    if (_seed % 6 == 0) _token = 454_861;
    if (_seed % 6 == 1) _token = 454_865;
    if (_seed % 6 == 2) _token = 326_807;
    if (_seed % 6 == 3) _token = 326_798;
    if (_seed % 6 == 4) _token = 326_783;
    if (_seed % 6 == 5) _token = 321_228;
  }

  function testFuzz_UpdateV4DripRate(uint256 newDrip) public {
    // Drip must be greater than 0
    // https://etherscan.io/address/0xbd537257fad96e977b9e545be583bbf7028f30b9#code#F1#L162
    vm.assume(newDrip > 0);

    IV4PoolTogetherTokenFaucet tokenFaucet = IV4PoolTogetherTokenFaucet(V4_TOKEN_FAUCET);

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      V4_TOKEN_FAUCET, 0, abi.encodeWithSignature("setDripRatePerSecond(uint256)", newDrip)
    );

    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(),
      proposals.values(),
      proposals.calldatas(),
      "Change to a new drip rate.",
      FOR
    );

    // Assert that the drip has been changed
    assertEq(newDrip, tokenFaucet.dripRatePerSecond(), "New drip value is not correct");
  }

  function testFuzz_UpdateV3ReserveRate(uint224 _newRate) public {
    IV3ConfigurableReserve configurableReserve = IV3ConfigurableReserve(V3_CONFIGURABLE_RESERVE);

    address reserveSource = 0x821B9819c0348076AD370b376522e1327AF7684A;

    address[] memory _sources = new address[](1);
    uint224[] memory _reserveRates = new uint224[](1);
    bool[] memory _useCustom = new bool[](1);

    _sources[0] = reserveSource;
    _reserveRates[0] = _newRate;
    _useCustom[0] = true;

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      V3_CONFIGURABLE_RESERVE,
      0,
      abi.encodeWithSignature(
        "setReserveRateMantissa(address[],uint224[],bool[])", _sources, _reserveRates, _useCustom
      )
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(),
      proposals.values(),
      proposals.calldatas(),
      "Change the reserve rate.",
      FOR
    );

    // Assert that the reserve rate has changed
    assertEq(
      _newRate,
      configurableReserve.reserveRateMantissa(reserveSource),
      "New reserve rate is not correct"
    );
  }

  function testFuzz_SunsetV3StakePool(uint224 _newRate) public {
    IV3ConfigurableReserve configurableReserve = IV3ConfigurableReserve(V3_CONFIGURABLE_RESERVE);

    address reserveSource = STAKE_PRIZE_POOL;
    uint256 reserveRate = configurableReserve.reserveRateMantissa(reserveSource);
    assertEq(reserveRate, 0, "Old reserve rate is not correct");

    IStakePrizePool prizePool = IStakePrizePool(STAKE_PRIZE_POOL);
    uint256 oldAmount = prizePool.reserveTotalSupply();
    assertEq(oldAmount, 31_270_374_730_242_635_937, "Current amount is incorrect");

    address[] memory _sources = new address[](1);
    uint224[] memory _reserveRates = new uint224[](1);
    bool[] memory _useCustom = new bool[](1);

    _sources[0] = reserveSource;
    _reserveRates[0] = _newRate;
    _useCustom[0] = true;
    string memory _description = "Change rate and withdraw reserve";

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      V3_CONFIGURABLE_RESERVE,
      0,
      abi.encodeWithSignature(
        "setReserveRateMantissa(address[],uint224[],bool[])", _sources, _reserveRates, _useCustom
      )
    );
    proposals.add(
      V3_CONFIGURABLE_RESERVE,
      0,
      abi.encodeWithSignature(
        "withdrawReserve(address,address)", STAKE_PRIZE_POOL, POOLTOGETHER_TREASURY
      )
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    // Assert the reserve has been withdrawn
    uint256 newAmount = prizePool.reserveTotalSupply();
    assertEq(newAmount, 0, "New amount is incorrect");

    // Assert that the reserve rate has been changed
    assertEq(
      _newRate, configurableReserve.reserveRateMantissa(reserveSource), "New reserve is not correct"
    );
  }

  function testFuzz_SetNumV3Winners(uint256 usdcNumWinners, uint256 daiNumWinners) public {
    // Cannot be 0 address
    // https://etherscan.io/address/0x3d9946190907ada8b70381b25c71eb9adf5f9b7b#code#F1#L54
    vm.assume(usdcNumWinners > 0);
    vm.assume(daiNumWinners > 0);

    string memory _description = "Increase the number of winners in the following V3 pools";
    address USDC_PRIZE_STRATEGY = 0x3D9946190907aDa8b70381b25c71eB9adf5f9B7b;
    address DAI_PRIZE_STRATEGY = 0x178969A87a78597d303C47198c66F68E8be67Dc2;

    IV3MultipleWinners usdcStrategy = IV3MultipleWinners(USDC_PRIZE_STRATEGY);

    IV3MultipleWinners daiStrategy = IV3MultipleWinners(DAI_PRIZE_STRATEGY);

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      USDC_PRIZE_STRATEGY, 0, abi.encodeWithSignature("setNumberOfWinners(uint256)", usdcNumWinners)
    );
    proposals.add(
      DAI_PRIZE_STRATEGY, 0, abi.encodeWithSignature("setNumberOfWinners(uint256)", daiNumWinners)
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    // Assert the number of DAI winners is correct
    uint256 newDaiWinners = daiStrategy.numberOfWinners();
    assertEq(newDaiWinners, daiNumWinners);

    // Assert the number of USDC winners is correct
    uint256 newUsdcWinners = usdcStrategy.numberOfWinners();
    assertEq(newUsdcWinners, usdcNumWinners);
  }

  function test_SendUniswapPosition(uint256 _seed) public {
    string memory _description = "Send Uniswap V3 position to controlled multisig";
    IERC721 uniswapPositionManager = IERC721(UNISWAP_POSITION_CONTRACT);
    uint256 uniswapPosition = _randomUniswapPosition(_seed);

    uint256 balance = uniswapPositionManager.balanceOf(TIMELOCK);
    assertEq(balance, 6);

    uint256 safeBalance = uniswapPositionManager.balanceOf(POOLTOGETHER_UNISWAP_SAFE);
    assertEq(safeBalance, 0);

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      UNISWAP_POSITION_CONTRACT,
      0,
      abi.encodeWithSignature(
        "transferFrom(address,address,uint256)",
        TIMELOCK,
        POOLTOGETHER_UNISWAP_SAFE,
        uniswapPosition
      )
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    uint256 newBalance = uniswapPositionManager.balanceOf(TIMELOCK);
    assertEq(newBalance, 5);

    uint256 newSafeBalance = uniswapPositionManager.balanceOf(POOLTOGETHER_UNISWAP_SAFE);
    assertEq(newSafeBalance, 1);
  }

  function testFuzz_V3PrizePoolSetCreditPlanOf(uint128 _creditLimit, uint128 _creditRate) public {
    string memory _description = "Set a new credit plan for the POOL token ";
    IStakePrizePool prizePool = IStakePrizePool(STAKE_PRIZE_POOL);

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      STAKE_PRIZE_POOL,
      0,
      abi.encodeWithSignature(
        "setCreditPlanOf(address,uint128,uint128)",
        POOLTOGETHER_POOL_TICKET,
        _creditRate,
        _creditLimit
      )
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    (uint256 newCreditLimit, uint256 newCreditRate) =
      prizePool.creditPlanOf(POOLTOGETHER_POOL_TICKET);
    assertEq(newCreditLimit, _creditLimit, "New credit limit is incorrect");
    assertEq(newCreditRate, _creditRate, "New credit rate is incorrect");
  }

  function testFuzz_V3PrizePoolSetLiquidityCap(uint256 _cap) public {
    string memory _description = "Set a new liquidity cap for the POOL token ";
    IStakePrizePool prizePool = IStakePrizePool(STAKE_PRIZE_POOL);

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(STAKE_PRIZE_POOL, 0, abi.encodeWithSignature("setLiquidityCap(uint256)", _cap));
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    uint256 newCap = prizePool.liquidityCap();
    assertEq(newCap, _cap, "New cap is incorrect");
  }

  function test_V3PrizePoolSetPrizeStrategy() public {
    string memory _description = "Set a new prize pool strategy for the POOL token ";
    IStakePrizePool prizePool = IStakePrizePool(STAKE_PRIZE_POOL);

    address prizeStratedgy = prizePool.prizeStrategy();
    assertEq(
      prizeStratedgy, 0x21E5E62e0B6B59155110cD36F3F6655FBbCF6424, "Old strategy is incorrect"
    );

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      STAKE_PRIZE_POOL,
      0,
      abi.encodeWithSignature(
        "setPrizeStrategy(address)", 0x178969A87a78597d303C47198c66F68E8be67Dc2
      )
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    address newStratedgy = prizePool.prizeStrategy();
    assertEq(newStratedgy, 0x178969A87a78597d303C47198c66F68E8be67Dc2, "New strategy is incorrect");
  }

  function test_V3PrizePoolCompLikeDelegate(address newDelegate) public {
    // Cannot delegate to the 0 address
    // https://etherscan.io/address/0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e#code#F1#L329
    vm.assume(newDelegate != address(0));
    vm.assume(newDelegate != 0x070a96fe4Ad5155eA91d409E8AFec6B2F3C729c0); // Already has POOL

    string memory _description = "Set comp like delegate";
    ERC20VotesComp token = ERC20VotesComp(POOL_TOKEN);
    uint256 currentVotes = token.getCurrentVotes(newDelegate);

    ProposalBuilder proposals = new ProposalBuilder();
    proposals.add(
      STAKE_PRIZE_POOL,
      0,
      abi.encodeWithSignature("compLikeDelegate(address,address)", POOL_TOKEN, newDelegate)
    );
    _queueAndVoteAndExecuteProposalWithBravoGovernor(
      proposals.targets(), proposals.values(), proposals.calldatas(), _description, FOR
    );

    vm.warp(10);
    uint256 newDelegateCurrentVotes = token.getCurrentVotes(newDelegate);
    assertEq(newDelegateCurrentVotes, currentVotes + 506_647_255_990_808_587_266_180, "New delegate current votes");
  }
}
