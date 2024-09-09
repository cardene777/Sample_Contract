```js
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import hre from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'

describe('MyONFT721 Test', function () {
    const { deployments } = hre
    const eidA = 1
    const eidB = 2
    let MyONFT721: ContractFactory
    let EndpointV2Mock: ContractFactory
    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let aONFT: Contract
    let bONFT: Contract
    let mockEndpointA: Contract
    let mockEndpointB: Contract

    before(async function () {
        MyONFT721 = await hre.ethers.getContractFactory('MyONFT721Mock')

        const signers = await hre.ethers.getSigners()
        ownerA = signers[0]
        ownerB = signers[1]
        endpointOwner = signers[2]

        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2ONFT721Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    beforeEach(async function () {
        mockEndpointA = await EndpointV2Mock.deploy(eidA)
        mockEndpointB = await EndpointV2Mock.deploy(eidB)

        aONFT = await MyONFT721.deploy('aONFT', 'aONFT', mockEndpointA.address, ownerA.address)
        bONFT = await MyONFT721.deploy('bONFT', 'bONFT', mockEndpointB.address, ownerB.address)

        await mockEndpointA.setDestLzEndpoint(bONFT.address, mockEndpointB.address)
        await mockEndpointB.setDestLzEndpoint(aONFT.address, mockEndpointA.address)

        await aONFT.connect(ownerA).setPeer(eidB, hre.ethers.utils.hexZeroPad(bONFT.address, 32))
        await bONFT.connect(ownerB).setPeer(eidA, hre.ethers.utils.hexZeroPad(aONFT.address, 32))
    })

    it('should send a token from A address to B address via each ONFT721', async function () {
        const tokenId = 1
        await aONFT.connect(ownerA).mint(ownerA.address, tokenId)

        // const executorOption = hre.ethers.utils.defaultAbiCoder.encode(
        //     ['uint8', 'uint128'], // _optionTypeを16ビットで指定
        //     [1, 50000] // 1 = 有効なオプションタイプ（TYPE_1）、50000 = ガスリミット
        // )
        const executorOption = Options.newOptions().addExecutorComposeOption(1, 200000, 0).toHex().toString()

        const sendParam = {
            dstEid: eidB,
            to: hre.ethers.utils.hexZeroPad(ownerB.address, 32),
            tokenId: tokenId,
            extraOptions: executorOption,
            composeMsg: [],
            onftCmd: [],
        }

        console.log(sendParam)

        const msgFee = {
            nativeFee: hre.ethers.utils.parseEther('0.1'),
            lzTokenFee: hre.ethers.utils.parseEther('0'),
        }

        console.log(msgFee)

        await aONFT.connect(ownerA).send(sendParam, msgFee, ownerA.address, { value: msgFee.nativeFee })

        console.log('sent')

        const ownerAFinalBalance = await aONFT.balanceOf(ownerA.address)
        const ownerBFinalBalance = await bONFT.balanceOf(ownerB.address)

        expect(ownerAFinalBalance).to.equal(0)
        expect(ownerBFinalBalance).to.equal(1)
    })
})
```






```js
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import hre from 'hardhat'
import Web3 from 'web3'

const web3 = new Web3()

describe('ONFT721: ', function () {
    const chainId_A = 1
    const chainId_B = 2
    const name = 'OmnichainNonFungibleToken'
    const symbol = 'ONFT'
    const minGasToStore = 150000
    const batchSizeLimit = 300
    const defaultAdapterParams = hre.ethers.utils.solidityPack(['uint16', 'uint256'], [1, 200000])

    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let warlock: SignerWithAddress
    let lzEndpointMockA: Contract
    let lzEndpointMockB: Contract
    let LZEndpointMock: ContractFactory
    let ONFT: ContractFactory
    let ONFT_A: Contract
    let ONFT_B: Contract

    before(async function () {
        console.log('getSigners')
        const signers = await hre.ethers.getSigners()
        ownerA = signers[0]
        console.log('ownerA', ownerA.address)
        ownerB = signers[1]
        warlock = signers[2]
        console.log('warlock', warlock.address)
        LZEndpointMock = await hre.ethers.getContractFactory('LZEndpointMock')
        ONFT = await hre.ethers.getContractFactory('MyONFT721Mock')
    })

    beforeEach(async function () {
        lzEndpointMockA = await LZEndpointMock.deploy(chainId_A)
        lzEndpointMockB = await LZEndpointMock.deploy(chainId_B)
        console.log('lzEndpointMockA', lzEndpointMockA.address)
        console.log('lzEndpointMockB', lzEndpointMockB.address)

        // generate a proxy to allow it to go ONFT
        ONFT_A = await ONFT.deploy(name, symbol, lzEndpointMockA.address, warlock.address)
        ONFT_B = await ONFT.deploy(name, symbol, lzEndpointMockB.address, warlock.address)

        console.log('ONFT_A', ONFT_A.address)
        console.log('ONFT_B', ONFT_B.address)

        // wire the lz endpoints to guide msgs back and forth
        lzEndpointMockA.setDestLzEndpoint(ONFT_B.address, lzEndpointMockB.address)
        lzEndpointMockB.setDestLzEndpoint(ONFT_A.address, lzEndpointMockA.address)

        console.log('ok setDestLzEndpoint')

        // set each contracts source address so it can send to each other
        await ONFT_A.setTrustedRemote(
            chainId_B,
            hre.ethers.utils.solidityPack(['address', 'address'], [ONFT_B.address, ONFT_A.address])
        )
        await ONFT_B.setTrustedRemote(
            chainId_A,
            hre.ethers.utils.solidityPack(['address', 'address'], [ONFT_A.address, ONFT_B.address])
        )

        console.log('ok setTrustedRemote')

        // set batch size limit
        await ONFT_A.setDstChainIdToBatchLimit(chainId_B, batchSizeLimit)
        await ONFT_B.setDstChainIdToBatchLimit(chainId_A, batchSizeLimit)

        console.log('ok setDstChainIdToBatchLimit')

        // set min dst gas for swap
        await ONFT_A.setMinDstGas(chainId_B, 1, 150000)
        await ONFT_B.setMinDstGas(chainId_A, 1, 150000)

        console.log('ok setMinDstGas')
    })

    it('sendFrom() - your own tokens', async function () {
        const tokenId = 123
        await ONFT_A.mint(ownerA.address, tokenId)

        // verify the owner of the token is on the source chain
        expect(await ONFT_A.ownerOf(tokenId)).to.be.equal(ownerA.address)

        // token doesn't exist on other chain
        await expect(ONFT_B.ownerOf(tokenId)).to.be.rejectedWith('ERC721: invalid token ID')

        // can transfer token on srcChain as regular erC721
        await ONFT_A.transferFrom(ownerA.address, warlock.address, tokenId)
        expect(await ONFT_A.ownerOf(tokenId)).to.be.equal(warlock.address)

        // approve the proxy to swap your token
        await ONFT_A.connect(warlock).approve(ONFT_A.address, tokenId)

        // estimate nativeFees
        let nativeFee = (await ONFT_A.estimateSendFee(chainId_B, warlock.address, tokenId, false, defaultAdapterParams))
            .nativeFee

        // swaps token to other chain
        await ONFT_A.connect(warlock).sendFrom(
            warlock.address,
            chainId_B,
            warlock.address,
            tokenId,
            warlock.address,
            hre.ethers.constants.AddressZero,
            defaultAdapterParams,
            { value: nativeFee }
        )

        // token is burnt
        expect(await ONFT_A.ownerOf(tokenId)).to.be.equal(ONFT_A.address)

        // token received on the dst chain
        expect(await ONFT_B.ownerOf(tokenId)).to.be.equal(warlock.address)

        // estimate nativeFees
        nativeFee = (await ONFT_B.estimateSendFee(chainId_A, warlock.address, tokenId, false, defaultAdapterParams))
            .nativeFee

        // can send to other onft contract eg. not the original nft contract chain
        await ONFT_B.connect(warlock).sendFrom(
            warlock.address,
            chainId_A,
            warlock.address,
            tokenId,
            warlock.address,
            hre.ethers.constants.AddressZero,
            defaultAdapterParams,
            { value: nativeFee }
        )

        // token is burned on the sending chain
        expect(await ONFT_B.ownerOf(tokenId)).to.be.equal(ONFT_B.address)
    })

    it('sendFrom() - on behalf of other user', async function () {
        const tokenId = 123
        await ONFT_A.mint(ownerA.address, tokenId)

        // approve the proxy to swap your token
        await ONFT_A.approve(ONFT_A.address, tokenId)

        // estimate nativeFees
        let nativeFee = (await ONFT_A.estimateSendFee(chainId_B, ownerA.address, tokenId, false, defaultAdapterParams))
            .nativeFee

        // swaps token to other chain
        await ONFT_A.sendFrom(
            ownerA.address,
            chainId_B,
            ownerA.address,
            tokenId,
            ownerA.address,
            hre.ethers.constants.AddressZero,
            defaultAdapterParams,
            {
                value: nativeFee,
            }
        )

        // token received on the dst chain
        expect(await ONFT_B.ownerOf(tokenId)).to.be.equal(ownerA.address)

        // approve the other user to send the token
        await ONFT_B.approve(warlock.address, tokenId)

        // estimate nativeFees
        nativeFee = (await ONFT_B.estimateSendFee(chainId_A, warlock.address, tokenId, false, defaultAdapterParams))
            .nativeFee

        // sends across
        await ONFT_B.connect(warlock).sendFrom(
            ownerA.address,
            chainId_A,
            warlock.address,
            tokenId,
            warlock.address,
            hre.ethers.constants.AddressZero,
            defaultAdapterParams,
            { value: nativeFee }
        )

        // token received on the dst chain
        expect(await ONFT_A.ownerOf(tokenId)).to.be.equal(warlock.address)
    })
})

```
