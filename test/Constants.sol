// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

contract Constants {
  address constant GOVERNOR_ALPHA = 0xB3a87172F555ae2a2AB79Be60B336D2F7D0187f0;
  address constant POOL_TOKEN = 0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e;
  address constant TIMELOCK = 0x42cd8312D2BCe04277dD5161832460e95b24262E;
  address constant PROPOSER = 0xe0e7b7C5aE92Fe94D2ae677D81214D6Ad7A11C27; // lonser.eth
  address constant PTAUSDC_ADDRESS = 0xdd4d117723C257CEe402285D3aCF218E9A8236E1;
  address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address constant STETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  uint256 constant MAX_REASONABLE_TIME_PERIOD = 302_400; // 6 weeks assuming a 12 second block time
  address constant V4_TOKEN_FAUCET = 0xBD537257fAd96e977b9E545bE583bbF7028F30b9;
  address constant V3_CONFIGURABLE_RESERVE = 0xd1797D46C3E825fce5215a0259D3426a5c49455C;
  address constant POOLTOGETHER_TREASURY = 0x42cd8312D2BCe04277dD5161832460e95b24262E;
  address constant STAKE_PRIZE_POOL = 0x396b4489da692788e327E2e4b2B0459A5Ef26791;
  address constant UNISWAP_SAFE = 0xDa63D70332139E6A8eCA7513f4b6E2E0Dc93b693;
  address constant UNISWAP_POSITION_CONTRACT = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
  address constant POOLTOGETHER_POOL_TICKET = 0x27D22A7648e955E510a40bDb058333E9190d12D4;

  uint256 constant QUORUM = 100_000e18;
}
