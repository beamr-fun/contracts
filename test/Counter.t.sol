// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BeamR} from "../src/contracts/BeamR.sol";
import {IBeamR} from "../src/interfaces/IBeamR.sol";
import {Accounts} from "./setup/Accounts.sol";

import {
    IGeneralDistributionAgreementV1,
    ISuperToken,
    ISuperfluidPool
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import {IPureSuperToken} from "@superfluid/ethereum-contracts/contracts/interfaces/tokens/IPureSuperToken.sol";

contract BeamRTest is Test, Accounts {
    // GDA V1 address on Base
    address constant GDA_V1 = 0x6DA13Bde224A05a288748d857b9e7DDEffd1dE08;
    // Using Aleph.im V2 token on Base to test
    address constant TOKEN_ADDRESS = 0xc0Fbc4967259786C743361a5885ef49380473dCF;

    // holds 19,200 ALEPH tokens
    // chose because the round number is easy to remember
    address constant WHALE = 0x83Be2Ec830E1D1be35CBD624c3d1F7591ad19369;

    IGeneralDistributionAgreementV1 public gda;
    BeamR public _beamR;
    ISuperToken public token;

    function setUp() public {
        vm.createSelectFork({blockNumber: 33905653, urlOrAlias: "base"});

        address[] memory poolAdmins = new address[](1);
        address[] memory rootAdmins = new address[](1);

        poolAdmins[0] = admin1(); // Replace with actual pool admin address
        rootAdmins[0] = beamTeam(); // Replace with actual root admin address

        _beamR = new BeamR(poolAdmins, rootAdmins, GDA_V1);

        gda = _beamR.gda();

        assertTrue(_beamR.hasRole(_beamR.POOL_ADMIN_ROLE(), admin1()));
        assertTrue(_beamR.hasRole(_beamR.ROOT_ADMIN_ROLE(), beamTeam()));

        // token = IPureSuperToken(TOKEN_ADDRESS);
        token = ISuperToken(TOKEN_ADDRESS);

        // assertEq(gda.agreementType(), keccak256("org.superfluid-finance.agreements.GeneralDistributionAgreement.v1"));

        _setupHolders();
    }

    function test_createPool() public {
        _createPool_noFlow();
    }

    function _createPool_noFlow() internal returns (address _poolAddress) {
        vm.startPrank(user1());

        BeamR.Member[] memory members = new BeamR.Member[](2);

        members[0] = IBeamR.Member({account: user1(), units: 5});

        members[1] = IBeamR.Member({account: admin1(), units: 5});

        _beamR.createPool(
            token,
            PoolConfig({transferabilityForUnitsOwner: false, distributionFromAnyAddress: true}),
            PoolERC20Metadata({name: "BeamR Pool Token", symbol: "BPT", decimals: 18}),
            members,
            admin1(),
            254,
            IBeamR.Metadata({protocol: 1, pointer: "https://example.com/pool-metadata"})
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
