// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "./ICrossChainRelayer.sol";

/**
 * @title CrossChainExecutor interface
 * @notice CrossChainExecutor interface of the ERC-5164 standard as defined in the EIP.
 */
interface ICrossChainExecutor {
    /**
     * @notice Emitted when calls have successfully been executed.
     * @param relayer Address of the contract that relayed the calls on the origin chain
     * @param nonce Nonce to uniquely identify the batch of calls
     */
    event ExecutedCalls(ICrossChainRelayer indexed relayer, uint256 indexed nonce);

    /**
     * @notice Call data structure
     * @param target Address that will be called on the receiving chain
     * @param data Data that will be sent to the `target` address
     */
    struct Call {
        address target;
        bytes data;
    }

    /**
     * @notice Execute calls from the origin chain.
     * @dev Should authenticate that the call has been performed by the bridge transport layer.
     * @dev Must emit the `ExecutedCalls` event once calls have been executed.
     * @param nonce Nonce to uniquely idenfity the batch of calls
     * @param sender Address of the sender on the origin chain
     * @param calls Array of calls being executed
     */
    function executeCalls(
        uint256 nonce,
        address sender,
        Call[] calldata calls
    ) external;
}
