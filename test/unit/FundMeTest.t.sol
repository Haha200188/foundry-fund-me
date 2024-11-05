// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

interface IFundMeErrors {
    error FundMe_NotOwner();
    error FundMe_NotEnoughETH(uint256 sent, uint256 required);
    error FundMe_CallFailed();
}

contract FundMeTest is Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    address public constant USER = address(1);
    uint256 public constant SEND_VALUE = 1e18;
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        DeployFundMe deployFundMe = new DeployFundMe();
        (fundMe, helperConfig) = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // send fake balance
    }

    function testPriceFeedSetCorrectly() public view {
        address retreivedPriceFeed = address(fundMe.getPriceFeed());
        address expectedPriceFeed = helperConfig.activeNetworkConfig();
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    // fund
    function testFundFailedWithoutEnoughETH() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFundMeErrors.FundMe_NotEnoughETH.selector,
                0,
                fundMe.MINIMUM_USD()
            )
        ); // the next line should revert
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // the next TX will be sent by USER
        fundMe.fund{value: SEND_VALUE}();
        uint256 ammountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(ammountFunded, SEND_VALUE);
    }

    function testFundUpdatesFunderArray() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address userAddress = fundMe.getFunder(0);
        assertEq(userAddress, USER);
    }

    // withdraw
    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testWithdrawFailedCalledByNotOwner() public funded {
        vm.expectRevert(IFundMeErrors.FundMe_NotOwner.selector);
        fundMe.withdraw();
    }

    function testWithdrawFromSingleFunder() public funded {
        // arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        // act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        // assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(fundMe.getFundersQuantity(), 0);
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        // arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < startingFunderIndex + numberOfFunders;
            i++
        ) {
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        // act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        // assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(fundMe.getFundersQuantity(), 0);
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
        assertEq(
            endingOwnerBalance - startingOwnerBalance,
            (numberOfFunders + 1) * SEND_VALUE // 1 + 10 (USER + numberOfFunders)
        );
    }
}
