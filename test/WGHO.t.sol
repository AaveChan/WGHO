// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {WGHO} from "../src/WGHO.sol";
import {GHO} from "../src/mocks/GHO.sol";
import "../src/interfaces/IGHO.sol";

contract WGHOTest is Test {
    WGHO public wGHO;
    IGHO public gho;

    uint256 public constant INITIAL_BALANCE = 1000e18;

    uint256 internal alice_pk = 0xA11CE;
    uint256 internal bob_pk = 0xB0B;

    address internal alice = vm.addr(alice_pk);
    address internal bob = vm.addr(bob_pk);

    function setUp() public {
        gho = IGHO(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f); // GHO ADDRESS MAINNET
        wGHO = new WGHO(address(gho));

        /*
            Impersonate GHO facilitator to mint GHO
        */
        vm.startPrank(0x00907f9921424583e7ffBfEdf84F92B7B2Be4977);
        gho.mint(alice, INITIAL_BALANCE);
        gho.mint(bob, INITIAL_BALANCE);

        assertEq(gho.balanceOf(alice), INITIAL_BALANCE);
        assertEq(gho.balanceOf(bob), INITIAL_BALANCE);
    }

    /*
        ERC20 Tests
    */
    
    // Test getters
    function testName() public {
        assertEq(wGHO.name(), "Wrapped GHO");
    }

    function testSymbol() public {
        assertEq(wGHO.symbol(), "WGHO");
    }

    function testDecimals() public {
        assertEq(wGHO.decimals(), 18);
    }

    function testApprove() public {
        vm.startPrank(alice);

        wGHO.approve(address(bob), 500e18);

        assertEq(wGHO.allowance(alice, bob), 500e18);
    }

    function testTotalSupplyDeposit() public {
        vm.startPrank(alice);

        gho.approve(address(wGHO), 500e18);
        wGHO.deposit(500e18);

        assertEq(wGHO.totalSupply(), 500e18);
    }
 
    function testTotalSupplyWithdraw() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.withdraw(500e18);
        assertEq(wGHO.totalSupply(), 0);
    }

    function testTotalSupplyWithTransferWithdraw() public {
        vm.startPrank(alice);
        _deposit(500e18);

        wGHO.transfer(address(0), 500e18);
        assertEq(wGHO.totalSupply(), 0);
    }

    function testTotalSupplyWithTransferFromWithdraw() public {
        vm.startPrank(alice);
        _deposit(500e18);

        wGHO.transferFrom(alice, address(0), 500e18);
        assertEq(wGHO.totalSupply(), 0);
    }

    // Test transfer from
    function testTransferFromToAddressWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.transferFrom(alice, bob, 500e18);

        assertEq(wGHO.balanceOf(alice), 0);
        assertEq(wGHO.balanceOf(bob), 500e18);
    }

    function testTransferFromToZeroAddressWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.transferFrom(alice, address(0), 500e18);

        assertEq(wGHO.balanceOf(alice), 0);
        assertEq(wGHO.totalSupply(), 0);
        assertEq(gho.balanceOf(alice), INITIAL_BALANCE);
    }

    function testTransferFromToSelfWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.transferFrom(alice, alice, 500e18);

        assertEq(wGHO.balanceOf(alice), 500e18);
        assertEq(wGHO.totalSupply(), 500e18);
    }

    function testTransferFromToAddressWithoutEnoughBalance() public {
        vm.startPrank(alice);  

        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountExceedsBalance()"));
        wGHO.transferFrom(alice, address(0), 500e18);
    }


    function testTransferFromToZeroAdddressWithoutEnoughBalance() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountExceedsBalance()"));
        wGHO.transferFrom(alice, address(0), 500e18);
    }

    function testTransferFromToSelfWithoutEnoughBalance() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSignature("TransferAmountExceedsBalance()"));
        wGHO.transferFrom(alice, alice, 500e18);
    }

    // Test transfer
    function testTransferToAddressWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.transfer(bob, 500e18);

        assertEq(wGHO.balanceOf(alice), 0);
        assertEq(wGHO.balanceOf(bob), 500e18);
    }

    function testTransferToZeroAddressWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.transfer(address(0), 500e18);

        assertEq(wGHO.balanceOf(alice), 0);
        assertEq(wGHO.totalSupply(), 0);
        assertEq(gho.balanceOf(alice), INITIAL_BALANCE);
    }

    function testTransferToSelfWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.transfer(alice, 500e18);

        assertEq(wGHO.balanceOf(alice), 500e18);
        assertEq(wGHO.totalSupply(), 500e18);
    }

    function testTransferToAddressWithoutEnoughBalance() public {
        vm.startPrank(alice);  

        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountExceedsBalance()"));
        wGHO.transfer(address(0), 500e18);
    }


    function testTransferToZeroAdddressWithoutEnoughBalance() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountExceedsBalance()"));
        wGHO.transfer(address(0), 500e18);
    }

    function testTransferToSelfWithoutEnoughBalance() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSignature("TransferAmountExceedsBalance()"));
        wGHO.transfer(alice, 500e18);
    }

    /*
        Permit tests
    */
    function testValidPermit() public {
        bytes32 digest = _getPermitDigest(alice, bob, 500e18,  block.timestamp + 1 days, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        wGHO.permit(alice, bob, 500e18, block.timestamp + 1 days, v, r, s);

        assertEq(wGHO.allowance(alice, bob), 500e18);
        assertEq(wGHO.nonces(alice), 1);
    }

    function testExpiredPermit() public {
        bytes32 digest = _getPermitDigest(alice, bob, 500e18, block.timestamp + 1 days, 0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);

        vm.warp(1 days + 1);

        vm.expectRevert(abi.encodeWithSignature("ExpiredPermit()"));
        wGHO.permit(alice, bob, 500e18, 1 days, v, r, s);
    }

    function testInvalidPermitSigner() public {
        bytes32 digest = _getPermitDigest(alice, bob, 500e18, 1 days + block.timestamp, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bob_pk, digest); // Spender PK instead of owner
        
        vm.expectRevert(abi.encodeWithSignature("InvalidPermit()"));
        wGHO.permit(alice, bob, 500e18, 1 days + block.timestamp, v, r, s);
    }

    function testInvalidPermitNonce() public {
        bytes32 digest = _getPermitDigest(alice, bob, 500e18, block.timestamp + 1 days, wGHO.nonces(alice) + 1); // Addding 1 to nonce makes it invalid
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        vm.expectRevert(abi.encodeWithSignature("InvalidPermit()"));
        wGHO.permit(alice, bob, 500e18, block.timestamp + 1 days, v, r, s);
    }

    function testPermitSignatureReplay() public {
        bytes32 digest = _getPermitDigest(alice, bob, 500e18, block.timestamp + 1 days, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        wGHO.permit(alice, bob, 500e18, block.timestamp + 1 days, v, r, s);

        vm.expectRevert(abi.encodeWithSignature("InvalidPermit()"));
        wGHO.permit(alice, bob, 500e18, block.timestamp + 1 days, v, r, s);
    }

    function testTransferFromLimitedPermit() public {
        bytes32 digest = _getPermitDigest(alice, bob, 500e18, block.timestamp + 1 days, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        vm.startPrank(alice);
        wGHO.permit(alice, bob, 500e18, block.timestamp + 1 days, v, r, s);
        _deposit(500e18);

        vm.prank(bob);
        wGHO.transferFrom(alice, bob, 500e18);

        assertEq(wGHO.balanceOf(alice), 0);
        assertEq(wGHO.balanceOf(bob), 500e18);
    }

    function testTransferFromMaxPermit() public {
        bytes32 digest = _getPermitDigest(alice, bob, type(uint256).max, block.timestamp + 1 days, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        vm.startPrank(alice);
        wGHO.permit(alice, bob, type(uint256).max, block.timestamp + 1 days, v, r, s);
        _deposit(500e18);

        vm.startPrank(bob);
        wGHO.transferFrom(alice, bob, 500e18);

        assertEq(wGHO.balanceOf(alice), 0);
        assertEq(wGHO.balanceOf(bob), 500e18);
        assertEq(wGHO.allowance(alice, bob), type(uint256).max);
    }

    function testTransferFromPermitInvalidAllowance() public {
        bytes32 digest = _getPermitDigest(alice, bob, 400e18, block.timestamp + 1 days, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        vm.startPrank(alice);
        wGHO.permit(alice, bob, 400e18, block.timestamp + 1 days, v, r, s);
        _deposit(500e18);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("RequestExceedsAllowance()"));
        wGHO.transferFrom(alice, bob, 500e18);
    }

    function testTransferFromPermitInvalidBalance() public {
        bytes32 digest = _getPermitDigest(alice, bob, 1000e18, block.timestamp + 1 days, wGHO.nonces(alice));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice_pk, digest);
        
        vm.startPrank(alice);
        wGHO.permit(alice, bob, 1000e18, block.timestamp + 1 days, v, r, s);
        _deposit(500e18);

        vm.startPrank(bob); 
        vm.expectRevert(abi.encodeWithSignature("TransferAmountExceedsBalance()"));
        wGHO.transferFrom(alice, bob, 1000e18);
    }


    /*
        Deposit and withdraw tests
    */
    function testDepositWithGhoAllowance() public {
        vm.startPrank(alice);

        gho.approve(address(wGHO), 500e18);

        wGHO.deposit(500e18);

        assertEq(wGHO.balanceOf(alice), 500e18);
        assertEq(wGHO.totalSupply(), 500e18);
        assertEq(gho.balanceOf(alice), INITIAL_BALANCE - 500e18);
    }

    function testDepositWithoutGhoAllowance() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughGHOAllowance()"));
        wGHO.deposit(500e18);
    }

    function testDepositWithoutEnoughGhoBalance() public {
        vm.startPrank(alice);
        gho.approve(address(wGHO), 2000e18);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughGHOBalance()"));
        wGHO.deposit(1001e18);
    }

    function testWithdrawWithEnoughBalance() public {
        vm.startPrank(alice);

        _deposit(500e18);

        wGHO.withdraw(500e18);
        assertEq(gho.balanceOf(alice), INITIAL_BALANCE);
        assertEq(wGHO.balanceOf(alice), 0);
    }

    function testWithdrawWithoutEnoughBalance() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountExceedsBalance()"));
        wGHO.withdraw(500e18);
    }

    /*
        Helper functions
    */
    function _deposit(uint256 amount) internal {
        gho.approve(address(wGHO), amount);
        wGHO.deposit(amount);
    }

    function _getPermitDigest(address owner, address spender, uint256 amount, uint256 deadline, uint256 nonce) internal view returns(bytes32) {
        bytes32 hashStruct = keccak256(
        abi.encode(
            wGHO.PERMIT_TYPEHASH(),
            owner,
            spender,
            amount,
            nonce,
            deadline));

        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                wGHO.DOMAIN_SEPARATOR(),
                hashStruct
            )
        );
    }
}
