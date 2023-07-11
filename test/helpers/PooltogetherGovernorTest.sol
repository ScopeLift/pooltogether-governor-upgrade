// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";
import {IPOOL} from "src/interfaces/IPOOL.sol";
import {PooltogetherGovernor} from "src/PooltogetherGovernor.sol";

abstract contract PooltogetherGovernorTest is Test, DeployInput {
  using FixedPointMathLib for uint256;

  uint256 constant QUORUM = 2_500_000e18;
  address constant POOL_TOKEN = 0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e;
  IPOOL poolToken = IPOOL(POOL_TOKEN);
  address constant TIMELOCK = 0x42cd8312D2BCe04277dD5161832460e95b24262E;
  address constant PROPOSER = 0xe0e7b7C5aE92Fe94D2ae677D81214D6Ad7A11C27; // lonser.eth
  uint256 constant MAX_REASONABLE_TIME_PERIOD = 302_400; // 6 weeks assuming a 12 second block time

  struct Delegate {
    string handle;
    address addr;
    uint96 votes;
  }

  Delegate[] delegates;

  PooltogetherGovernor governorBravo;

  function setUp() public virtual {
    // The latest block when this test was written. If you update the fork block
    // make sure to also update the top 6 delegates below.
    uint256 _forkBlock = 17_665_572;
    vm.createSelectFork(vm.rpcUrl("mainnet"), _forkBlock);

    // Taken from https://www.tally.xyz/gov/pooltogether/delegates?sort=voting_power_desc.
    // If you update these delegates (including updating order in the array),
    // make sure to update any tests that reference specific delegates. The last delegate is the
    // proposer and lower in the voting power than the above link.
    Delegate[] memory _delegates = new Delegate[](6);
    _delegates[0] = Delegate("gnosis safe", 0x070a96fe4Ad5155eA91d409E8AFec6B2F3C729c0, 507.12e3);
    _delegates[1] =
      Delegate("A second gnosis safe", 0x9aBad5d367565425a11aB0446cdc1CD3F38a0bd8, 340e3);
    _delegates[2] =
      Delegate("A third gnosis safe", 0xFAdd8d4753658311adE98eECD2353f50F2Eb35BF, 150e3);
    _delegates[3] = Delegate("random address", 0xa4b8339D2162125b33A667b0D40aC5dec27E924b, 138.89e3);
    _delegates[4] = Delegate("shacheng", 0xFFb032E27b70DfAD518753BAAa77040F64df9840, 112.45e3);
    _delegates[5] = Delegate("proposer", PROPOSER, 45.01e3);

    // Fetch up-to-date voting weight for the top delegates.
    for (uint256 i; i < _delegates.length; i++) {
      Delegate memory _delegate = _delegates[i];
      _delegate.votes = poolToken.getCurrentVotes(_delegate.addr);
      delegates.push(_delegate);
    }

    // Use deployed governor once it is deployed
    Deploy _deployScript = new Deploy();
    _deployScript.setUp();
    governorBravo = _deployScript.run();
  }
}
