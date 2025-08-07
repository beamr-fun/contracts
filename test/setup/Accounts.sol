// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/StdCheats.sol";

contract Accounts is StdCheats {
    // //////////////////////
    // Vote Admins
    // //////////////////////

    function beamTeam() public returns (address) {
        return makeAddr("dummy_dao");
    }

    function admin1() public returns (address) {
        return makeAddr("admin_1");
    }

    function admin2() public returns (address) {
        return makeAddr("admin_2");
    }

    function admin3() public returns (address) {
        return makeAddr("admin_3");
    }

    // //////////////////////
    // Users
    // //////////////////////

    function user1() public returns (address) {
        return makeAddr("user_1");
    }

    function user2() public returns (address) {
        return makeAddr("user_2");
    }

    function user3() public returns (address) {
        return makeAddr("user_3");
    }

    function user4() public returns (address) {
        return makeAddr("user_4");
    }

    function user5() public returns (address) {
        return makeAddr("user_5");
    }

    // //////////////////////
    // Outsiders
    // //////////////////////

    function someGuy() public returns (address) {
        return makeAddr("some_guy");
    }
}
