// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BeamR} from "../src/contracts/BeamR.sol";
import {IBeamR} from "../src/interfaces/IBeamR.sol";
import {Accounts} from "./setup/Accounts.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import {IPureSuperToken} from "@superfluid/ethereum-contracts/contracts/interfaces/tokens/IPureSuperToken.sol";

interface IGDAForwader {
    function distributeFlow(
        ISuperToken token,
        address sender,
        ISuperfluidPool pool,
        int96 flowRate,
        bytes calldata userData
    ) external;
}

contract BeamRTest is Test, Accounts {
    error Unauthorized();

    // Using STREME token on Base to test
    address constant TOKEN_ADDRESS = 0x3B3Cd21242BA44e9865B066e5EF5d1cC1030CC58;
    address constant FOWARDER_ADDRESS = 0x6DA13Bde224A05a288748d857b9e7DDEffd1dE08;

    // holds 500,000,000 Streme
    // chose because the round number is easy to remember
    address constant WHALE = 0x22C64e05aabDE039A7c9792d6886D8C2D714b2E9;

    BeamR public _beamR;
    ISuperToken public token;
    IGDAForwader public gdaForwarder;

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

        assertEq(_beamR.getRoleAdmin(_beamR.ADMIN_ROLE()), _beamR.ROOT_ADMIN_ROLE());
        assertEq(_beamR.getRoleAdmin(_beamR.ROOT_ADMIN_ROLE()), 0x00);

        token = ISuperToken(TOKEN_ADDRESS);
        gdaForwarder = IGDAForwader(FOWARDER_ADDRESS);

        _setupHolders();
    }

    function test_createPool() public {
        ISuperfluidPool pool = _createPool();

        // TEST AND RECORD POOL STATE
        assertTrue(pool.distributionFromAnyAddress());
        assertFalse(pool.transferabilityForUnitsOwner());
        assertEq(pool.getTotalUnits(), 10);
        assertEq(pool.getUnits(user1()), 5);
        assertEq(pool.getUnits(admin1()), 5);
        assertEq(address(_beamR), pool.admin());
        assertEq(address(pool.superToken()), address(token));
        assertEq(pool.getTotalDisconnectedUnits(), 10);
        assertEq(pool.getTotalConnectedUnits(), 0);
        assertEq(pool.getTotalFlowRate(), 0);
        assertEq(pool.getTotalConnectedFlowRate(), 0);
        assertEq(pool.getTotalDisconnectedFlowRate(), 0);
        assertEq(pool.getDisconnectedBalance(uint32(block.timestamp)), 0);
        assertEq(pool.getTotalAmountReceivedByMember(user1()), 0);
        assertEq(pool.getTotalAmountReceivedByMember(admin1()), 0);
        assertEq(pool.getMemberFlowRate(user1()), 0);
        assertEq(pool.getMemberFlowRate(admin1()), 0);

        assertEq(_beamR.poolAdminKey(address(pool)), keccak256(abi.encodePacked(address(pool))));
    }

    function test_createPool_role() public {
        ISuperfluidPool pool = _createPool();

        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user1()));

        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), admin1()));
        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), beamTeam()));
        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), someGuy()));

        // Check that the pool admin role is set correctly
        assertEq(_beamR.getRoleAdmin(_beamR.poolAdminKey(address(pool))), _beamR.poolAdminKey(address(pool)));
    }

    function test_createPool_roleMgmt() public {
        ISuperfluidPool pool = _createPool();

        // Check that user1 can manage the pool admin role
        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user1()));

        // user1 should be able to grant admin role to user2
        vm.startPrank(user1());
        _beamR.grantRole(_beamR.poolAdminKey(address(pool)), user2());

        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user2()));

        // user1 should be able to revoke admin role from user2
        _beamR.revokeRole(_beamR.poolAdminKey(address(pool)), user2());
        vm.stopPrank();

        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user2()));
    }

    function test_rootGrantsAdminRole() public {
        // Check that admin2 does not have the ADMIN_ROLE initially
        assertFalse(_beamR.hasRole(_beamR.ADMIN_ROLE(), admin2()));

        // Root admin grants ADMIN_ROLE to admin1
        vm.startPrank(beamTeam());
        _beamR.grantRole(_beamR.ADMIN_ROLE(), admin2());
        vm.stopPrank();

        // Verify that admin2 now has the ADMIN_ROLE
        assertTrue(_beamR.hasRole(_beamR.ADMIN_ROLE(), admin2()));
    }

    function test_distributeFlow() public {
        ISuperfluidPool pool = _createPool();

        _distributeFlow(pool);

        assertEq(pool.getMemberFlowRate(user1()), 50);
        assertEq(pool.getMemberFlowRate(admin1()), 50);
        assertEq(pool.getTotalFlowRate(), 100);
        assertEq(pool.getTotalDisconnectedUnits(), 10);
        assertEq(pool.getTotalConnectedUnits(), 0);
        assertEq(pool.getTotalConnectedFlowRate(), 0);
        assertEq(pool.getTotalDisconnectedFlowRate(), 100);

        assertEq(pool.getTotalAmountReceivedByMember(user1()), 0);
        assertEq(pool.getTotalAmountReceivedByMember(admin1()), 0);

        assertEq(pool.getDisconnectedBalance(uint32(block.timestamp + 10)), 1000);
    }

    function test_updateMemberUnits() public {
        ISuperfluidPool pool = _createPool();

        // Check initial units
        assertEq(pool.getUnits(user1()), 5);
        assertEq(pool.getUnits(admin1()), 5);

        // Update user1's units to 10
        BeamR.Member[] memory members = new BeamR.Member[](1);
        members[0] = IBeamR.Member({account: user1(), units: 10});

        address[] memory poolAddresses = new address[](1);
        poolAddresses[0] = address(pool);

        vm.startPrank(user1());
        _beamR.updateMemberUnits(members, poolAddresses);
        vm.stopPrank();

        // Verify updated units
        assertEq(pool.getUnits(user1()), 10);
        assertEq(pool.getUnits(admin1()), 5);
    }

    function test_updateMemberUnits_byAdmin() public {
        ISuperfluidPool pool = _createPool();

        // Check initial units
        assertEq(pool.getUnits(user1()), 5);
        assertEq(pool.getUnits(admin1()), 5);

        // Update user1's units to 10 by admin1
        BeamR.Member[] memory members = new BeamR.Member[](1);
        members[0] = IBeamR.Member({account: user1(), units: 10});

        address[] memory poolAddresses = new address[](1);
        poolAddresses[0] = address(pool);

        vm.startPrank(admin1());
        _beamR.updateMemberUnits(members, poolAddresses);
        vm.stopPrank();

        // Verify updated units
        assertEq(pool.getUnits(user1()), 10);
        assertEq(pool.getUnits(admin1()), 5);
    }

    function test_bactchUpdateMemberUnits() public {
        ISuperfluidPool pool = _createPool();

        // Check initial units
        assertEq(pool.getUnits(user1()), 5);
        assertEq(pool.getUnits(admin1()), 5);
        assertEq(pool.getUnits(user3()), 0);
        assertEq(pool.getUnits(user4()), 0);
        assertEq(pool.getUnits(user5()), 0);

        BeamR.Member[] memory members = new BeamR.Member[](5);
        members[0] = IBeamR.Member({account: user1(), units: 10});
        members[1] = IBeamR.Member({account: admin1(), units: 15});
        members[2] = IBeamR.Member({account: user3(), units: 20});
        members[3] = IBeamR.Member({account: user4(), units: 25});
        members[4] = IBeamR.Member({account: user5(), units: 30});

        address[] memory poolAddresses = new address[](5);
        poolAddresses[0] = address(pool);
        poolAddresses[1] = address(pool);
        poolAddresses[2] = address(pool);
        poolAddresses[3] = address(pool);
        poolAddresses[4] = address(pool);

        vm.startPrank(admin1());
        _beamR.updateMemberUnits(members, poolAddresses);
        vm.stopPrank();

        // Verify updated units
        assertEq(pool.getUnits(user1()), 10);
        assertEq(pool.getUnits(admin1()), 15);
        assertEq(pool.getUnits(user3()), 20);
        assertEq(pool.getUnits(user4()), 25);
        assertEq(pool.getUnits(user5()), 30);
        assertEq(pool.getTotalUnits(), 100); // 10 + 15 + 20 + 25 + 30
    }

    function test_bactchUpdateMemberUnits_acrossPools() public {
        ISuperfluidPool pool1 = _createPool();

        // Check initial units in pool1
        assertEq(pool1.getUnits(user1()), 5);
        assertEq(pool1.getUnits(admin1()), 5);

        // Create a second pool with different members
        BeamR.Member[] memory members2 = new BeamR.Member[](2);

        members2[0] = IBeamR.Member({account: user2(), units: 5});
        members2[1] = IBeamR.Member({account: admin1(), units: 5});

        vm.prank(admin1());

        ISuperfluidPool pool2 = _beamR.createPool(
            token,
            PoolConfig({transferabilityForUnitsOwner: false, distributionFromAnyAddress: true}),
            PoolERC20Metadata({name: "BeamR Pool Token 2", symbol: "BPT2", decimals: 18}),
            members2,
            user2(),
            IBeamR.Metadata({protocol: 1, pointer: "https://beamr.io"})
        );

        // Check initial units in pool2
        assertEq(pool2.getUnits(user2()), 5);
        assertEq(pool2.getUnits(admin1()), 5);

        // Update units across both pools
        BeamR.Member[] memory members = new BeamR.Member[](3);
        members[0] = IBeamR.Member({account: user3(), units: 10});
        members[1] = IBeamR.Member({account: user4(), units: 15});
        members[2] = IBeamR.Member({account: user5(), units: 20});

        address[] memory poolAddresses = new address[](3);
        poolAddresses[0] = address(pool1);
        poolAddresses[1] = address(pool1);
        poolAddresses[2] = address(pool2);

        vm.startPrank(admin1());
        _beamR.updateMemberUnits(members, poolAddresses);
        vm.stopPrank();

        // Verify updated units in both pools
        assertEq(pool1.getUnits(user3()), 10);
        assertEq(pool1.getUnits(user4()), 15);
        assertEq(pool2.getUnits(user5()), 20);

        assertEq(pool2.getUnits(user3()), 0);
        assertEq(pool2.getUnits(user4()), 0);
        assertEq(pool1.getUnits(user5()), 0);
    }

    function testRescuePoolCreator() public {
        ISuperfluidPool pool = _createPool();

        // Check that user1 is the creator of the pool
        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user1()));
        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user2()));

        // Check that admin1 can rescue the pool creator
        vm.startPrank(beamTeam());
        _beamR.rescuePoolCreator(address(pool), user2(), user1());
        vm.stopPrank();

        // Verify that the creator was rescued correctly

        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user1()));
        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user2()));
    }

    function testRescuedPoolCreatorCanPerformFunctions() public {
        ISuperfluidPool pool = _createPool();

        // Check that admin1 can rescue the pool creator
        vm.startPrank(beamTeam());
        _beamR.rescuePoolCreator(address(pool), user2(), user1());
        vm.stopPrank();

        // Verify that the new creator can manage the pool admin role

        vm.startPrank(user2());
        _beamR.grantRole(_beamR.poolAdminKey(address(pool)), user3());

        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user3()));
        vm.stopPrank();
    }

    function testUpdateMetadata() public {
        ISuperfluidPool pool = _createPool();

        vm.prank(user1());
        _beamR.updateMetadata(address(pool), IBeamR.Metadata({protocol: 2, pointer: "https://new-metadata.com"}));
    }

    //////////////////////////////////
    ///// REVERTS ///////////////////
    /////////////////////////////////

    function testRevert_adminGrantsRole_UNAUTHORIZED() public {
        string memory expectedError = _createOZAccessControlErrorMessage(admin1(), _beamR.ROOT_ADMIN_ROLE());

        _manuallyTestGrantRoleError(expectedError, admin1(), someOtherGuy(), _beamR.ADMIN_ROLE());
    }

    function testRevert_poolAdmin_grantRole_UNAUTHORIZED() public {
        ISuperfluidPool pool = _createPool();
        bytes32 poolRole = _beamR.poolAdminKey(address(pool));

        string memory expectedError = _createOZAccessControlErrorMessage(someGuy(), poolRole);
        vm.startPrank(someGuy());
        vm.expectRevert(bytes(expectedError));
        _beamR.grantRole(poolRole, someOtherGuy());
        vm.stopPrank();
    }

    function testRevert_poolAdmin_revokeRole_UNAUTHORIZED() public {
        ISuperfluidPool pool = _createPool();
        bytes32 poolRole = _beamR.poolAdminKey(address(pool));

        string memory expectedError = _createOZAccessControlErrorMessage(user2(), poolRole);

        vm.startPrank(user2());
        vm.expectRevert(bytes(expectedError));
        _beamR.revokeRole(poolRole, user1());
        vm.stopPrank();
    }

    function testRevert_poolAdmin_tryAccessOtherPools() public {
        ISuperfluidPool pool1 = _createPool();

        // Create a second pool with different members
        BeamR.Member[] memory members2 = new BeamR.Member[](2);

        members2[0] = IBeamR.Member({account: user2(), units: 5});
        members2[1] = IBeamR.Member({account: admin1(), units: 5});

        vm.prank(admin1());

        ISuperfluidPool pool2 = _beamR.createPool(
            token,
            PoolConfig({transferabilityForUnitsOwner: false, distributionFromAnyAddress: true}),
            PoolERC20Metadata({name: "BeamR Pool Token 2", symbol: "BPT2", decimals: 18}),
            members2,
            user2(),
            IBeamR.Metadata({protocol: 1, pointer: "https://beamr.io"})
        );

        bytes32 poolRole1 = _beamR.poolAdminKey(address(pool1));
        bytes32 poolRole2 = _beamR.poolAdminKey(address(pool2));

        // user1 is admin of pool1 but not pool2
        assertTrue(_beamR.hasRole(poolRole1, user1()));
        assertFalse(_beamR.hasRole(poolRole2, user1()));

        // user2 is admin of pool2 but not pool1
        assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool2)), user2()));
        assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool1)), user2()));

        string memory expectedError = _createOZAccessControlErrorMessage(user1(), poolRole2);

        _manuallyTestGrantRoleError(expectedError, user1(), someOtherGuy(), poolRole2);

        expectedError = _createOZAccessControlErrorMessage(user2(), poolRole1);

        _manuallyTestGrantRoleError(expectedError, user2(), someOtherGuy(), poolRole1);
    }

    function testPublicCannotGrantAdminRole() public {
        // Check that a non-admin cannot grant the ADMIN_ROLE
        string memory expectedError = _createOZAccessControlErrorMessage(someGuy(), _beamR.ROOT_ADMIN_ROLE());

        _manuallyTestGrantRoleError(expectedError, someGuy(), someOtherGuy(), _beamR.ADMIN_ROLE());
    }

    function testPublicCannotGrantRootAdminRole() public {
        // Check that a non-root-admin cannot grant the ROOT_ADMIN_ROLE
        string memory expectedError = _createOZAccessControlErrorMessage(someGuy(), 0x00);

        _manuallyTestGrantRoleError(expectedError, someGuy(), someOtherGuy(), _beamR.ROOT_ADMIN_ROLE());
    }

    function testRevert_updateUnits_UNAUTHORIZED() public {
        ISuperfluidPool pool = _createPool();

        // Check initial units
        assertEq(pool.getUnits(user1()), 5);
        assertEq(pool.getUnits(admin1()), 5);

        // Attempt to update user1's units to 10 by someGuy, who is not authorized
        BeamR.Member[] memory members = new BeamR.Member[](1);
        members[0] = IBeamR.Member({account: user1(), units: 10});

        address[] memory poolAddresses = new address[](1);
        poolAddresses[0] = address(pool);

        vm.startPrank(someGuy());
        vm.expectRevert(Unauthorized.selector);
        _beamR.updateMemberUnits(members, poolAddresses);
        vm.stopPrank();

        vm.startPrank(beamTeam());
        vm.expectRevert(Unauthorized.selector);
        _beamR.updateMemberUnits(members, poolAddresses);
        vm.stopPrank();
    }

    function testRevert_RescuePoolCreator_UNAUTHORIZED() public {
        ISuperfluidPool pool = _createPool();

        // Check that user1 is the creator of the pool
        // assertTrue(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user1()));
        // assertFalse(_beamR.hasRole(_beamR.poolAdminKey(address(pool)), user2()));

        string memory errorMessage = _createOZAccessControlErrorMessage(admin1(), _beamR.ROOT_ADMIN_ROLE());

        // Check that admin1 can rescue the pool creator
        vm.startPrank(admin1());
        vm.expectRevert(bytes(errorMessage));
        _beamR.rescuePoolCreator(address(pool), user2(), user1());
        vm.stopPrank();

        errorMessage = _createOZAccessControlErrorMessage(someGuy(), _beamR.ROOT_ADMIN_ROLE());

        vm.startPrank(someGuy());
        vm.expectRevert(bytes(errorMessage));
        _beamR.rescuePoolCreator(address(pool), user2(), user1());
        vm.stopPrank();
    }

    function testRevert_updateMetadata_UNAUTHORIZED() public {
        ISuperfluidPool pool = _createPool();

        // Attempt to update metadata by someGuy, who is not authorized

        string memory errorMessage = _createOZAccessControlErrorMessage(someGuy(), _beamR.poolAdminKey(address(pool)));

        vm.startPrank(someGuy());
        vm.expectRevert(bytes(errorMessage));
        _beamR.updateMetadata(address(pool), IBeamR.Metadata({protocol: 2, pointer: "https://new-metadata.com"}));
        vm.stopPrank();

        vm.startPrank(admin1());
        errorMessage = _createOZAccessControlErrorMessage(admin1(), _beamR.poolAdminKey(address(pool)));
        vm.expectRevert(bytes(errorMessage));
        _beamR.updateMetadata(address(pool), IBeamR.Metadata({protocol: 2, pointer: "https://new-metadata.com"}));
        vm.stopPrank();
    }

    //////////////////////////////////
    ///// UTILS /////////////////////
    /////////////////////////////////

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
            user1(),
            IBeamR.Metadata({protocol: 1, pointer: "https://beamr.io"})
        );
    }

    function _distributeFlow(ISuperfluidPool pool) internal {
        vm.startPrank(user1());
        gdaForwarder.distributeFlow(token, user1(), pool, 100, new bytes(0));

        vm.stopPrank();
    }

    function _setupHolders() internal {
        vm.startPrank(WHALE);
        token.transfer(user1(), 1_000e18);
        token.transfer(user2(), 1_000e18);
        vm.stopPrank();

        assertEq(token.balanceOf(user1()), 1_000e18);
    }

    function _createOZAccessControlErrorMessage(address account, bytes32 role) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(account),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )
        );
    }

    function _manuallyTestGrantRoleError(string memory _expectedError, address _from, address _to, bytes32 _role)
        internal
    {
        // Utility to manually test that grantRole() reverts with the exact expected
        // OpenZeppelin AccessControl string. This bypasses vm.expectRevert(), which
        // can be unreliable with string-based errors, by using try/catch to capture
        // the revert reason and assert equality against _expectedError.
        string memory revertReason;
        bool didRevert = false;

        vm.startPrank(_from);

        try _beamR.grantRole(_role, _to) {
            fail("Expected revert did not occur");
        } catch Error(string memory actualError) {
            didRevert = true;
            revertReason = actualError;
        } catch (bytes memory) {
            didRevert = true;
            revertReason = "Unknown error";
        }

        vm.stopPrank();

        assertTrue(didRevert, "Function should have reverted");
        assertEq(revertReason, _expectedError, "Wrong revert reason");
    }
}
