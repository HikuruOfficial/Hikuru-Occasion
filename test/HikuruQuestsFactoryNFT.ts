const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

async function waitForTwoSeconds() {
  return new Promise(resolve => {
    setTimeout(resolve, 2000); // 2000 milliseconds = 2 seconds
  });
}

describe("HikuruQuestsFactoryV1_2", function () {
  let deployer: { address: any; }, user_task_maker: { address: any; }, user_reward1: { address: any; }, user_reward2: any, user_reward3: any, user_reward4, user_reward5, user_reward6, user_reward7, user_reward8, user_reward9, user_reward10, user_reward11;
  let tether: {
    [x: string]: any; waitForDeployment: () => any; target: any; mint: (arg0: any, arg1: any) => any; connect: (arg0: any) => any; 
};
let nft: {
  [x: string]: any; waitForDeployment: () => any; target: any; owner: () => any; 
};
  let provider;
  let hikuruPiggyBank;
  let stableDecimal: number;
  let HikuruQuestsFactoryV1Contract: {
    [x: string]: any; target: any; 
};
  let questCount = 0;

  before(async () => {
    [deployer, user_task_maker, user_reward1, user_reward2, user_reward3, user_reward4, user_reward5, user_reward6, user_reward7, user_reward8, user_reward9, user_reward10, user_reward11] = await ethers.getSigners();
    tether = await ethers.deployContract("Tether", []);
    provider = ethers.provider;
    hikuruPiggyBank = "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707";
    stableDecimal = 18;

    console.log("Piggy Bank Address: ", hikuruPiggyBank);
    console.log("hikuruPiggyBank: ", ethers.formatEther(await provider.getBalance(hikuruPiggyBank)), "eth");

    await tether.waitForDeployment();
    console.log(`Tether deployed: ${tether.target}`);

    // Transfer 1000 tokens to another address (replace with your recipient address)
    await tether.mint(user_task_maker.address, ethers.parseUnits("1000", stableDecimal));

    const HikuruQuestsFactoryV1 = await ethers.getContractFactory("HikuruQuestsFactoryV1_2");
    HikuruQuestsFactoryV1Contract = await upgrades.deployProxy(
      HikuruQuestsFactoryV1,
      [deployer.address, hikuruPiggyBank, ethers.parseEther("0.01"), true, ethers.parseUnits("10", stableDecimal), [tether.target]],
      {
        initializer: "initialize",
        kind: "uups"
      }
    );


    //making approve Tether for HikuruQuestsFactoryV1
    const TetherWithMaker = tether.connect(user_task_maker);
    await TetherWithMaker.approve(HikuruQuestsFactoryV1Contract.target, ethers.parseUnits("1000", stableDecimal));


    nft = await ethers.deployContract("HikuruNFT", [HikuruQuestsFactoryV1Contract.target, "TestName", "SYM", 10, deployer.address, "23"]);
    await nft.waitForDeployment();
    console.log(`nft deployed: ${nft.target}`);
  });

  it('HikuruQuestsFactoryV1 deployment', async function () {
    expect(HikuruQuestsFactoryV1Contract.target).to.not.be.equal("0x0000000000000000000000000000000000000000");
    console.log("HikuruQuestsFactoryV1Contract: ", HikuruQuestsFactoryV1Contract.target)
  });

  it('HikuruQuestsFactoryV1 owner of NFT', async function () {
    expect(await nft.hasRole("0x0000000000000000000000000000000000000000000000000000000000000000", HikuruQuestsFactoryV1Contract.target)).to.be.true
  });

  it('AcceptanceParticipation with Our NFT ownership',  async function () {
    questCount+=1;
     const participantsAcc = [user_reward1, user_reward2, user_reward3];
 
     const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
     const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
      tether.target,
      3,
      Math.floor((new Date().getTime())/1000),
      Math.floor((new Date().getTime()+650000)/1000),
      questCount,
       10,
       1,
       10,
       nft.target,
       true,
       true,
       { value: ethers.parseEther("0.01") }
     )
 
    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user.address)
      await tx_attand.wait()
    }

    // user should have 1 nft
    const nft_balance1 = await nft.balanceOf(user_reward1.address, 1);
    expect(nft_balance1).to.be.equal(1);

    const nft_balance2 = await nft.balanceOf(user_reward2.address, 2);
    expect(nft_balance2).to.be.equal(1);    

    const nft_balance3 = await nft.balanceOf(user_reward3.address, 3);
    expect(nft_balance3).to.be.equal(1);


    try {
      for(const user of participantsAcc){
        const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
        const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user.address)
        await tx_attand.wait()
      }
      expect.fail('Transaction should have thrown an error');

    } catch (error) {
      // All good 
    }

  });




  it('AcceptanceParticipation not Our',  async function () {
    questCount+=1;
     const participantsAcc = [user_reward2];

     const nft2 = await ethers.deployContract("HikuruNFT", [user_task_maker.address, "TestName2", "SYM2", 10, deployer.address, "232"]);
     await nft2.waitForDeployment();


     const nft2WithMaker = nft2.connect(user_task_maker);
     await nft2WithMaker.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", HikuruQuestsFactoryV1Contract.target);


     const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
     const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
       3,
       Math.floor((new Date().getTime())/1000),
       Math.floor((new Date().getTime()+650000)/1000),
       questCount,
       10,
       1,
       10,
       nft2.target,
       true,
       true,
       { value: ethers.parseEther("0.01") }
     )
 
    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user.address)
      await tx_attand.wait()
    }

    // user should have 1 nft
    const nft_balance = await nft2.balanceOf(user_reward2.address, 1);
    expect(nft_balance).to.be.equal(1);


  });


  it('AcceptanceParticipation - RANDOM Winner',  async function () {
    questCount+=1;
     const participantsAcc = [user_reward1, user_reward2, user_reward3];


     const nft3 = await ethers.deployContract("HikuruNFT", [user_task_maker.address, "TestName2", "SYM2", 10, deployer.address, "232"]);
     await nft3.waitForDeployment();


     const nft2WithMaker = nft3.connect(user_task_maker);
     await nft2WithMaker.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", HikuruQuestsFactoryV1Contract.target);
 
     const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
     const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
       4,
       Math.floor((new Date().getTime())/1000),
       Math.floor((new Date().getTime()+650000)/1000),
       questCount,
       3,
       1,
       3,
       nft3.target,
       true,
       true,
       { value: ethers.parseEther("0.01") }
     )
 
    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user.address)
      await tx_attand.wait()
    }



    try {
      for(const user of participantsAcc){
        const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
        const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user.address)
        await tx_attand.wait()
      }
      expect.fail('Transaction should have thrown an error');

    } catch (error) {
      // All good 
    }



    const tx_find_winner = await HikuruQuestsFactoryV1Contract["FinishQuest(uint256,uint256[])"](questCount,[1,2,3])
    await tx_find_winner.wait();

    const quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    // Check is Participants increased
    expect(quest.participantsCount).to.be.equal(3);
    // Chekc is Completed
    expect(quest.isCompleted).to.be.true;


    // user should have 1 nft
    const nft_balance1 = await nft3.balanceOf(user_reward1.address, 1) || await nft3.balanceOf(user_reward1.address, 2) || await nft3.balanceOf(user_reward1.address, 3);
    expect(nft_balance1).to.be.equal(1);

    const nft_balance2 = await nft3.balanceOf(user_reward2.address, 1) || await nft3.balanceOf(user_reward2.address, 2) || await nft3.balanceOf(user_reward2.address, 3);
    expect(nft_balance2).to.be.equal(1);    

    const nft_balance3 = await nft3.balanceOf(user_reward3.address, 1) || await nft3.balanceOf(user_reward3.address, 2) || await nft3.balanceOf(user_reward3.address, 3);
    expect(nft_balance3).to.be.equal(1);


    expect(quest.participantsCount).to.equal(3);
    expect(quest.totalRewardPool).to.equal(0);
  });

  it('AcceptanceParticipation - RANDOM Winner One User',  async function () {
    questCount+=1;
     const participantsAcc = [user_reward1];


     const nft3 = await ethers.deployContract("HikuruNFT", [user_task_maker.address, "TestName2", "SYM2", 10, deployer.address, "232"]);
     await nft3.waitForDeployment();


     const nft2WithMaker = nft3.connect(user_task_maker);
     await nft2WithMaker.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", HikuruQuestsFactoryV1Contract.target);
 


     const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
     const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
       4,
       Math.floor((new Date().getTime())/1000),
       Math.floor((new Date().getTime()+650000)/1000),
       questCount,
       3,
       1,
       5,
       nft3.target,
       true,
       true,
       { value: ethers.parseEther("0.01") }
     )
 
    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user.address)
      await tx_attand.wait()
    }



    const tx_find_winner = await HikuruQuestsFactoryV1Contract["FinishQuest(uint256,uint256[])"](questCount,[0])
    await tx_find_winner.wait();

    const quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    // Check is Participants increased
    expect(quest.isCompleted).to.be.true;


    // user should have 1 nft
    const nft_balance1 = await nft3.balanceOf(user_reward1.address, 1) || await nft3.balanceOf(user_reward1.address, 2) || await nft3.balanceOf(user_reward1.address, 3) || await nft3.balanceOf(user_reward1.address, 4) || await nft3.balanceOf(user_reward1.address, 5);
    expect(nft_balance1).to.be.equal(1);


    expect(quest.participantsCount).to.equal(1);
    expect(quest.totalRewardPool).to.equal(4);
  });

});
