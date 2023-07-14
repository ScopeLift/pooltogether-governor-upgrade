pragma solidity ^0.8.18;

// Taken from 0xd1797D46C3E825fce5215a0259D3426a5c49455C
interface IV3ConfigurableReserve {
    event DefaultReserveRateMantissaSet(uint256 rate);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReserveRateMantissaSet(address indexed prizePool, uint256 reserveRateMantissa, bool useCustom);
    event ReserveWithdrawStrategistChanged(address indexed strategist);

    function defaultReserveRateMantissa() external view returns (uint224);
    function owner() external view returns (address);
    function prizePoolMantissas(address) external view returns (uint224 rateMantissa, bool useCustom);
    function renounceOwnership() external;
    function reserveRateMantissa(address source) external view returns (uint256);
    function setDefaultReserveRateMantissa(uint224 _reserveRateMantissa) external;
    function setReserveRateMantissa(address[] memory sources, uint224[] memory _reserveRates, bool[] memory useCustom)
        external;
    function setWithdrawStrategist(address _strategist) external;
    function transferOwnership(address newOwner) external;
    function withdrawReserve(address prizePool, address to) external returns (uint256);
    function withdrawStrategist() external view returns (address);
}
