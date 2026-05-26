// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/*//////////////////////////////////////////////////////////////
                            ENUMS
//////////////////////////////////////////////////////////////*/

/// @notice Lifecycle states of a tokenized fund.
enum LifecycleState {
    Pending, // 0 - fund deployed, not yet open
    SubscriptionOpen, // 1 - accepting new subscriptions
    SubscriptionClosed, // 2 - subscriptions closed, redemptions may or may not be open
    Operating, // 3 - steady state
    RedemptionOnly, // 4 - subscriptions disabled, redemptions enabled
    WindingDown, // 5 - subscriptions and redemptions disabled; assets being liquidated
    Closed, // 6 - terminal state
    Paused // 7 - administrative halt
}

enum DistributionType {
    Dividend,
    Coupon,
    ReturnOfCapital,
    Other
}

enum DistributionStatus {
    Declared,
    ExDate,
    Paid,
    Cancelled
}

/*//////////////////////////////////////////////////////////////
                            STRUCTS
//////////////////////////////////////////////////////////////*/

struct DistributionInfo {
    uint256 id;
    uint256 declaredAt;
    uint256 exDate;
    uint256 recordDate;
    uint256 paymentDate;
    uint256 amountPerShare;
    uint8 amountDecimals;
    bytes3 currency;
    DistributionType distributionType;
    DistributionStatus status;
}

struct ShareClassInfo {
    bytes32 id;
    string name;
    string symbol;
    uint256 minInvestment;
    uint8 minInvestmentDecimals;
    bytes eligibility;
}

struct AttestationInfo {
    bytes32 attestationHash;
    string attestationURI;
    uint256 attestedAt;
    address[] attestors;
    uint16 reservesToSupplyBps;
    string methodologyURI;
}

/*//////////////////////////////////////////////////////////////
                        CORE INTERFACE
//////////////////////////////////////////////////////////////*/

interface IERC_UFUND is IERC165 {
    /*//////////////////////////////////////////////////////////////
                                NAV READS
    //////////////////////////////////////////////////////////////*/

    /// @notice Current NAV per share of the default share class.
    /// @return nav NAV per share, scaled by navDecimals.
    /// @return navDecimals Decimal precision of nav.
    function navPerShare() external view returns (uint256 nav, uint8 navDecimals);

    /// @notice NAV per share at or immediately before timestamp.
    /// @dev MAY revert if historical NAV is not stored.
    function navAsOf(uint256 timestamp)
        external
        view
        returns (uint256 nav, uint8 navDecimals);

    /// @notice Timestamp at which current NAV was last updated.
    function navUpdatedAt() external view returns (uint256 timestamp);

    /// @notice True if current NAV is older than navStalenessThreshold().
    function navStale() external view returns (bool);

    /// @notice Maximum NAV age in seconds before it is considered stale.
    function navStalenessThreshold() external view returns (uint256);

    /// @notice ISO 4217 alpha-3 valuation currency, e.g. USD as bytes3.
    function valuationCurrency() external view returns (bytes3);

    /*//////////////////////////////////////////////////////////////
                            LIFECYCLE READS
    //////////////////////////////////////////////////////////////*/

    function lifecycleState() external view returns (LifecycleState);

    function lifecycleStateUpdatedAt() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            DISTRIBUTION READS
    //////////////////////////////////////////////////////////////*/

    function pendingDistributions()
        external
        view
        returns (DistributionInfo[] memory);

    function lastDistribution()
        external
        view
        returns (DistributionInfo memory);

    function nextDistributionDate() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            BASIC FUND PARAMS
    //////////////////////////////////////////////////////////////*/

    function managementFeeBps() external view returns (uint16);

    function performanceFeeBps() external view returns (uint16);

    function subscriptionFeeBps() external view returns (uint16);

    function redemptionFeeBps() external view returns (uint16);

    function minInvestment()
        external
        view
        returns (uint256 amount, uint8 decimals);

    function subscriptionWindow()
        external
        view
        returns (uint256 opensAt, uint256 closesAt);

    function redemptionWindow()
        external
        view
        returns (uint256 opensAt, uint256 closesAt);

    /// @notice Fixed maturity date. MUST return 0 if fund has no fixed maturity.
    function maturityDate() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            REQUIRED EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted whenever navPerShare() changes.
    event NavUpdated(
        uint256 previousNav,
        uint256 newNav,
        uint8 navDecimals,
        uint256 effectiveAt
    );

    /// @notice Emitted whenever lifecycleState() changes.
    event LifecycleStateChanged(
        LifecycleState indexed previousState,
        LifecycleState indexed newState,
        uint256 timestamp
    );

    /// @notice Emitted when a distribution is declared.
    event DistributionDeclared(
        uint256 indexed id,
        DistributionType indexed distributionType,
        uint256 exDate,
        uint256 recordDate,
        uint256 paymentDate,
        uint256 amountPerShare,
        bytes3 currency
    );

    /// @notice Emitted when a declared distribution is paid.
    event DistributionPaid(
        uint256 indexed id,
        uint256 totalAmount,
        uint256 paidAt
    );

    /// @notice Emitted when a declared distribution is cancelled.
    event DistributionCancelled(
        uint256 indexed id,
        string reason
    );
}

/*//////////////////////////////////////////////////////////////
                    OPTIONAL AUM EXTENSION
//////////////////////////////////////////////////////////////*/

interface IERC_UFUND_AUM is IERC_UFUND {
    function aum() external view returns (uint256 amount, uint8 decimals);

    function aumUpdatedAt() external view returns (uint256 timestamp);

    event AUMUpdated(
        uint256 previousAum,
        uint256 newAum,
        uint8 decimals,
        uint256 effectiveAt
    );
}

/*//////////////////////////////////////////////////////////////
                    OPTIONAL LOCKUP EXTENSION
//////////////////////////////////////////////////////////////*/

interface IERC_UFUND_Lockup is IERC_UFUND {
    function lockupExpires(address account)
        external
        view
        returns (uint256 timestamp);
}

/*//////////////////////////////////////////////////////////////
                    OPTIONAL YIELD EXTENSION
//////////////////////////////////////////////////////////////*/

interface IERC_UFUND_Yield is IERC_UFUND {
    function accruedYield(address account)
        external
        view
        returns (uint256 amount);
}

/*//////////////////////////////////////////////////////////////
                    OPTIONAL MULTI-CLASS EXTENSION
//////////////////////////////////////////////////////////////*/

interface IERC_UFUND_MultiClass is IERC_UFUND {
    function shareClasses() external view returns (bytes32[] memory);

    function defaultShareClass() external view returns (bytes32);

    function shareClassInfo(bytes32 shareClassId)
        external
        view
        returns (ShareClassInfo memory);

    function navPerShare(bytes32 shareClassId)
        external
        view
        returns (uint256 nav, uint8 navDecimals);

    function navAsOf(bytes32 shareClassId, uint256 timestamp)
        external
        view
        returns (uint256 nav, uint8 navDecimals);

    function lifecycleState(bytes32 shareClassId)
        external
        view
        returns (LifecycleState);

    function managementFeeBps(bytes32 shareClassId)
        external
        view
        returns (uint16);

    function performanceFeeBps(bytes32 shareClassId)
        external
        view
        returns (uint16);

    function subscriptionFeeBps(bytes32 shareClassId)
        external
        view
        returns (uint16);

    function redemptionFeeBps(bytes32 shareClassId)
        external
        view
        returns (uint16);

    function minInvestment(bytes32 shareClassId)
        external
        view
        returns (uint256 amount, uint8 decimals);

    function pendingDistributions(bytes32 shareClassId)
        external
        view
        returns (DistributionInfo[] memory);

    /// @notice Emitted whenever a new share class is added.
    event ShareClassAdded(
        bytes32 indexed id,
        string name,
        string symbol
    );

    /// @notice Share-class-scoped NAV update event.
    event NavUpdated(
        bytes32 indexed shareClassId,
        uint256 previousNav,
        uint256 newNav,
        uint8 navDecimals,
        uint256 effectiveAt
    );

    /// @notice Share-class-scoped lifecycle event.
    event LifecycleStateChanged(
        bytes32 indexed shareClassId,
        LifecycleState indexed previousState,
        LifecycleState indexed newState,
        uint256 timestamp
    );

    /// @notice Share-class-scoped distribution declaration event.
    event DistributionDeclared(
        bytes32 indexed shareClassId,
        uint256 indexed id,
        DistributionType indexed distributionType,
        uint256 exDate,
        uint256 recordDate,
        uint256 paymentDate,
        uint256 amountPerShare,
        bytes3 currency
    );

    /// @notice Share-class-scoped distribution payment event.
    event DistributionPaid(
        bytes32 indexed shareClassId,
        uint256 indexed id,
        uint256 totalAmount,
        uint256 paidAt
    );

    /// @notice Share-class-scoped distribution cancellation event.
    event DistributionCancelled(
        bytes32 indexed shareClassId,
        uint256 indexed id,
        string reason
    );
}

/*//////////////////////////////////////////////////////////////
                OPTIONAL PROOF-OF-RESERVES EXTENSION
//////////////////////////////////////////////////////////////*/

interface IERC_UFUND_ProofOfReserves is IERC_UFUND {
    function latestAttestation()
        external
        view
        returns (AttestationInfo memory);

    function attestationHistory(uint256 fromTimestamp)
        external
        view
        returns (AttestationInfo[] memory);

    event AttestationPublished(
        bytes32 indexed attestationHash,
        uint256 attestedAt,
        uint16 reservesToSupplyBps,
        string attestationURI
    );
}