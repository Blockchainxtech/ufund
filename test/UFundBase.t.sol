// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UFundBase} from "../contracts/UFundBase.sol";
import {
    IERC_UFUND,
    IERC_UFUND_AUM,
    IERC_UFUND_Lockup,
    IERC_UFUND_Yield,
    IERC_UFUND_MultiClass,
    IERC_UFUND_ProofOfReserves,
    LifecycleState,
    DistributionType,
    DistributionStatus
} from "../contracts/interfaces/IERC_UFUND.sol";

contract MockShareToken is ERC20 {
    constructor() ERC20("Mock Fund Share", "MFS") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract UFundBaseTest is Test {
    MockShareToken token;
    UFundBase fund;
    address admin = address(0xA11CE);

    event NavUpdated(uint256 previousNav, uint256 newNav, uint8 navDecimals, uint256 effectiveAt);
    event LifecycleStateChanged(LifecycleState indexed previousState, LifecycleState indexed newState, uint256 timestamp);
    event DistributionDeclared(
        uint256 indexed id,
        DistributionType indexed distributionType,
        uint256 exDate,
        uint256 recordDate,
        uint256 paymentDate,
        uint256 amountPerShare,
        bytes3 currency
    );

    function setUp() public {
        token = new MockShareToken();
        fund = new UFundBase(token, bytes3("USD"), 1 days, admin);
    }

function testInterfaceId() public view {
    console2.log("IERC_UFUND");
    console2.logBytes4(type(IERC_UFUND).interfaceId);

    console2.log("IERC_UFUND_AUM");
    console2.logBytes4(type(IERC_UFUND_AUM).interfaceId);

    console2.log("IERC_UFUND_Lockup");
    console2.logBytes4(type(IERC_UFUND_Lockup).interfaceId);

    console2.log("IERC_UFUND_Yield");
    console2.logBytes4(type(IERC_UFUND_Yield).interfaceId);

    console2.log("IERC_UFUND_MultiClass");
    console2.logBytes4(type(IERC_UFUND_MultiClass).interfaceId);

    console2.log("IERC_UFUND_ProofOfReserves");
    console2.logBytes4(type(IERC_UFUND_ProofOfReserves).interfaceId);
}

    function testSetNavEmitsEventAndUpdatesState() public {
        vm.warp(1_000_000);
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit NavUpdated(0, 1e18, 18, block.timestamp);
        fund.setNav(1e18, 18, block.timestamp);

        (uint256 nav, uint8 decimals) = fund.navPerShare();
        assertEq(nav, 1e18);
        assertEq(decimals, 18);
        assertEq(fund.navUpdatedAt(), block.timestamp);
    }

    function testSetNavNoOpDoesNotRevert() public {
        vm.warp(1_000_000);
        vm.startPrank(admin);
        fund.setNav(1e18, 18, block.timestamp);
        fund.setNav(1e18, 18, block.timestamp);
        vm.stopPrank();
    }

    function testLifecycleTransitionEmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit LifecycleStateChanged(LifecycleState.Pending, LifecycleState.SubscriptionOpen, block.timestamp);
        fund.setLifecycleState(LifecycleState.SubscriptionOpen);
        assertEq(uint8(fund.lifecycleState()), uint8(LifecycleState.SubscriptionOpen));
    }

    function testIllegalLifecycleTransitionReverts() public {
        vm.prank(admin);
        vm.expectRevert("uFund: illegal transition");
        fund.setLifecycleState(LifecycleState.Closed);
    }

    function testDeclareDistributionEmitsEvent() public {
        uint256 exDate = block.timestamp + 1 days;
        uint256 recordDate = block.timestamp + 2 days;
        uint256 paymentDate = block.timestamp + 3 days;

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit DistributionDeclared(1, DistributionType.Dividend, exDate, recordDate, paymentDate, 5e16, bytes3("USD"));
        uint256 id = fund.declareDistribution(exDate, recordDate, paymentDate, 5e16, 18, bytes3("USD"), DistributionType.Dividend);
        assertEq(id, 1);
        assertEq(fund.nextDistributionDate(), paymentDate);
    }

    function testNavStale() public {
        vm.warp(100);
        vm.prank(admin);
        fund.setNav(1e18, 18, block.timestamp);
        assertFalse(fund.navStale());
        vm.warp(100 + 2 days);
        assertTrue(fund.navStale());
    }
}
