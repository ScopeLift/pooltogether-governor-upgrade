# Pooltogether Governor Bravo

An upgrade to a "Bravo" compatible Governor for the Pooltogether DAO, built using the OpenZeppelin implemented and [Flexible Voting](https://github.com/ScopeLift/flexible-voting).

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

- `script/Deploy.s.sol` - Deploys the PooltogetherGovernor contract

To test these scripts locally, start a local fork with anvil:

```bash
anvil --fork-url YOUR_RPC_URL --fork-block-number 17665572
```

Then execute the deploy script.

_NOTE_: You must populate the `DEPLOYER_PRIVATE_KEY` in your `.env` file for this to work.

```bash
forge script script/Deploy.s.sol --tc Deploy --rpc-url http://localhost:8545 --broadcast
```
