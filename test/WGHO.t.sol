// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from 'forge-std/Test.sol';
import {WGHO} from '../src/WGHO.sol';
import '../src/interfaces/IGHO.sol';

contract WGHOTest is Test {

    WGHO public wGHO;
    IGHO public gho;

    uint256 public constant INITIAL_BALANCE = 1000e18;

    uint256 internal alice_pk = 0xA11CE;
    uint256 internal bob_pk = 0xB0B;

    address internal alice = vm.addr(alice_pk);
    address internal bob = vm.addr(bob_pk);

    bytes32 public constant METADEPOSIT_TYPEHASH = keccak256(
        'Deposit(uint256 amount,address depositor,uint256 nonce,uint256 deadline,PermitParams permit)'
    );

    bytes32 public constant METAWITHDRAWAL_TYPEHASH = keccak256(
        'Withdraw(uint256 amount,address depositor,uint256 nonce,uint256 deadline,PermitParams permit)'
    );

    function setUp() public {
        gho = IGHO(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f); // GHO ADDRESS MAINNET
        wGHO = new WGHO(address(gho), address(this));

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
        vm.expectRevert(abi.encodeWithSignature('NotEnoughGHOAllowance()'));
        wGHO.deposit(500e18);
    }

    function testDepositWithoutEnoughGhoBalance() public {
        vm.startPrank(alice);
        gho.approve(address(wGHO), 2000e18);
        vm.expectRevert(abi.encodeWithSignature('NotEnoughGHOBalance()'));
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
        vm.expectRevert(abi.encodeWithSignature('WithdrawAmountExceedsBalance()'));
        wGHO.withdraw(500e18);
    }

    /*
        Rescuable tests
    */
    function testEmergencyEtherTransfer() public {

        vm.deal(address(wGHO), 5 ether);

        address recipient = address(1230123519);

        vm.startPrank(wGHO.whoCanRescue());
        
        wGHO.emergencyEtherTransfer(recipient, 5 ether);

        assertEq(address(wGHO).balance, 0 ether);
        assertEq(address(recipient).balance, 5 ether);
    }

    function testEmergencyEtherTransferWhenNotOwner() public {
        vm.deal(address(wGHO), 5 ether);

        assertEq(address(wGHO).balance, 5 ether);

        address recipient = address(1230123519);

        vm.expectRevert('ONLY_RESCUE_GUARDIAN');
        wGHO.emergencyEtherTransfer(recipient, 5 ether);
    }

    function testEmergencyTokenTransfer() public {
        
        vm.startPrank(alice);
        gho.transfer(address(wGHO), 500e18);
        _deposit(500e18); 

        assertEq(gho.balanceOf(address(wGHO)), 1000e18);
        assertEq(wGHO.totalSupply(), 500e18);

        address recipient = address(1230123519);

        vm.startPrank(wGHO.whoCanRescue());
        wGHO.emergencyTokenTransfer(address(gho), recipient, 500e18);

        assertEq(gho.balanceOf(address(wGHO)), 500e18);
        assertEq(gho.balanceOf(recipient), 500e18);
    }

    function testEmergencyTokenTransferWithoutSupply() public {
        
        vm.startPrank(alice);
        gho.transfer(address(wGHO), 500e18);

        assertEq(gho.balanceOf(address(wGHO)), 500e18);

        address recipient = address(1230123519);

        vm.startPrank(wGHO.whoCanRescue());
        vm.expectRevert(abi.encodeWithSignature('NotEnoughGHOBalance()'));
        wGHO.emergencyTokenTransfer(address(gho), recipient, 500e18);
    }

    function testEmergencyTokenTransferWhenNotOwner() public {

        vm.startPrank(alice);
        gho.transfer(address(wGHO), 500e18);

        assertEq(gho.balanceOf(address(wGHO)), 500e18);

        address recipient = address(1230123519);

        vm.expectRevert('ONLY_RESCUE_GUARDIAN');
        wGHO.emergencyTokenTransfer(address(gho), recipient, 500e18);
    }


    /*
        testMetaDeposit:
        with permit
        with invalid digest
        without permit
    */
    function testMetaDeposit() public {
        WGHO.PermitParams memory permit;
        WGHO.SignatureParams memory signature;

        // Prepare permit
        bytes32 permitDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                gho.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'),
                        alice,
                        address(wGHO),
                        500e18,
                        0,
                        block.timestamp + 10
                    )
                )
            )
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(alice_pk, permitDigest);

        permit.owner = alice;
        permit.spender = address(wGHO);
        permit.value = 500e18;
        permit.deadline = block.timestamp + 10;
        permit.v = v1;
        permit.r = r1;
        permit.s = s1;

        // Prepare signature
        bytes32 sigDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        METADEPOSIT_TYPEHASH,
                        500e18,
                        alice,
                        0,
                        block.timestamp + 10,
                        permit
                    )
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alice_pk, sigDigest);

        signature.v = v2;
        signature.r = r2;
        signature.s = s2;

        vm.startPrank(alice);

        wGHO.metaDeposit(500e18, alice, block.timestamp + 10, permit, signature);

        assertEq(wGHO.balanceOf(alice), 500e18);
        assertEq(wGHO.totalSupply(), 500e18);
        assertEq(gho.balanceOf(alice), INITIAL_BALANCE - 500e18);
    }

    function testMetaDepositWithInvalidPermit() public {
        WGHO.PermitParams memory permit;
        WGHO.SignatureParams memory signature;

        // Prepare permit
        bytes32 permitDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                gho.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'),
                        alice,
                        address(wGHO),
                        500e18,
                        1,
                        block.timestamp + 10
                    )
                )
            )
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(alice_pk, permitDigest);

        permit.owner = alice;
        permit.spender = address(wGHO);
        permit.value = 500e18;
        permit.deadline = block.timestamp + 10;
        permit.v = v1;
        permit.r = r1;
        permit.s = s1;

        // Prepare signature
        bytes32 sigDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        METADEPOSIT_TYPEHASH,
                        500e18,
                        alice,
                        0,
                        block.timestamp + 10,
                        permit
                    )
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alice_pk, sigDigest);

        signature.v = v2;
        signature.r = r2;
        signature.s = s2;

        vm.startPrank(alice);

        vm.expectRevert('INVALID_SIGNER');
        wGHO.metaDeposit(500e18, alice, block.timestamp + 10, permit, signature);
        
    }

    function testMetaDepositWithInvalidSignature() public {
        WGHO.PermitParams memory permit;
        WGHO.SignatureParams memory signature;

        // Prepare permit
        bytes32 permitDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                gho.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'),
                        alice,
                        address(wGHO),
                        500e18,
                        0,
                        block.timestamp + 10
                    )
                )
            )
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(bob_pk, permitDigest);

        permit.owner = alice;
        permit.spender = address(wGHO);
        permit.value = 500e18;
        permit.deadline = block.timestamp + 10;
        permit.v = v1;
        permit.r = r1;
        permit.s = s1;

        // Prepare signature
        bytes32 sigDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        METADEPOSIT_TYPEHASH,
                        500e18,
                        alice,
                        0,
                        block.timestamp + 10,
                        permit
                    )
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alice_pk, sigDigest);

        signature.v = v2;
        signature.r = r2;
        signature.s = s2;

        vm.startPrank(alice);

        vm.expectRevert('INVALID_SIGNER');
        wGHO.metaDeposit(500e18, alice, block.timestamp + 10, permit, signature);
    }


    function testMetaWithdrawal() public {

        vm.startPrank(alice);
        _deposit(500e18);
        WGHO.SignatureParams memory signature;

        // Prepare signature
        bytes32 sigDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        METAWITHDRAWAL_TYPEHASH,
                        500e18,
                        alice,
                        0,
                        block.timestamp + 10
                    )
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alice_pk, sigDigest);

        signature.v = v2;
        signature.r = r2;
        signature.s = s2;

        vm.startPrank(bob);
        wGHO.metaWithdraw(500e18, alice, block.timestamp + 10, signature);

        assertEq(gho.balanceOf(alice), INITIAL_BALANCE);
        assertEq(wGHO.balanceOf(alice), 0);
    }

    function testMetaWithdrawalInvalidAddress() public {
        WGHO.SignatureParams memory signature;

        vm.expectRevert(abi.encodeWithSignature('InvalidAddress()'));
        wGHO.metaWithdraw(500e18, address(0), block.timestamp + 10, signature);
    }

    function testMetaWithdrawalWithInvalidDeadline() public {
        WGHO.SignatureParams memory signature;

        vm.expectRevert(abi.encodeWithSignature('InvalidDeadline()'));
        wGHO.metaWithdraw(500e18, alice, block.timestamp - 10, signature);
    } 
    
    function testMetaWithdrawalWithoutDeposit() public {
        WGHO.SignatureParams memory signature;

        // Prepare signature
        bytes32 sigDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        METAWITHDRAWAL_TYPEHASH,
                        500e18,
                        alice,
                        0,
                        block.timestamp + 10
                    )
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alice_pk, sigDigest);

        signature.v = v2;
        signature.r = r2;
        signature.s = s2;

        vm.startPrank(bob);
        
        vm.expectRevert(abi.encodeWithSignature('WithdrawAmountExceedsBalance()'));
        wGHO.metaWithdraw(500e18, alice, block.timestamp + 10, signature); 
    }

    function testMetaWithdrawalWithInvalidSignature() public {

        vm.startPrank(alice);
        _deposit(500e18);

        WGHO.SignatureParams memory signature;

        // Prepare signature
        bytes32 sigDigest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        METAWITHDRAWAL_TYPEHASH,
                        500e18,
                        alice,
                        1,
                        block.timestamp + 10
                    )
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alice_pk, sigDigest);

        signature.v = v2;
        signature.r = r2;
        signature.s = s2;

        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSignature('InvalidSignature()'));
        wGHO.metaWithdraw(500e18, alice, block.timestamp + 10, signature);
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
            keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'),
            owner,
            spender,
            amount,
            nonce,
            deadline));

        return keccak256(
            abi.encodePacked(
                '\x19\x01',
                wGHO.DOMAIN_SEPARATOR(),
                hashStruct
            )
        );
    }
}
