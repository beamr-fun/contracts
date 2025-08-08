// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BeamR} from "../src/contracts/BeamR.sol";
import {IBeamR} from "../src/interfaces/IBeamR.sol";
import {Accounts} from "./setup/Accounts.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import {IPureSuperToken} from "@superfluid/ethereum-contracts/contracts/interfaces/tokens/IPureSuperToken.sol";

contract BeamRTest is Test, Accounts {
    // Using Aleph.im V2 token on Base to test
    address constant TOKEN_ADDRESS = 0x14951082e5dD1Fc46973Ed812Ee531d0321C74B5;

    // holds 19,200 ALEPH tokens
    // chose because the round number is easy to remember
    address constant WHALE = 0x83Be2Ec830E1D1be35CBD624c3d1F7591ad19369;

    BeamR public _beamR;
    ISuperToken public token;

    function setUp() public {
        vm.createSelectFork({blockNumber: 33905653, urlOrAlias: "base"});

        address[] memory poolAdmins = new address[](1);
        address[] memory rootAdmins = new address[](1);

        poolAdmins[0] = admin1(); // Replace with actual pool admin address
        rootAdmins[0] = beamTeam(); // Replace with actual root admin address

        _beamR = new BeamR(poolAdmins, rootAdmins);

        assertTrue(_beamR.hasRole(_beamR.ADMIN_ROLE(), admin1()));
        assertTrue(_beamR.hasRole(_beamR.ROOT_ADMIN_ROLE(), beamTeam()));

        assertFalse(_beamR.hasRole(_beamR.ADMIN_ROLE(), someGuy()));
        assertFalse(_beamR.hasRole(_beamR.ROOT_ADMIN_ROLE(), someGuy()));

        // token = IPureSuperToken(TOKEN_ADDRESS);
        token = ISuperToken(TOKEN_ADDRESS);

        console.log(token.symbol()); // Ensure the token is loaded correctly

        // _setupHolders();
    }

    function test_createPool() public {
        ISuperfluidPool pool = _createPool();

        // assertTrue(pool.distributionFromAnyAddress());
        // assertFalse(pool.transferabilityForUnitsOwner());

        // assertEq(pool.getTotalUnits(), 10);
        // assertEq(pool.getUnits(user1()), 5);
        // assertEq(pool.getUnits(admin1()), 5);
        // assertEq(address(_beamR), pool.admin());
        // assertEq(address(pool.superToken()), address(token));
        // assertEq(pool.getTotalDisconnectedUnits(), 10);
        // assertEq(pool.getTotalConnectedUnits(), 0);
        // assertEq(pool.getTotalFlowRate(), 0);
        // assertEq(pool.getTotalConnectedFlowRate(), 0);
        // assertEq(pool.getTotalDisconnectedFlowRate(), 0);
        // assertEq(pool.getDisconnectedBalance(uint32(block.timestamp)), 0);
        // assertEq(pool.getTotalAmountReceivedByMember(user1()), 0);
        // assertEq(pool.getTotalAmountReceivedByMember(admin1()), 0);
        // assertEq(pool.getMemberFlowRate(user1()), 0);
        // assertEq(pool.getMemberFlowRate(admin1()), 0);
    }

    function _createPool() internal returns (ISuperfluidPool _pool) {
        BeamR.Member[] memory members = new BeamR.Member[](2);

        members[0] = IBeamR.Member({account: user1(), units: 5});

        members[1] = IBeamR.Member({account: admin1(), units: 5});

        vm.prank(admin1());

        _pool = _beamR.createPool(
            token,
            PoolConfig({transferabilityForUnitsOwner: false, distributionFromAnyAddress: true}),
            PoolERC20Metadata({name: "BeamR Pool Token", symbol: "BPT", decimals: 18}),
            members,
            admin1(),
            user1()
        );
    }

    function _setupHolders() internal {
        uint256 balance = token.balanceOf(WHALE);
        console.log("WHALE ALEPH balance:", balance / 1e18);

        vm.prank(WHALE);
        token.transfer(user1(), 1_000e18); // Transfer 1,000 ALEPH to user1

        assertEq(token.balanceOf(user1()), 1_000e18);
    }
}
