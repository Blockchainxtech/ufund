// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC_UFUND, LifecycleState, DistributionType, DistributionStatus, DistributionInfo} from "./interfaces/IERC_UFUND.sol";

/// @notice Minimal non-production reference implementation for the uFund draft.
/// @dev Admin write functions are NON-NORMATIVE examples. The draft standardizes
/// read functions and event semantics, not admin function names/signatures.
contract UFundBase is IERC_UFUND, ERC165, AccessControl {
    bytes32 public constant FUND_ADMIN_ROLE = keccak256("FUND_ADMIN_ROLE");
    bytes32 public constant NAV_PUBLISHER_ROLE = keccak256("NAV_PUBLISHER_ROLE");

    IERC20 public immutable shareToken;

    uint256 private _nav;
    uint8 private _navDecimals;
    uint256 private _navUpdatedAt;
    uint256 private _stalenessThreshold;
    bytes3 private _currency;
    mapping(uint256 => uint256) private _historicalNav;

    LifecycleState private _state;
    LifecycleState private _stateBeforePause;
    uint256 private _stateUpdatedAt;

    uint256 private _nextDistId;
    mapping(uint256 => DistributionInfo) private _distributions;
    uint256[] private _pendingIds;
    uint256 private _lastPaidId;

    uint16 private _mgmtFeeBps;
    uint16 private _perfFeeBps;
    uint16 private _subFeeBps;
    uint16 private _redFeeBps;
    uint256 private _minInvestment;
    uint8 private _minInvestmentDecimals;
    uint256 private _subOpensAt;
    uint256 private _subClosesAt;
    uint256 private _redOpensAt;
    uint256 private _redClosesAt;
    uint256 private _maturityDate;

    constructor(IERC20 shareToken_, bytes3 currency_, uint256 stalenessThreshold_, address admin) {
        require(address(shareToken_) != address(0), "uFund: share token zero");
        require(admin != address(0), "uFund: admin zero");

        shareToken = shareToken_;
        _currency = currency_;
        _stalenessThreshold = stalenessThreshold_;
        _state = LifecycleState.Pending;
        _stateUpdatedAt = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FUND_ADMIN_ROLE, admin);
        _grantRole(NAV_PUBLISHER_ROLE, admin);
    }

    function navPerShare() external view returns (uint256, uint8) {
        return (_nav, _navDecimals);
    }

    function navAsOf(uint256 timestamp) external view returns (uint256, uint8) {
        uint256 v = _historicalNav[timestamp];
        require(v != 0, "uFund: no historical NAV");
        return (v, _navDecimals);
    }

    function navUpdatedAt() external view returns (uint256) { return _navUpdatedAt; }

    function navStale() external view returns (bool) {
        return _navUpdatedAt == 0 || block.timestamp > _navUpdatedAt + _stalenessThreshold;
    }

    function navStalenessThreshold() external view returns (uint256) { return _stalenessThreshold; }
    function valuationCurrency() external view returns (bytes3) { return _currency; }

    function lifecycleState() external view returns (LifecycleState) { return _state; }
    function lifecycleStateUpdatedAt() external view returns (uint256) { return _stateUpdatedAt; }

    function pendingDistributions() external view returns (DistributionInfo[] memory out) {
        out = new DistributionInfo[](_pendingIds.length);
        for (uint256 i = 0; i < _pendingIds.length; ++i) {
            out[i] = _distributions[_pendingIds[i]];
        }
    }

    function lastDistribution() external view returns (DistributionInfo memory) {
        require(_lastPaidId != 0, "uFund: no paid distribution");
        return _distributions[_lastPaidId];
    }

    function nextDistributionDate() external view returns (uint256) {
        uint256 next;
        for (uint256 i = 0; i < _pendingIds.length; ++i) {
            uint256 p = _distributions[_pendingIds[i]].paymentDate;
            if (next == 0 || p < next) next = p;
        }
        return next;
    }

    function managementFeeBps() external view returns (uint16) { return _mgmtFeeBps; }
    function performanceFeeBps() external view returns (uint16) { return _perfFeeBps; }
    function subscriptionFeeBps() external view returns (uint16) { return _subFeeBps; }
    function redemptionFeeBps() external view returns (uint16) { return _redFeeBps; }
    function minInvestment() external view returns (uint256, uint8) { return (_minInvestment, _minInvestmentDecimals); }
    function subscriptionWindow() external view returns (uint256, uint256) { return (_subOpensAt, _subClosesAt); }
    function redemptionWindow() external view returns (uint256, uint256) { return (_redOpensAt, _redClosesAt); }
    function maturityDate() external view returns (uint256) { return _maturityDate; }

    function setNav(uint256 nav_, uint8 decimals_, uint256 timestamp_) external onlyRole(NAV_PUBLISHER_ROLE) {
        require(timestamp_ <= block.timestamp, "uFund: future NAV");
        require(_state != LifecycleState.Closed, "uFund: closed");
        if (nav_ == _nav && decimals_ == _navDecimals && timestamp_ == _navUpdatedAt) return;

        uint256 prev = _nav;
        _nav = nav_;
        _navDecimals = decimals_;
        _navUpdatedAt = timestamp_;
        _historicalNav[timestamp_] = nav_;

        emit NavUpdated(prev, nav_, decimals_, timestamp_);
    }

    function setLifecycleState(LifecycleState newState) external onlyRole(FUND_ADMIN_ROLE) {
        require(newState != _state, "uFund: no-op transition");
        require(_isLegalTransition(_state, newState), "uFund: illegal transition");

        LifecycleState prev = _state;
        if (newState == LifecycleState.Paused) _stateBeforePause = prev;
        _state = newState;
        _stateUpdatedAt = block.timestamp;

        emit LifecycleStateChanged(prev, newState, block.timestamp);
    }

    function declareDistribution(
        uint256 exDate,
        uint256 recordDate,
        uint256 paymentDate,
        uint256 amountPerShare,
        uint8 amountDecimals,
        bytes3 currency,
        DistributionType distributionType
    ) external onlyRole(FUND_ADMIN_ROLE) returns (uint256 id) {
        require(exDate <= recordDate && recordDate <= paymentDate, "uFund: bad dates");

        id = ++_nextDistId;
        _distributions[id] = DistributionInfo({
            id: id,
            declaredAt: block.timestamp,
            exDate: exDate,
            recordDate: recordDate,
            paymentDate: paymentDate,
            amountPerShare: amountPerShare,
            amountDecimals: amountDecimals,
            currency: currency,
            distributionType: distributionType,
            status: DistributionStatus.Declared
        });
        _pendingIds.push(id);

        emit DistributionDeclared(id, distributionType, exDate, recordDate, paymentDate, amountPerShare, currency);
    }

    function supportsInterface(bytes4 id) public view virtual override(ERC165, AccessControl, IERC165) returns (bool) {
        return id == type(IERC_UFUND).interfaceId || super.supportsInterface(id);
    }

    function _isLegalTransition(LifecycleState from, LifecycleState to) internal view returns (bool) {
        if (from == LifecycleState.Closed) return false;
        if (to == LifecycleState.Paused) return from != LifecycleState.Closed;
        if (from == LifecycleState.Paused) return to == _stateBeforePause || _isLegalTransitionFromState(_stateBeforePause, to);
        return _isLegalTransitionFromState(from, to);
    }

    function _isLegalTransitionFromState(LifecycleState f, LifecycleState t) internal pure returns (bool) {
        if (f == LifecycleState.Pending) return t == LifecycleState.SubscriptionOpen;
        if (f == LifecycleState.SubscriptionOpen) return t == LifecycleState.SubscriptionClosed || t == LifecycleState.Operating;
        if (f == LifecycleState.SubscriptionClosed) return t == LifecycleState.SubscriptionOpen || t == LifecycleState.Operating || t == LifecycleState.RedemptionOnly || t == LifecycleState.WindingDown;
        if (f == LifecycleState.Operating) return t == LifecycleState.SubscriptionOpen || t == LifecycleState.SubscriptionClosed || t == LifecycleState.RedemptionOnly || t == LifecycleState.WindingDown;
        if (f == LifecycleState.RedemptionOnly) return t == LifecycleState.Operating || t == LifecycleState.WindingDown;
        if (f == LifecycleState.WindingDown) return t == LifecycleState.RedemptionOnly || t == LifecycleState.Closed;
        return false;
    }
}
