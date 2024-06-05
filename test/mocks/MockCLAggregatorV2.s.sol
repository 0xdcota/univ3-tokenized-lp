// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IPriceFeed} from "../../src/interfaces/IPriceFeed.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockCLAggregatorV2 is Ownable {
    event SetReferenceAggregator(address newRefAggregator);
    event SetAuthorizedCaller(address caller, bool isAuthorized);
    event PriceOverriden(int256 price);
    event UpdatedAtOverriden(uint256 updatedAt);

    uint256 public constant DEFAULT_DECIMALS = 8;

    IPriceFeed public referenceAggregator;
    int256 public overridenPrice;
    uint256 public overridenUpdatedAt;
    mapping(address => bool) public authorizedCallers;

    modifier isAuthorized() {
        require(authorizedCallers[msg.sender], "Unauthorized caller");
        _;
    }

    constructor(address refAggregator) Ownable(msg.sender) {
        if (refAggregator != address(0)) {
            referenceAggregator = IPriceFeed(refAggregator);
            emit SetReferenceAggregator(refAggregator);
        }
        authorizedCallers[msg.sender] = true;
        emit SetAuthorizedCaller(msg.sender, true);
    }

    function setReferenceAggregator(address refAggregator) external isAuthorized {
        referenceAggregator = IPriceFeed(refAggregator);
        emit SetReferenceAggregator(refAggregator);
    }

    function setAuthorizedCaller(address caller, bool setAuthorized) external onlyOwner {
        authorizedCallers[caller] = setAuthorized;
        emit SetAuthorizedCaller(caller, setAuthorized);
    }

    function setPrice(int256 _price) external isAuthorized {
        overridenPrice = _price;
        emit PriceOverriden(_price);
    }

    function setUpdatedAt(uint256 _updatedAt) external isAuthorized {
        overridenUpdatedAt = _updatedAt;
        emit UpdatedAtOverriden(_updatedAt);
    }

    function latestAnswer() external view returns (int256) {
        if (overridenPrice != 0) {
            return overridenPrice;
        }
        if (address(referenceAggregator) == address(0)) {
            return 0;
        }
        return referenceAggregator.latestAnswer();
    }

    function decimals() external view returns (uint256) {
        if (address(referenceAggregator) == address(0)) {
            return DEFAULT_DECIMALS;
        }
        return referenceAggregator.decimals();
    }

    function description() external view returns (string memory) {
        if (address(referenceAggregator) == address(0)) {
            return "MockCLAggregatorV2";
        }
        return referenceAggregator.description();
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (address(referenceAggregator) != address(0)) {
            (roundId, answer, startedAt, updatedAt, answeredInRound) = referenceAggregator.latestRoundData();
        }
        if (overridenPrice != 0) {
            answer = overridenPrice;
        }
        if (overridenUpdatedAt != 0) {
            updatedAt = overridenUpdatedAt;
        }
    }
}
