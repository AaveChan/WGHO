// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {WGHO} from "../src/WGHO.sol";
import {GHO} from "../src/mocks/GHO.sol";

contract WGHOTest is Test {
    WGHO public wGHO;
    GHO public gho;

    uint256 public constant INITIAL_BALANCE = 1000e18;

    address internal alice = address(10);
    address internal bob = address(20);

    function setUp() public {
        gho = new GHO("GHO Stablecoin", "GHO"); 
        wGHO = new WGHO(address(gho));

        gho.mint(alice, INITIAL_BALANCE);
        gho.mint(bob, INITIAL_BALANCE);
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
        bytes4 selector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(wGHO), 0, 500e18));
        wGHO.deposit(500e18);
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
}
