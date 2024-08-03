// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IPriceFeed, PriceFeedAdapter} from "./PriceFeedAdapter.sol";

/// @title ValidatedPriceFeedAdatperWithSequencer Contract
contract ValidatedPriceFeedAdapterWithSequencer is PriceFeedAdapter {
    IPriceFeed public sequencerUptimeFeed;
    uint256 public constant GRACE_PERIOD_TIME = 3600;
    uint256 public constant UPDATE_PERIOD = 86400;

    error SequencerDown();
    error InvalidSequencerRound();
    error GracePeriodNotOver();

    constructor(address _priceFeed, uint256 _heartbeat, address _sequencerFeed)
        PriceFeedAdapter(_priceFeed, _heartbeat)
    {
        if (_sequencerFeed == address(0)) revert AddressZero();
        sequencerUptimeFeed = IPriceFeed(_sequencerFeed);
    }

    /**
     * @notice Check the sequencer status for the Arbitrum mainnet.
     */
    function checkSequencerFeed() public view {
        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        if (startedAt == 0) {
            revert InvalidSequencerRound();
        }

        // Make sure the grace period has passed after the sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }
    }

    /// @notice Validates `answer` and `updatedAt`, it revert if invalid, otherwise returns feed `answer`.
    function latestAnswer() external view override returns (int256) {
        checkSequencerFeed();
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
        checkSequencerFeed();
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();
        validate(answer, updatedAt);
    }
}
