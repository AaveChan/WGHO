// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/interfaces/IERC2612.sol';
import {IERC20} from "@bgd/utils/Rescuable.sol";
import './IGhoToken.sol';

/**
 * @title GHO Interface
*/
interface IGHO is IERC20, IERC2612, IGhoToken {

}