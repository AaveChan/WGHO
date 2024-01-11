pragma solidity ^0.8.13;

import {Rescuable, IERC20} from '@bgd/utils/Rescuable.sol';
import {SafeERC20} from '@bgd/oz-common/SafeERC20.sol';
import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {ERC20Permit} from '@openzeppelin/token/ERC20/extensions/ERC20Permit.sol';
import {IERC20Permit} from '@openzeppelin/token/ERC20/extensions/IERC20Permit.sol';
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
contract WGHO is ERC20, ERC20Permit, Rescuable, Ownable {

    using SafeERC20 for IERC20;

    struct SignatureParams {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct PermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    /// @dev Typehash of the deposit function
    bytes32 public constant METADEPOSIT_TYPEHASH = keccak256(
        'Deposit(uint256 amount,address depositor,uint256 nonce,uint256 deadline,PermitParams permit)'
    );

    // @dev Typehash of the withdrawal function
    bytes32 public constant METAWITHDRAWAL_TYPEHASH = keccak256(
        'Withdraw(uint256 amount,address depositor,uint256 nonce,uint256 deadline,PermitParams permit)'
    );

    // @dev Address that will be able to call the rescue
    address rescueAddress;

    /// @dev The original GHO token contract
    IGHO public immutable GHO;

    /// @dev Thrown when the user attempts to withdraw an amount greater than their balance.
    error WithdrawAmountExceedsBalance();
    /// @dev Thrown when the user's GHO balance is insufficient for a deposit operation.
    error NotEnoughGHOBalance();
    /// @dev Thrown when the user's GHO allowance for this contract is insufficient for a deposit operation.
    error NotEnoughGHOAllowance();
    /// @dev Thrown when the user that attems to meta deposit / withdraw is the zero address
    error InvalidAddress();
    /// @dev Thrown when the deadline submitted for the permit on meta transactions is invalid
    error InvalidDeadline();
    /// @dev Thrown when thet signature submitted on the meta transactions is invalid
    error InvalidSignature();

    /**
     * @dev Initializes the Wrapped GHO contract.
     *
     * @param ghoAddress The address of the original GHO token contract.
     * @param owner The address of the short executor of the v3
     */
    constructor(address ghoAddress, address owner) ERC20('Wrapped GHO', 'WGHO') ERC20Permit('WGHO') Ownable(owner) {
        GHO = IGHO(ghoAddress);
        rescueAddress = AaveGovernanceV2.SHORT_EXECUTOR;
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
    }

    function metaDeposit(
        uint256 amount,
        address depositor,
        uint256 deadline,
        PermitParams calldata permitParams,
        SignatureParams calldata sig
    ) external {
        if(depositor == address(0)) revert InvalidAddress();
        if(deadline < block.timestamp) revert InvalidDeadline();

        uint256 nonce = nonces(depositor);

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    _domainSeparatorV4(),
                    keccak256(
                        abi.encode(
                            METADEPOSIT_TYPEHASH,
                            amount,
                            depositor,
                            nonce,
                            deadline,
                            permitParams
                        )
                    )
                )
            );

            _useNonce(depositor);
            if(depositor != ecrecover(digest, sig.v, sig.r, sig.s)) revert InvalidSignature();
        }

        // assume if deadline 0 no permit was supplied
        if(permitParams.deadline != 0) {
            IERC20Permit(address(GHO)).permit(
                depositor,
                address(this),
                permitParams.value,
                permitParams.deadline,
                permitParams.v,
                permitParams.r,
                permitParams.s
            );
        }

        _mint(depositor, amount);

        GHO.transferFrom(depositor, address(this), amount);
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
        if (balanceOf(msg.sender) < amount) revert WithdrawAmountExceedsBalance();

        _burn(msg.sender, amount);
        
        GHO.transfer(msg.sender, amount);
    }

    function metaWithdraw(
        uint256 amount,
        address depositor,
        uint256 deadline,
        PermitParams calldata permitParams,
        SignatureParams calldata sig
    ) external {
        if(depositor == address(0)) revert InvalidAddress();
        if(deadline < block.timestamp) revert InvalidDeadline();
        if(balanceOf(depositor) < amount) revert WithdrawAmountExceedsBalance();

        uint256 nonce = nonces(depositor);

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    _domainSeparatorV4(),
                    keccak256(
                        abi.encode(
                            METAWITHDRAWAL_TYPEHASH,
                            amount,
                            depositor,
                            nonce,
                            deadline,
                            permitParams
                        )
                    )
                )
            );

            _useNonce(depositor);
            if(depositor != ecrecover(digest, sig.v, sig.r, sig.s)) revert InvalidSignature();
        }

        _burn(depositor, amount);
        
        GHO.transfer(depositor, amount);
    }

    /**
     * @dev Returns the address that can initiate rescue operations.
     *
     * @return The address that can execute rescue operations (AaveGovernanceV2.SHORT_EXECUTOR).
     */
    function whoCanRescue() public view override returns (address) {
        return rescueAddress;
    }

    /**
     * @dev Changes the address that can initiate rescue operations
     */
    function changeWhoCanRescue(address _rescueAddress) public onlyOwner() {
        rescueAddress = _rescueAddress;
    }

    //@inheritdoc 
    function emergencyTokenTransfer(
        address erc20Token,
        address to,
        uint256 amount
    ) external override onlyRescueGuardian {

        if(erc20Token == address(GHO) && amount > totalSupply()) revert NotEnoughGHOBalance();

        IERC20(erc20Token).safeTransfer(to, amount);

        emit ERC20Rescued(msg.sender, erc20Token, to, amount);
    }
    
}