pragma solidity ^0.8.18;

// Generated with `cast interface 0xBD537257fAd96e977b9E545bE583bbF7028F30b9`
interface IV4PoolTogetherTokenFaucet {
  event Claimed(address indexed user, uint256 newTokens);
  event Deposited(address indexed user, uint256 amount);
  event DripRateChanged(uint256 dripRatePerSecond);
  event Dripped(uint256 newTokens);
  event Initialized(address indexed asset, address indexed measure, uint256 dripRatePerSecond);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function asset() external view returns (address);
  function beforeTokenMint(address to, uint256 amount, address token, address referrer) external;
  function beforeTokenTransfer(address from, address to, uint256, address token) external;
  function claim(address user) external returns (uint256);
  function deposit(uint256 amount) external;
  function drip() external returns (uint256);
  function dripRatePerSecond() external view returns (uint256);
  function exchangeRateMantissa() external view returns (uint112);
  function initialize(address _asset, address _measure, uint256 _dripRatePerSecond) external;
  function lastDripTimestamp() external view returns (uint32);
  function measure() external view returns (address);
  function owner() external view returns (address);
  function renounceOwnership() external;
  function setDripRatePerSecond(uint256 _dripRatePerSecond) external;
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
  function totalUnclaimed() external view returns (uint112);
  function transferOwnership(address newOwner) external;
  function userStates(address)
    external
    view
    returns (uint128 lastExchangeRateMantissa, uint128 balance);
}
