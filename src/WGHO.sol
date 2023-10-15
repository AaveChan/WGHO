// SPDX-License-Identifier: MIT
// Aave-Chan Initiative

pragma solidity ^0.8.13;

import "./interfaces/IWGHO.sol";
import "./interfaces/IGHO.sol";
import "@aave/AaveGovernanceV2.sol";

/// @title WGHO - Wrapped GHO
contract WGHO is IWGHO {

    /// @dev The name of the wrapped token
    string public constant name = "Wrapped GHO";

    /// @dev The symbol of the wrapped token
    string public constant symbol = "WGHO";

    /// @dev The number of decimal places for the token
    uint8 public constant decimals = 18;

    /// @dev The type hash for permit function
    bytes32 public immutable PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @dev The chain ID of the deployment
    uint256 public immutable deploymentChainId;

    /// @dev The total supply of the wrapped token
    uint256 public totalSupply;

    /// @dev The domain separator used for EIP-712
    bytes32 private immutable _DOMAIN_SEPARATOR;

    /// @dev The original GHO token contract
    IGHO public immutable GHO;

    /// @dev A mapping of account balances
    mapping (address => uint256) public override balanceOf;

    /// @dev A mapping of nonces for permits
    mapping (address => uint256) public override nonces;

    /// @dev A mapping of spending allowances
    mapping (address => mapping (address => uint256)) public override allowance;

    // Transfer errors
    error TransferFailed();
    error WithdrawAmountExceedsBalance();
    error TransferAmountExceedsBalance();
    error RequestExceedsAllowance();
    error NotEnoughGHOBalance();
    error NotEnoughGHOAllowance();

    // Permit errors
    error ExpiredPermit();
    error InvalidPermit();

    /// @dev Modifier to restrict access to the rescue guardian
    modifier onlyRescueGuardian() {
        if (msg.sender != whoCanRescue()) revert OnlyRescueGuardian();
        _;
    }

    /// @dev Constructor to initialize the contract with the original GHO token address
    /// @param ghoAddress The address of the original GHO token contract
    constructor(address ghoAddress) {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
        deploymentChainId = block.chainid;
        GHO = IGHO(ghoAddress);
    }

    /// @dev Internal function to calculate the EIP-712 domain separator
    /// @param chainId The chain ID
    /// @return The EIP-712 domain separator
    function _calculateDomainSeparator(uint256 chainId) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /// @dev Get the current EIP-712 domain separator
    /// @return The EIP-712 domain separator
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid);
    }

    /// @dev Deposit function to wrap GHO tokens
    /// @param amount The amount of GHO tokens to deposit
    function deposit(uint256 amount) external {
        if (amount > GHO.balanceOf(msg.sender)) revert NotEnoughGHOBalance(); 
        if (amount > GHO.allowance(msg.sender, address(this))) revert NotEnoughGHOAllowance();
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        GHO.transferFrom(msg.sender, address(this), amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    /// @dev Withdraw function to unwrap GHO tokens
    /// @param amount The amount of WGHO tokens to withdraw
    function withdraw(uint256 amount) external {
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) revert WithdrawAmountExceedsBalance();
        balanceOf[msg.sender] = balance - amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        GHO.transfer(msg.sender, amount);
    }

    /// @dev Approve function to set an allowance for a spender
    /// @param spender The address of the spender
    /// @param amount The allowance amount
    /// @return true if the approval was successful
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @dev Permit function to approve a spender with a signature
    /// @param owner The owner of the tokens
    /// @param spender The address of the spender
    /// @param amount The allowance amount
    /// @param deadline The deadline for the permit
    /// @param v The recovery id of the signature
    /// @param r The R part of the signature
    /// @param s The S part of the signature
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        if (block.timestamp > deadline) revert ExpiredPermit();
        bytes32 hashStruct = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                amount,
                nonces[owner]++,
                deadline));
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid),
                hashStruct));
        address signer = ecrecover(hash, v, r, s);
        if (signer != owner) revert InvalidPermit();
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /// @dev Transfer function to send tokens to another address
    /// @param to The recipient address
    /// @param amount The amount of tokens to transfer
    /// @return true if the transfer was successful
    function transfer(address to, uint256 amount) external override returns (bool) {
        if (to != address(0) && to != address(this)) { // Transfer
            uint256 balance = balanceOf[msg.sender];
            if (amount > balance) revert TransferAmountExceedsBalance();
            balanceOf[msg.sender] = balance - amount;
            balanceOf[to] += amount;
            emit Transfer(msg.sender, to, amount);
        } else { // Withdraw
            uint256 balance = balanceOf[msg.sender];
            if (amount > balance) revert WithdrawAmountExceedsBalance();
            balanceOf[msg.sender] = balance - amount;
            emit Transfer(msg.sender, address(0), amount);
            totalSupply -= amount;
            GHO.transfer(msg.sender, amount);
        }
        return true;
    }

    /// @dev Transfer function to send tokens from one address to another
    /// @param from The sender's address
    /// @param to The recipient address
    /// @param amount The amount of tokens to transfer
    /// @return true if the transfer was successful
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                if (amount > allowed) revert RequestExceedsAllowance();
                uint256 reduced = allowed - amount;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }
        if (to != address(0) && to != address(this)) { // Transfer
            uint256 balance = balanceOf[from];
            if (amount > balance) revert TransferAmountExceedsBalance();
            balanceOf[from] = balance - amount;
            balanceOf[to] += amount;
            emit Transfer(from, to, amount);
        } else { // Withdraw
            uint256 balance = balanceOf[from];
            if (amount > balance) revert WithdrawAmountExceedsBalance();
            balanceOf[from] = balance - amount;
            emit Transfer(from, address(0), amount);
            totalSupply -= amount;
            GHO.transfer(msg.sender, amount);
        }
        return true;
    }

    /// @inheritdoc IRescuable
    function emergencyTokenTransfer(
        address erc20Token,
        address to,
        uint256 amount
    ) external onlyRescueGuardian {
        IERC20(erc20Token).transfer(to, amount);
        emit ERC20Rescued(msg.sender, erc20Token, to, amount);
    }

    /// @inheritdoc IRescuable
    function emergencyEtherTransfer(address to, uint256 amount) external onlyRescueGuardian {
        (bool success, ) = to.call{value: amount}(new bytes(0));
        if (!success) revert EthRescueTransferFail();
        emit NativeTokensRescued(msg.sender, to, amount);
    }

    /// @inheritdoc IRescuable
    function whoCanRescue() public view virtual returns (address) {
        return AaveGovernanceV2.SHORT_EXECUTOR;
    }
}