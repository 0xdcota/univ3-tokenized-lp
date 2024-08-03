// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

/// @title PriceFeed Adapter Contract
abstract contract PriceFeedAdapter is IPriceFeed {
    /// @notice Token price feed
    IPriceFeed public immutable priceFeed;
    uint256 public immutable heartbeat;
    /// @notice How late since heartbeat before a price reverts
    uint256 public constant HEART_BEAT_TOLERANCE = 300;

    error AddressZero();
    error RoundNotComplete();
    error StalePrice();
    error InvalidPrice();

    /**
     * @notice constructor
     * @param _priceFeed price feed for token compliant to IPriceFeed.
     * @param _heartbeat heartbeat for feed
     */
    constructor(address _priceFeed, uint256 _heartbeat) {
        if (_priceFeed == address(0)) revert AddressZero();
        priceFeed = IPriceFeed(_priceFeed);
        heartbeat = _heartbeat;
    }

    /// @inheritdoc IPriceFeed
    function latestAnswer() external view virtual returns (int256 price);

    /// @inheritdoc IPriceFeed
    function latestRoundData()
        external
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function validate(int256 _answer, uint256 _updatedAt) public view {
        if (_updatedAt == 0) revert RoundNotComplete();
        if (heartbeat > 0 && block.timestamp - _updatedAt >= heartbeat + HEART_BEAT_TOLERANCE) revert StalePrice();
        if (_answer <= 0) revert InvalidPrice();
    }

    /// @inheritdoc IPriceFeed
    function version() external view returns (uint256) {
        return priceFeed.version();
    }

    /// @inheritdoc IPriceFeed
    function decimals() external view returns (uint8) {
        return priceFeed.decimals();
    }

    /// @inheritdoc IPriceFeed
    function description() external view returns (string memory) {
        return priceFeed.description();
    }

    /// @inheritdoc IPriceFeed
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.getRoundData(_roundId);
    }

    /// @inheritdoc IPriceFeed
    function latestRound() external view override returns (uint256) {
        return priceFeed.latestRound();
    }
}
