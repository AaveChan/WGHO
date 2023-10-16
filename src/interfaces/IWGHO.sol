// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/token/ERC20/IERC20.sol';
import '@openzeppelin/interfaces/IERC2612.sol';
import '@bgd/utils/interfaces/IRescuable.sol';

/**
 * @title Wrapped GHO (WGHO) Interface
 * @dev This interface defines the functions for the Wrapped GHO (WGHO) token, which wraps GHO tokens to make them compatible with other systems.
 */
interface IWGHO is IERC20, IERC2612, IRescuable {

    /**
     * @dev Deposit GHO tokens to receive WGHO tokens.
     * @param amount The amount of GHO tokens to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @dev Withdraw WGHO tokens to receive GHO tokens.
     * @param amount The amount of WGHO tokens to withdraw.
     */
    function withdraw(uint256 amount) external;
}