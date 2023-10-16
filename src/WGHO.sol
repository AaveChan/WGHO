pragma solidity ^0.8.13;


import {Rescuable, IERC20} from '@bgd/utils/Rescuable.sol';
import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {ERC20Permit} from '@openzeppelin/token/ERC20/extensions/ERC20Permit.sol';
import {AaveGovernanceV2} from '@aave/AaveGovernanceV2.sol';
import './interfaces/IGHO.sol';

/**
 * @title Wrapped GHO (WGHO) Token
 *
 * @notice This contract represents Wrapped GHO (WGHO), which wraps GHO tokens to make them compatible with other systems.
 * It is an ERC20 token with permit support and implements a rescue mechanism.
 *
 * @dev The contract is based on the OpenZeppelin ERC20 and ERC20Permit standards, with additional functionality.
 */
contract WGHO is ERC20, ERC20Permit, Rescuable {

    /// @dev The original GHO token contract
    IGHO public immutable GHO;

    /// @dev Thrown when the user attempts to withdraw an amount greater than their balance.
    error WithdrawAmountExceedsBalance();
    /// @dev Thrown when the user's GHO balance is insufficient for a deposit operation.
    error NotEnoughGHOBalance();
    /// @dev Thrown when the user's GHO allowance for this contract is insufficient for a deposit operation.
    error NotEnoughGHOAllowance();

    /**
     * @dev Initializes the Wrapped GHO contract.
     *
     * @param ghoAddress The address of the original GHO token contract.
     */
    constructor(address ghoAddress) ERC20('Wrapped GHO', 'WGHO') ERC20Permit('WGHO') {
        GHO = IGHO(ghoAddress);
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
    function deposit(uint256 amount) external {
        if (amount > GHO.balanceOf(msg.sender)) revert NotEnoughGHOBalance();
        if (amount > GHO.allowance(msg.sender, address(this))) revert NotEnoughGHOAllowance();

        _mint(msg.sender, amount);

        GHO.transferFrom(msg.sender, address(this), amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    /**
     * @dev Withdraw WGHO tokens to receive GHO tokens.
     *
     * Requirements:
     * - The caller must have a balance of WGHO tokens greater than or equal to the withdrawal amount.
     *
     * @param amount The amount of WGHO tokens to withdraw.
     */
    function withdraw(uint256 amount) external {
        uint256 balance = balanceOf(msg.sender);
        if (balance < amount) revert WithdrawAmountExceedsBalance();

        _burn(msg.sender, amount);

        emit Transfer(msg.sender, address(0), amount);
        GHO.transfer(msg.sender, amount);
    }

    /**
     * @dev Returns the address that can initiate rescue operations.
     *
     * @return The address that can execute rescue operations (AaveGovernanceV2.SHORT_EXECUTOR).
     */
    function whoCanRescue() public pure override returns (address) {
        return AaveGovernanceV2.SHORT_EXECUTOR;
    }
}