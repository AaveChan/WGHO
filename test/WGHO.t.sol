// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {WGHO} from "../src/WGHO.sol";

contract WGHOTest is Test {
    WGHO public token;

    function setUp() public {
        token = new WGHO();
    }
    
}
