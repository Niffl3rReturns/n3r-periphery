// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@niffl3rreturns/n3r-core/contracts/interfaces/IControlledToken.sol";

interface IStrategy {
    /**
     * @notice Emit when a strategy captures award amount from PrizePool.
     * @param totalPrizeCaptured  Total prize captured from the PrizePool
     */
    event Distributed(uint256 totalPrizeCaptured);

    /**
     * @notice Emit when an individual prize split is awarded.
     * @param user          User address being awarded
     * @param prizeAwarded  Awarded prize amount
     * @param token         Token address
     */
    event PrizeSplitAwarded(
        address indexed user,
        uint256 prizeAwarded,
        IControlledToken indexed token
    );

    /**
     * @notice Capture the award balance and distribute to prize splits.
     * @dev    Permissionless function to initialize distribution of interst
     * @return Prize captured from PrizePool
     */
    function distribute() external returns (uint256);
}
