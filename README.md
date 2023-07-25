# PoolTogether Governor Bravo

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
