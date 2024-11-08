// Get funds from users
// Withdraw funds
// Set a minimum funding value in USD

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

error FundMe_NotOwner();
error FundMe_NotEnoughETH(uint256 sent, uint256 required);
error FundMe_CallFailed();

contract FundMe {
    using PriceConverter for uint256;

    mapping(address => uint256) private s_addressToAmountFunded;
    address[] private s_funders;

    address private immutable I_OWNER;
    uint256 public constant MINIMUM_USD = 50e18; // 50 * 10 ** 18
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed) {
        I_OWNER = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        // require(
        //     msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
        //     "You need to spend more ETH!"
        // );
        if (msg.value.getConversionRate(s_priceFeed) < MINIMUM_USD) {
            revert FundMe_NotEnoughETH({
                sent: msg.value.getConversionRate(s_priceFeed),
                required: MINIMUM_USD
            });
        }

        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != I_OWNER) revert FundMe_NotOwner();
        _;
    }

    function withdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;
        // loading from memory instead of loading from storage for saving gas
        for (
            uint256 funderIndex = 0;
            funderIndex < fundersLength;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // transfer
        // payable(msg.sender).transfer(address(this).balance);

        // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");

        // call
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!callSuccess) {
            revert FundMe_CallFailed();
        }
    }

    // Ether is sent to contract
    //      is msg.data empty?
    //          /   \
    //         yes  no
    //         /     \
    //    receive()?  fallback()
    //     /   \
    //   yes   no
    //  /        \
    //receive()  fallback()

    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }

    // view/pure function (Getter)
    function getPriceFeed() external view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    function getVersion() external view returns (uint256) {
        // ETH/USD price feed address.
        return s_priceFeed.version();
    }

    function getOwner() external view returns (address) {
        return I_OWNER;
    }

    function getAddressToAmountFunded(
        address fundingAddress
    ) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getFundersQuantity() external view returns (uint256) {
        return s_funders.length;
    }
}
