// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/token/ERC20/IERC20.sol';
import '@openzeppelin/token/ERC20/extensions/IERC20Permit.sol';
import '@bgd/utils/interfaces/IRescuable.sol';

/**
 * @title Wrapped GHO (WGHO) Interface
 * @dev This interface defines the functions for the Wrapped GHO (WGHO) token, which wraps GHO tokens to make them compatible with other systems.
 */
interface IWGHO is IERC20, IERC20Permit, IRescuable {

    /// @dev The three signature parameters for any signed message.
    struct SignatureParams {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @dev The parameters needed for the permit with its signature
    struct PermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Deposit GHO tokens to receive WGHO tokens.
     *
     * Requirements:
     * - The caller must have a GHO balance greater than or equal to the deposit amount.
     * - The caller must have approved this contract to spend their GHO tokens.
     *
     * @param amount The amount of GHO tokens to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @dev Deposit GHO tokens to receive WGHO tokens, uses GHO permit and signature.
     *
     * Requirements:
     * - The caller must have a GHO balance greater than or equal to the deposit amount.
     * - The permit data must be valid.
     * - The signature must be valid.
     * - The deadline must be valid
     *
     * @param amount The amount of GHO tokens to deposit.
     * @param depositor The original person that signed the message that should receive the wGHO.
     * @param deadline The deadline in which the signature will be valid.
     * @param permitParams The parameters in order to do the permit.
     * @param sig The signature of the deposit.
     */
    function metaDeposit(
        uint256 amount,
        address depositor,
        uint256 deadline,
        PermitParams calldata permitParams,
        SignatureParams calldata sig
    ) external;

    /**
     * @dev Withdraw WGHO tokens to receive GHO tokens.
     *
     * Requirements:
     * - The caller must have a balance of WGHO tokens greater than or equal to the withdrawal amount.
     *
     * @param amount The amount of WGHO tokens to withdraw.
     */
    function withdraw(uint256 amount) external;

    /**
     * @dev Withdraw WGHO tokens to receive GHO tokens, uses signatures.
     *
     * Requirements:
     * - The depositor must have a balance of WGHO tokens greater than or equal to the withdrawal amount.
     * - The deadline must be valid
     * - The signature must be valid
     *
     * @param amount The amount of WGHO tokens to withdraw.
     * @param depositor The person that signed the message and wants to withdraw.
     * @param deadline The deadline until the signature will be valid.
     * @param sig The signature of the withdraw parameters.
     */
    function metaWithdraw(
        uint256 amount,
        address depositor,
        uint256 deadline,
        SignatureParams calldata sig
    ) external;    
}