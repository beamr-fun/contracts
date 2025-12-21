// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BeamR} from "../src/contracts/BeamR.sol";

contract DeployBeamRProxy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRI_K");

        vm.startBroadcast(deployerPrivateKey);

        BeamR implementation = new BeamR();
        address[] memory admins = new address[](2);
        address[] memory rootAdmins = new address[](1);

        admins[0] = vm.envAddress("PUB_K");
        admins[1] = vm.envAddress("DEV_PUB_K");

        rootAdmins[0] = vm.envAddress("DEV_PUB_K");

        string memory initSig = "initialize(address[],address[])";
        bytes memory initCalldata = abi.encodeWithSignature(initSig, admins, rootAdmins);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initCalldata);

        vm.stopBroadcast();

        console2.log("BeamR implementation deployed at:", address(implementation));
        console2.log("BeamR proxy deployed at:", address(proxy));
    }
}
