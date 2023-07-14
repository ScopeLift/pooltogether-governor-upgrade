//
pragma solidity ^0.8.18;

interface ICompoundPrizePool {
    event AwardCaptured(uint256 amount);
    event Awarded(address indexed winner, address indexed token, uint256 amount);
    event AwardedExternalERC20(address indexed winner, address indexed token, uint256 amount);
    event AwardedExternalERC721(address indexed winner, address indexed token, uint256[] tokenIds);
    event CompoundPrizePoolInitialized(address indexed cToken);
    event ControlledTokenAdded(address indexed token);
    event CreditBurned(address indexed user, address indexed token, uint256 amount);
    event CreditMinted(address indexed user, address indexed token, uint256 amount);
    event CreditPlanSet(address token, uint128 creditLimitMantissa, uint128 creditRateMantissa);
    event Deposited(
        address indexed operator, address indexed to, address indexed token, uint256 amount, address referrer
    );
    event Initialized(address reserveRegistry, uint256 maxExitFeeMantissa, uint256 maxTimelockDuration);
    event InstantWithdrawal(
        address indexed operator,
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 redeemed,
        uint256 exitFee
    );
    event LiquidityCapSet(uint256 liquidityCap);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PrizeStrategySet(address indexed prizeStrategy);
    event ReserveFeeCaptured(uint256 amount);
    event ReserveWithdrawal(address indexed to, uint256 amount);
    event TimelockDeposited(address indexed operator, address indexed to, address indexed token, uint256 amount);
    event TimelockedWithdrawal(
        address indexed operator, address indexed from, address indexed token, uint256 amount, uint256 unlockTimestamp
    );
    event TimelockedWithdrawalSwept(address indexed operator, address indexed from, uint256 amount, uint256 redeemed);
    event TransferredExternalERC20(address indexed to, address indexed token, uint256 amount);

    function accountedBalance() external view returns (uint256);
    function addControlledToken(address _controlledToken) external;
    function award(address to, uint256 amount, address controlledToken) external;
    function awardBalance() external view returns (uint256);
    function awardExternalERC20(address to, address externalToken, uint256 amount) external;
    function awardExternalERC721(address to, address externalToken, uint256[] memory tokenIds) external;
    function balance() external returns (uint256);
    function balanceOfCredit(address user, address controlledToken) external returns (uint256);
    function beforeTokenTransfer(address from, address to, uint256 amount) external;
    function cToken() external view returns (address);
    function calculateEarlyExitFee(address from, address controlledToken, uint256 amount)
        external
        returns (uint256 exitFee, uint256 burnedCredit);
    function calculateReserveFee(uint256 amount) external view returns (uint256);
    function calculateTimelockDuration(address from, address controlledToken, uint256 amount)
        external
        returns (uint256 durationSeconds, uint256 burnedCredit);
    function canAwardExternal(address _externalToken) external view returns (bool);
    function captureAwardBalance() external returns (uint256);
    function creditPlanOf(address controlledToken)
        external
        view
        returns (uint128 creditLimitMantissa, uint128 creditRateMantissa);
    function depositTo(address to, uint256 amount, address controlledToken, address referrer) external;
    function estimateCreditAccrualTime(address _controlledToken, uint256 _principal, uint256 _interest)
        external
        view
        returns (uint256 durationSeconds);
    function initialize(
        address _reserveRegistry,
        address[] memory _controlledTokens,
        uint256 _maxExitFeeMantissa,
        uint256 _maxTimelockDuration
    ) external;
    function initialize(
        address _reserveRegistry,
        address[] memory _controlledTokens,
        uint256 _maxExitFeeMantissa,
        uint256 _maxTimelockDuration,
        address _cToken
    ) external;
    function liquidityCap() external view returns (uint256);
    function maxExitFeeMantissa() external view returns (uint256);
    function maxTimelockDuration() external view returns (uint256);
    function owner() external view returns (address);
    function prizeStrategy() external view returns (address);
    function renounceOwnership() external;
    function reserveRegistry() external view returns (address);
    function reserveTotalSupply() external view returns (uint256);
    function setCreditPlanOf(address _controlledToken, uint128 _creditRateMantissa, uint128 _creditLimitMantissa)
        external;
    function setLiquidityCap(uint256 _liquidityCap) external;
    function setPrizeStrategy(address _prizeStrategy) external;
    function sweepTimelockBalances(address[] memory users) external returns (uint256);
    function timelockBalanceAvailableAt(address user) external view returns (uint256);
    function timelockBalanceOf(address user) external view returns (uint256);
    function timelockDepositTo(address to, uint256 amount, address controlledToken) external;
    function timelockTotalSupply() external view returns (uint256);
    function token() external view returns (address);
    function tokens() external view returns (address[] memory);
    function transferExternalERC20(address to, address externalToken, uint256 amount) external;
    function transferOwnership(address newOwner) external;
    function withdrawInstantlyFrom(address from, uint256 amount, address controlledToken, uint256 maximumExitFee)
        external
        returns (uint256);
    function withdrawReserve(address to) external returns (uint256);
    function withdrawWithTimelockFrom(address from, uint256 amount, address controlledToken)
        external
        returns (uint256);
}
