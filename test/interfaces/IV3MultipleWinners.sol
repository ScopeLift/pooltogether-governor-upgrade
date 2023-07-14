pragma solidity ^0.8.18;

// Generated with cast interface for 0x3D9946190907aDa8b70381b25c71eB9adf5f9B7b
interface IV3MultipleWinners {
    event ExternalErc20AwardAdded(address indexed externalErc20);
    event ExternalErc20AwardRemoved(address indexed externalErc20Award);
    event ExternalErc721AwardAdded(address indexed externalErc721, uint256[] tokenIds);
    event ExternalErc721AwardRemoved(address indexed externalErc721Award);
    event Initialized(
        uint256 prizePeriodStart,
        uint256 prizePeriodSeconds,
        address indexed prizePool,
        address ticket,
        address sponsorship,
        address rng,
        address[] externalErc20Awards
    );
    event NoWinners();
    event NumberOfWinnersSet(uint256 numberOfWinners);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PeriodicPrizeStrategyListenerSet(address indexed periodicPrizeStrategyListener);
    event PrizePoolAwardCancelled(
        address indexed operator, address indexed prizePool, uint32 indexed rngRequestId, uint32 rngLockBlock
    );
    event PrizePoolAwardStarted(
        address indexed operator, address indexed prizePool, uint32 indexed rngRequestId, uint32 rngLockBlock
    );
    event PrizePoolAwarded(address indexed operator, uint256 randomNumber);
    event PrizePoolOpened(address indexed operator, uint256 indexed prizePeriodStartedAt);
    event RngRequestFailed();
    event RngRequestTimeoutSet(uint32 rngRequestTimeout);
    event RngServiceUpdated(address indexed rngService);
    event SplitExternalErc20AwardsSet(bool splitExternalErc20Awards);
    event TokenListenerUpdated(address indexed tokenListener);

    function addExternalErc20Award(address _externalErc20) external;
    function addExternalErc20Awards(address[] memory _externalErc20s) external;
    function addExternalErc721Award(address _externalErc721, uint256[] memory _tokenIds) external;
    function beforeTokenMint(address to, uint256 amount, address controlledToken, address referrer) external;
    function beforeTokenTransfer(address from, address to, uint256 amount, address controlledToken) external;
    function calculateNextPrizePeriodStartTime(uint256 currentTime) external view returns (uint256);
    function canCompleteAward() external view returns (bool);
    function canStartAward() external view returns (bool);
    function cancelAward() external;
    function completeAward() external;
    function currentPrize() external view returns (uint256);
    function estimateRemainingBlocksToPrize(uint256 secondsPerBlockMantissa) external view returns (uint256);
    function getExternalErc20Awards() external view returns (address[] memory);
    function getExternalErc721AwardTokenIds(address _externalErc721) external view returns (uint256[] memory);
    function getExternalErc721Awards() external view returns (address[] memory);
    function getLastRngLockBlock() external view returns (uint32);
    function getLastRngRequestId() external view returns (uint32);
    function initialize(
        uint256 _prizePeriodStart,
        uint256 _prizePeriodSeconds,
        address _prizePool,
        address _ticket,
        address _sponsorship,
        address _rng,
        address[] memory externalErc20Awards
    ) external;
    function initializeMultipleWinners(
        uint256 _prizePeriodStart,
        uint256 _prizePeriodSeconds,
        address _prizePool,
        address _ticket,
        address _sponsorship,
        address _rng,
        uint256 _numberOfWinners
    ) external;
    function isPrizePeriodOver() external view returns (bool);
    function isRngCompleted() external view returns (bool);
    function isRngRequested() external view returns (bool);
    function isRngTimedOut() external view returns (bool);
    function numberOfWinners() external view returns (uint256);
    function owner() external view returns (address);
    function periodicPrizeStrategyListener() external view returns (address);
    function prizePeriodEndAt() external view returns (uint256);
    function prizePeriodRemainingSeconds() external view returns (uint256);
    function prizePeriodSeconds() external view returns (uint256);
    function prizePeriodStartedAt() external view returns (uint256);
    function prizePool() external view returns (address);
    function removeExternalErc20Award(address _externalErc20, address _prevExternalErc20) external;
    function removeExternalErc721Award(address _externalErc721, address _prevExternalErc721) external;
    function renounceOwnership() external;
    function rng() external view returns (address);
    function rngRequestTimeout() external view returns (uint32);
    function setNumberOfWinners(uint256 count) external;
    function setPeriodicPrizeStrategyListener(address _periodicPrizeStrategyListener) external;
    function setRngRequestTimeout(uint32 _rngRequestTimeout) external;
    function setRngService(address rngService) external;
    function setSplitExternalErc20Awards(bool _splitExternalErc20Awards) external;
    function setTokenListener(address _tokenListener) external;
    function splitExternalErc20Awards() external view returns (bool);
    function sponsorship() external view returns (address);
    function startAward() external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function ticket() external view returns (address);
    function tokenListener() external view returns (address);
    function transferExternalERC20(address to, address externalToken, uint256 amount) external;
    function transferOwnership(address newOwner) external;
}
