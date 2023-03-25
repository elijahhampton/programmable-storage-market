require("hardhat-deploy")
require("hardhat-deploy-ethers")
import 'hardhat-deploy'
import 'hardhat-deploy-ethers'
import { ethers, network } from 'hardhat'

import { networkConfig } from '../helper-hardhat-config'
import { Ubique } from '../typechain-types'

//@ts-ignore
const private_key: string = network.config.accounts[0]
const wallet = new ethers.Wallet(private_key, ethers.provider)

module.exports = async ({ deployments }: { deployments: any}) => {
    console.log("Wallet Ethereum Address:", wallet.address)
    const chainId: number | undefined = network.config.chainId

    //deploy FilecoinMarketConsumer
    const Ubique = await ethers.getContractFactory('Ubique', wallet);
    console.log('Deploying Ubique...');
    const ubique: Ubique = await Ubique.deploy();
    await ubique.deployed()
    //@ts-ignore
    console.log('Ubique deployed to:', ubique.address);
}