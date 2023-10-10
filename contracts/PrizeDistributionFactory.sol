// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.6;

import "@niffl3rreturns/n3r-core/contracts/interfaces/ITicket.sol";
import "@niffl3rreturns/n3r-core/contracts/interfaces/IPrizeDistributionBuffer.sol";
import "@niffl3rreturns/n3r-core/contracts/interfaces/IPrizeDistributionSource.sol";
import "@niffl3rreturns/owner-manager-contracts/contracts/Manageable.sol";
import "./interfaces/IPrizeTierHistory.sol";

/**
 * @title Prize Distribution Factory
 * @author PoolTogether Inc.
 * @notice The Prize Distribution Factory populates a Prize Distribution Buffer for a prize pool.  It uses a Prize Tier History, Draw Buffer and Ticket
 * to compute the correct prize distribution.  It automatically sets the cardinality based on the minPickCost and the total network ticket supply.
 */
contract PrizeDistributionFactory is Manageable {
    using ExtendedSafeCastLib for uint256;

    /// @notice Emitted when a new Prize Distribution is pushed.
    /// @param drawId The draw id for which the prize dist was pushed
    event PrizeDistributionPushed(uint32 indexed drawId);

    /// @notice Emitted when a Prize Distribution is set (overrides another)
    /// @param drawId The draw id for which the prize dist was set
    event PrizeDistributionSet(uint32 indexed drawId);

    /// @notice The prize tier history to pull tier information from
    IPrizeTierHistory public immutable prizeTierHistory;

    /// @notice The draw buffer to pull the draw from
    IDrawBuffer public immutable drawBuffer;

    /// @notice The prize distribution buffer to push and set.  This contract must be the manager or owner of the buffer.
    IPrizeDistributionBuffer public immutable prizeDistributionBuffer;

    /// @notice The ticket whose average total supply will be measured to calculate the portion of picks
    ITicket public immutable ticket;

    /// @notice The minimum cost of each pick.  Used to calculate the cardinality.
    uint256 public immutable minPickCost;

    constructor(
        address _owner,
        IPrizeTierHistory _prizeTierHistory,
        IDrawBuffer _drawBuffer,
        IPrizeDistributionBuffer _prizeDistributionBuffer,
        ITicket _ticket,
        uint256 _minPickCost
    ) Ownable(_owner) {
        require(_owner != address(0), "PDC/owner-zero");
        require(address(_prizeTierHistory) != address(0), "PDC/pth-zero");
        require(address(_drawBuffer) != address(0), "PDC/db-zero");
        require(address(_prizeDistributionBuffer) != address(0), "PDC/pdb-zero");
        require(address(_ticket) != address(0), "PDC/ticket-zero");
        require(_minPickCost > 0, "PDC/pick-cost-gt-zero");

        minPickCost = _minPickCost;
        prizeTierHistory = _prizeTierHistory;
        drawBuffer = _drawBuffer;
        prizeDistributionBuffer = _prizeDistributionBuffer;
        ticket = _ticket;
    }

    /**
     * @notice Allows the owner or manager to push a new prize distribution onto the buffer.
     * The PrizeTier and Draw for the given draw id will be pulled in, and the total network ticket supply will be used to calculate cardinality.
     * @param _drawId The draw id to compute for
     * @return The resulting Prize Distribution
     */
    function pushPrizeDistribution(
        uint32 _drawId
    ) external onlyManagerOrOwner returns (IPrizeDistributionBuffer.PrizeDistribution memory) {
        IPrizeDistributionBuffer.PrizeDistribution
            memory prizeDistribution = calculatePrizeDistribution(_drawId);

        prizeDistributionBuffer.pushPrizeDistribution(_drawId, prizeDistribution);

        emit PrizeDistributionPushed(_drawId);

        return prizeDistribution;
    }

    /**
     * @notice Allows the owner or manager to override an existing prize distribution in the buffer.
     * The PrizeTier and Draw for the given draw id will be pulled in, and the total network ticket supply will be used to calculate cardinality.
     * @param _drawId The draw id to compute for
     * @return The resulting Prize Distribution
     */
    function setPrizeDistribution(
        uint32 _drawId
    ) external onlyOwner returns (IPrizeDistributionBuffer.PrizeDistribution memory) {
        IPrizeDistributionBuffer.PrizeDistribution
            memory prizeDistribution = calculatePrizeDistribution(_drawId);

        prizeDistributionBuffer.setPrizeDistribution(_drawId, prizeDistribution);

        emit PrizeDistributionSet(_drawId);

        return prizeDistribution;
    }

    /**
     * @notice Calculates what the prize distribution will be, given a draw id and total network ticket supply.
     * @param _drawId The draw id to pull from the Draw Buffer and Prize Tier History
     * @return PrizeDistribution using info from the Draw for the given draw id, total network ticket supply, and PrizeTier for the draw.
     */
    function calculatePrizeDistribution(
        uint32 _drawId
    ) public view virtual returns (IPrizeDistributionBuffer.PrizeDistribution memory) {
        IDrawBeacon.Draw memory draw = drawBuffer.getDraw(_drawId);
        IPrizeTierHistory.PrizeTier memory prizeTier = prizeTierHistory.getPrizeTier(_drawId);

        (
            uint64[] memory startTimes,
            uint64[] memory endTimes
        ) = _calculateDrawPeriodTimestampOffsets(
                draw.timestamp,
                draw.beaconPeriodSeconds,
                prizeTier.endTimestampOffset
            );

        uint256 totalTicketSupply = ticket.getAverageTotalSuppliesBetween(startTimes, endTimes)[0];
        uint256 maxPicks = totalTicketSupply / minPickCost;
        return _calculatePrizeDistribution(_drawId, draw.beaconPeriodSeconds, maxPicks);
    }

    /**
     * @notice Gets the PrizeDistributionBuffer for a drawId
     * @param _drawId drawId
     * @param _startTimestampOffset The start timestamp offset to use for the prize distribution
     * @param _maxPicks The maximum picks that the distribution should allow.  The Prize Distribution's numberOfPicks will be less than or equal to this number.
     * @return prizeDistribution
     */
    function _calculatePrizeDistribution(
        uint32 _drawId,
        uint32 _startTimestampOffset,
        uint256 _maxPicks
    ) internal view virtual returns (IPrizeDistributionBuffer.PrizeDistribution memory) {
        IPrizeTierHistory.PrizeTier memory prizeTier = prizeTierHistory.getPrizeTier(_drawId);

        uint8 cardinality;
        do {
            cardinality++;
        } while ((2 ** prizeTier.bitRangeSize) ** (cardinality + 1) < _maxPicks);

        IPrizeDistributionBuffer.PrizeDistribution
            memory prizeDistribution = IPrizeDistributionSource.PrizeDistribution({
                bitRangeSize: prizeTier.bitRangeSize,
                matchCardinality: cardinality,
                startTimestampOffset: _startTimestampOffset,
                endTimestampOffset: prizeTier.endTimestampOffset,
                maxPicksPerUser: prizeTier.maxPicksPerUser,
                expiryDuration: prizeTier.expiryDuration,
                numberOfPicks: uint256((2 ** prizeTier.bitRangeSize) ** cardinality).toUint104(),
                tiers: prizeTier.tiers,
                prize: prizeTier.prize
            });

        return prizeDistribution;
    }

    /**
     * @notice Calculate Draw period start and end timestamp.
     * @param _timestamp Timestamp at which the draw was created by the DrawBeacon
     * @param _startOffset Draw start time offset in seconds
     * @param _endOffset Draw end time offset in seconds
     * @return Draw start and end timestamp
     */
    function _calculateDrawPeriodTimestampOffsets(
        uint64 _timestamp,
        uint32 _startOffset,
        uint32 _endOffset
    ) internal pure returns (uint64[] memory, uint64[] memory) {
        uint64[] memory _startTimestamps = new uint64[](1);
        uint64[] memory _endTimestamps = new uint64[](1);

        _startTimestamps[0] = _timestamp - _startOffset;
        _endTimestamps[0] = _timestamp - _endOffset;

        return (_startTimestamps, _endTimestamps);
    }
}
