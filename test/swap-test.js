const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("liteSwap", function () {
  let
    deployer,
    Treasury,
    treasury,
    DummyToken,
    token,
    SwapFactory,
    factory,
    Swap,
    swap
      
  beforeEach(async() => {
    [
      deployer, 
      user1, 
      user2 
    ] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();
    
    Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(deployer.address);

    SwapFactory = await ethers.getContractFactory("SwapFactory");
    factory = await SwapFactory.deploy(treasury.address);

    DummyToken = await ethers.getContractFactory("DummyToken");
    token = await DummyToken.deploy();
    token1 = await DummyToken.deploy();

    Swap = await ethers.getContractFactory("Swap");
  });

  it("Proper compilation and setting", async function () {
    console.log("Contracts compiled and controller configured!");
  });

  it("Broadcast and execute", async function () {
    await factory.createSwap(token.address, token1.address);
    swap = await Swap.attach(await factory.swapAddress(token.address, token1.address));

    await token.mint('1000000000000000000000000000000000');
    await token1.connect(user1).mint('1000000000000000000000000000000000');

    await token.approve(swap.address, '1000000000000000000000000000000000');
    await token1.connect(user1).approve(swap.address, '1000000000000000000000000000000000');
    await swap.addCredit(token.address, '1000000000000000000000000000000000');

    await swap.broadcastBlockBid(
      token.address,
      100,
      10,
      20
    );

    let block = parseInt((await swap.getBlock()).toString());
    await swap.connect(user1).bidForBlock(
      token.address,
      token1.address,
      block + 3,
      10,
      20,
      50
    );
  });

  it("Claim reward", async function () {
    await factory.createSwap(token.address, token1.address);
    swap = await Swap.attach(await factory.swapAddress(token.address, token1.address));

    await token.mint('1000000000000000000000000000000000');
    await token1.connect(user1).mint('1000000000000000000000000000000000');

    await token.approve(swap.address, '1000000000000000000000000000000000');
    await token1.connect(user1).approve(swap.address, '1000000000000000000000000000000000');
    await swap.addCredit(token.address, '1000000000000000000000000000000000');

    console.log(`Broadcasting sale of 100000000 tokens at the price of ${10 / 20}/token...`);
    await swap.broadcastBlockBid(
      token.address,
      100000000,
      10,
      20
    );

    console.log("Successfully broadcasted!");

    console.log(`Broadcasting sale of 100000000 tokens at the price of ${200 / 20}/token...`);
    await swap.broadcastBlockBid(
      token.address,
      100000000,
      200,
      20
    );

    console.log("Successfully broadcasted!");

    let block = parseInt((await swap.getBlock()).toString());
    console.log(`Submitting bid for block ${block}...`);
    await swap.connect(user1).bidForBlock(
      token.address,
      token1.address,
      block + 3,
      10,
      20,
      50000000
    );

    console.log("Successfully submitted!");

    await network.provider.send("hardhat_mine", ["0x100"]);
    
    console.log("Claiming block reward...")
    await swap.connect(user1).claimBlockReward(
      token.address,
      [block + 3],
      [10],
      [20]
    );

    console.log("Successfully claimed!");

    console.log("Reclaiming failed order...")
    await swap.reclaimOrder(
      token.address,
      [block + 3],
      [200],
      [20]
    );

    console.log("Successfully claimed!");
  });
});