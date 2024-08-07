// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IPriceFeed, PriceFeedAdapter} from "./PriceFeedAdapter.sol";

/// @title ValidatedPriceFeedAdapter Contract
contract ValidatedPriceFeedAdapter is PriceFeedAdapter {
    constructor(address _priceFeed, uint256 _heartbeat) PriceFeedAdapter(_priceFeed, _heartbeat) {}

    /// @notice Validates `answer` and `updatedAt`, it revert if invalid, otherwise returns feed `answer`.
    function latestAnswer() external view override returns (int256) {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        validate(answer, updatedAt);
        return answer;
    }

    /// @notice Validates the `getLatestRoundData` and reverts if invalid, otherwise returns feed `getLatestRoundData`
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();
        validate(answer, updatedAt);
    }
}
