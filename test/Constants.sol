// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

contract Constants {
  address constant GOVERNOR_ALPHA = 0xB3a87172F555ae2a2AB79Be60B336D2F7D0187f0;
  address constant POOL_TOKEN = 0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e;
  address constant TIMELOCK = 0x42cd8312D2BCe04277dD5161832460e95b24262E;
  address constant PROPOSER = 0xe0e7b7C5aE92Fe94D2ae677D81214D6Ad7A11C27; // lonser.eth
  address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address constant RAD_ADDRESS = 0x31c8EAcBFFdD875c74b94b077895Bd78CF1E64A3;
  uint256 constant MAX_REASONABLE_TIME_PERIOD = 302_400; // 6 weeks assuming a 12 second block time

  uint256 constant QUORUM = 100_000e18;
}
