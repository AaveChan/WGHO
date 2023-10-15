// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/token/ERC20/IERC20.sol';
import '@openzeppelin/interfaces/IERC2612.sol';
import './IGhoToken.sol';

interface IGHO is IERC20, IERC2612, IGhoToken {

}