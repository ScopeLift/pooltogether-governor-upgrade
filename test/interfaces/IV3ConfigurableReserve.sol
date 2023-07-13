pragma solidity ^0.8.18;

// Taken from 0xd1797D46C3E825fce5215a0259D3426a5c49455C
interface IV3ConfigurableReserve {
 function setReserveRateMantissa(address[] calldata sources, uint224[] calldata _reserveRates, bool[] calldata useCustom) external;
 function reserveRateMantissa(address source) external returns (uint256);
}
