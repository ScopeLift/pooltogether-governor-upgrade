# PoolTogether Governor Bravo Upgrade

An upgrade to a "Bravo" compatible Governor for the PoolTogether DAO, built using the OpenZeppelin implemented and [Flexible Voting](https://github.com/ScopeLift/flexible-voting).

#### Getting started

Clone the repo

```bash
git clone git@github.com:ScopeLift/pooltogether-governor-upgrade.git
cd pooltogether-governor-upgrade
```

Copy the `.env.template` file and populate it with values

```bash
cp .env.template .env
# Open the .env file and add your values
```

```bash
forge install
forge build
forge test
```

### Formatting

Formatting is done via [scopelint](https://github.com/ScopeLift/scopelint). To install scopelint, run:

```bash
cargo install scopelint
```

#### Apply formatting

```bash
scopelint fmt
```

#### Check formatting

```bash
scopelint check
```

#### Scopelint spec compatibility

Some tests will not show up when running `scopelint spec` because the methods they are testing are inherited in the `PoolTogetherGovernor`. In order to get an accurate picture of the tests with `scopelint spec` add an explicit `propose` method to the `PoolTogetherGovernor`. It should look like this:

```
 function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override(Governor, IGovernor) returns (uint256) {
    return Governor.propose(targets, values, calldatas, description);
  }
```

## Scripts

- `script/Deploy.s.sol` - Deploys the PoolTogetherGovernor contract

To test these scripts locally, start a local fork with anvil:

```bash
anvil --fork-url YOUR_RPC_URL --fork-block-number 17665572
```

Then execute the deploy script.

_NOTE_: You must populate the `DEPLOYER_PRIVATE_KEY` in your `.env` file for this to work.

```bash
forge script script/Deploy.s.sol --tc Deploy --rpc-url http://localhost:8545 --broadcast
```

Pull the contract address for the new Governor from the deploy script address, then execute the Proposal script.

_NOTE_: You must populate the `PROPOSER_PRIVATE_KEY` in your `.env` file for this to work. Additionally, the
private key must correspond to the `proposer` address defined in the `Proposal.s.sol` script. You can update this
variable to an address you control, however the proposal itself will still revert in this case, unless you provide
the private key of an address that has sufficient POOL Token delegation to have the right to submit a proposal.

```bash
forge script script/Propose.s.sol --sig "run(address)" NEW_GOVERNOR_ADDRESS --rpc-url http://localhost:8545 --broadcast
```

### Non-standard Governor changes

When upgrading PoolTogether's Alpha Governor implementation we needed to fallback on non-standard interfaces.

#### Timelock

PoolTogether's timelock is not compatible with Openzeppelin's `ICompoundTimelock` which is used by `GovernorTimelockCompound`, and is in charge of queuing and executing proposals. Due to this incompatibility we had to fork the `GovernorTimelockCompound.sol` and change the interface to conform to the PoolTogether interface.

The main issue with the interface is that PoolTogether's contract has a method `gracePeriod` when `ICompoundTimelock` is expecting the method to be called `GRACE_PERIOD`. This function is used in `GovernorTimelockCompound`'s `state` method and caused us to have to fork the `GovernorTimelockCompound`. Below is a table of all the changes we had to make between the Openzeppelin `GovernorTimelockCompound` and our forked version.

| Change name                           |                                                                                    original                                                                                    |                                                                                                                                                       Changed version |
| ------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| \_timelock type                       | [here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/49c0e4370d0cc50ea6090709e3835a3091e33ee2/contracts/governance/extensions/GovernorTimelockCompound.sol#L31)  |             [here](https://github.com/ScopeLift/pooltogether-governor-upgrade/blob/ad4276bc960a414db2244cf482683cf4da07bf70/src/lib/GovernorTimelockCompound.sol#L54) |
| Constructor argument type             | [here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/49c0e4370d0cc50ea6090709e3835a3091e33ee2/contracts/governance/extensions/GovernorTimelockCompound.sol#L43)  |             [here](https://github.com/ScopeLift/pooltogether-governor-upgrade/blob/ad4276bc960a414db2244cf482683cf4da07bf70/src/lib/GovernorTimelockCompound.sol#L71) |
| state grace period call               | [here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/49c0e4370d0cc50ea6090709e3835a3091e33ee2/contracts/governance/extensions/GovernorTimelockCompound.sol#L67)  |            [here](https://github.com/ScopeLift/pooltogether-governor-upgrade/blob/ad4276bc960a414db2244cf482683cf4da07bf70/src/lib/GovernorTimelockCompound.sol#L111) |
| Cast timelock to address              | [here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/49c0e4370d0cc50ea6090709e3835a3091e33ee2/contracts/governance/extensions/GovernorTimelockCompound.sol#L128) | [here](https://github.com/ScopeLift/pooltogether-governor-upgrade/blob/ad4276bc960a414db2244cf482683cf4da07bf70/src/lib/GovernorTimelockCompound.sol#L177C1-L177C174) |
| Update updateTimelock function args   | [here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/49c0e4370d0cc50ea6090709e3835a3091e33ee2/contracts/governance/extensions/GovernorTimelockCompound.sol#L185) |            [here](https://github.com/ScopeLift/pooltogether-governor-upgrade/blob/ad4276bc960a414db2244cf482683cf4da07bf70/src/lib/GovernorTimelockCompound.sol#L245) |
| Update \_updateTimelock function args | [here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/49c0e4370d0cc50ea6090709e3835a3091e33ee2/contracts/governance/extensions/GovernorTimelockCompound.sol#L189) |            [here](https://github.com/ScopeLift/pooltogether-governor-upgrade/blob/ad4276bc960a414db2244cf482683cf4da07bf70/src/lib/GovernorTimelockCompound.sol#L252) |


A full diff of the two contracts can be found [here](https://www.diffchecker.com/EyE5XQDS/)

#### Token

In the new Governor we inherit from `GovernorVotesComp` which expects an `ERC20VotesComp` token. The PoolTogether token is missing a few functions that exist in `ERC20VotesComp` and we have listed those missing functions below. The reason we did not fork the Openzeppelin contract and use a custom interface was because `GovernorVotesComp` calls a single function `getPriorVotes` which exists on the PoolTogether token.

A full diff of the two contracts can be found [here](https://www.diffchecker.com/m7hUJqn8/)

##### Missing functions in POOL

1. `function DOMAIN_SEPARATOR() external view returns (bytes32);`
1. `function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);`
1. `function getPastTotalSupply(uint256 blockNumber) external view returns (uint256);`
1. `function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);`
1. `function getVotes(address account) external view returns (uint256);`
1. `function increaseAllowance(address spender, uint256 addedValue) external returns (bool);`
1. `function numCheckpoints(address account) external view returns (uint32);`
1. `function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;`

##### Functions in POOL with a different signature compared with ERC20Votes

- checkpoints
  - ERC20Votes: `function checkpoints(address account, uint32 pos) external view returns (Checkpoint memory);`
  - POOL: `function checkpoints(address, uint32) external view returns (uint32 fromBlock, uint96 votes);`

### Testing issues

This repo heavily leverages fuzz fork tests causing a significant number of RPC requests to be made. We leverage caching to minimize the number of RPC calls after the tests are run for the first time, but running these tests for the first may cause timeouts and consume a significant number of RPC calls.
