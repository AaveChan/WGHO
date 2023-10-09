pragma solidity ^0.8.13;

import "./interfaces/IWGHO.sol";

contract WGHO is IWGHO {

    string public constant name = "Wrapped GHO";
    string public constant symbol = "WGHO";
    uint8  public constant decimals = 18;

    bytes32 public immutable PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    uint256 public immutable deploymentChainId;
    bytes32 private immutable _DOMAIN_SEPARATOR;

    mapping (address => uint256) public override balanceOf;

    mapping (address => uint256) public override nonces;

    mapping (address => mapping (address => uint256)) public override allowance;


    // Transfer errors
    error TransferFailed();
    error BurnAmountExceedsBalance();
    error TransferAmountExceedsBalance();
    error RequestExceedsAllowance();

    //@dev Permit errors
    error ExpiredPermit();
    error InvalidPermit();

    constructor() {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
        deploymentChainId = block.chainid;
    }

    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
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

    function totalSupply() external view override returns (uint256) {
        return address(this).balance;
    }

    function deposit() external payable {
        // _mintTo(msg.sender, msg.value);
        balanceOf[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }

   function withdraw(uint256 value) external {
        // _burnFrom(msg.sender, value);
        uint256 balance = balanceOf[msg.sender];
        if(balance < value) revert BurnAmountExceedsBalance();
        balanceOf[msg.sender] = balance - value;
        emit Transfer(msg.sender, address(0), value);

        // _transferEther(msg.sender, value);
        (bool success, ) = msg.sender.call{value: value}("");
        if(!success) revert TransferFailed();
    }

   function approve(address spender, uint256 value) external override returns (bool) {
        // _approve(msg.sender, spender, value);
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);

        return true;
    }

   function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        if(block.timestamp > deadline) revert ExpiredPermit();

        bytes32 hashStruct = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline));

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid),
                hashStruct));

        address signer = ecrecover(hash, v, r, s);
        if(signer != owner) revert InvalidPermit();
        // _approve(owner, spender, value);
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        // _transferFrom(msg.sender, to, value);
        if (to != address(0) && to != address(this)) { // Transfer
            uint256 balance = balanceOf[msg.sender];
            if(value > balance) revert TransferAmountExceedsBalance();

            balanceOf[msg.sender] = balance - value;
            balanceOf[to] += value;
            emit Transfer(msg.sender, to, value);
        } else { // Withdraw
            uint256 balance = balanceOf[msg.sender];
            if(value > balance) revert BurnAmountExceedsBalance();
            balanceOf[msg.sender] = balance - value;
            emit Transfer(msg.sender, address(0), value);

            (bool success, ) = msg.sender.call{value: value}("");
            if(!success) revert TransferFailed();
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (from != msg.sender) {
            // _decreaseAllowance(from, msg.sender, value);
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                if(value > allowed) revert RequestExceedsAllowance();
                uint256 reduced = allowed - value;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }

        // _transferFrom(from, to, value);
        if (to != address(0) && to != address(this)) { // Transfer
            uint256 balance = balanceOf[from];
            if(value > balance) revert TransferAmountExceedsBalance();

            balanceOf[from] = balance - value;
            balanceOf[to] += value;
            emit Transfer(from, to, value);
        } else { // Withdraw
            uint256 balance = balanceOf[from];
            if(value > balance) revert BurnAmountExceedsBalance();
            balanceOf[from] = balance - value;
            emit Transfer(from, address(0), value);

            (bool success, ) = msg.sender.call{value: value}("");
            if(!success) revert TransferFailed();
        }

        return true;
    }
}