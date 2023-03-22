import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.0"
      },
      {
        version: "0.8.4"
      },
      {
        version: "0.8.17"
      },
      {
        version: "0.8.19"
      }
    ]
  },
};

export default config;
