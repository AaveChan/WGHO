pragma solidity ^0.8.13;

import "./interfaces/IWGHO.sol";
import "./interfaces/IGHO.sol";

contract WGHO is IWGHO {

    string public constant name = "Wrapped GHO";
    string public constant symbol = "WGHO";
    uint8  public constant decimals = 18;

    bytes32 public immutable PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    uint256 public immutable deploymentChainId;
    uint256 public totalSupply;
    bytes32 private immutable _DOMAIN_SEPARATOR;
    IGHO public immutable GHO;

    mapping (address => uint256) public override balanceOf;

    mapping (address => uint256) public override nonces;

    mapping (address => mapping (address => uint256)) public override allowance;

    // Transfer errors
    error TransferFailed();
    error WithdrawAmountExceedsBalance();
    error TransferAmountExceedsBalance();
    error RequestExceedsAllowance();

    //@dev Permit errors
    error ExpiredPermit();
    error InvalidPermit();

    constructor(address ghoAddress) {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
        deploymentChainId = block.chainid;
        GHO = IGHO(ghoAddress);
    }

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

    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid);
    }

    function deposit(uint256 amount) external {
        // _mintTo(msg.sender, amount);
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        GHO.transferFrom(msg.sender, address(this), amount);
        emit Transfer(address(0), msg.sender, amount);
    }

   function withdraw(uint256 amount) external {
        // _burnFrom(msg.sender, amount);
        uint256 balance = balanceOf[msg.sender];
        if(balance < amount) revert WithdrawAmountExceedsBalance();
        balanceOf[msg.sender] = balance - amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);

        GHO.transfer(msg.sender, amount);
    }

   function approve(address spender, uint256 amount) external override returns (bool) {
        // _approve(msg.sender, spender, amount);
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        return true;
    }

   function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        if(block.timestamp > deadline) revert ExpiredPermit();

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
        if(signer != owner) revert InvalidPermit();
        // _approve(owner, spender, amount);
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        // _transferFrom(msg.sender, to, amount);
        if (to != address(0) && to != address(this)) { // Transfer
            uint256 balance = balanceOf[msg.sender];
            if(amount > balance) revert TransferAmountExceedsBalance();

            balanceOf[msg.sender] = balance - amount;
            balanceOf[to] += amount;
            emit Transfer(msg.sender, to, amount);
        } else { // Withdraw
            uint256 balance = balanceOf[msg.sender];
            if(amount > balance) revert WithdrawAmountExceedsBalance();
            balanceOf[msg.sender] = balance - amount;
            emit Transfer(msg.sender, address(0), amount);
            totalSupply -= amount;
            GHO.transfer(msg.sender, amount);
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (from != msg.sender) {
            // _decreaseAllowance(from, msg.sender, amount);
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                if(amount > allowed) revert RequestExceedsAllowance();
                uint256 reduced = allowed - amount;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }

        // _transferFrom(from, to, amount);
        if (to != address(0) && to != address(this)) { // Transfer
            uint256 balance = balanceOf[from];
            if(amount > balance) revert TransferAmountExceedsBalance();

            balanceOf[from] = balance - amount;
            balanceOf[to] += amount;
            emit Transfer(from, to, amount);
        } else { // Withdraw
            uint256 balance = balanceOf[from];
            if(amount > balance) revert WithdrawAmountExceedsBalance();
            balanceOf[from] = balance - amount;
            emit Transfer(from, address(0), amount);
            totalSupply -= amount;
            GHO.transfer(msg.sender, amount);
        }

        return true;
    }
}