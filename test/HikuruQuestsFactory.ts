const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");


async function waitForTwoSeconds() {
  return new Promise(resolve => {
    setTimeout(resolve, 2000); // 2000 milliseconds = 2 seconds
  });
}

describe("HikuruQuestsFactoryV1_2", function () {
  let deployer, user_task_maker: { address: any; }, user_reward1: { address: any; }, user_reward2: any, user_reward3, user_reward4, user_reward5, user_reward6, user_reward7, user_reward8, user_reward9, user_reward10, user_reward11;
  let tether: {
    [x: string]: any; waitForDeployment: () => any; target: any; mint: (arg0: any, arg1: any) => any; connect: (arg0: any) => any; 
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
  });

  it('HikuruQuestsFactoryV1 deployment', async function () {
    expect(HikuruQuestsFactoryV1Contract.target).to.not.be.equal("0x0000000000000000000000000000000000000000");
  });


  it('Quest creation with Tether fee + reward', async function () {
   questCount+=1;
    const user_task_makerUSDTBalance = await tether.balanceOf(user_task_maker.address);
    const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
    const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
      tether.target,
      1,
      Math.floor((new Date().getTime())/1000),
      Math.floor((new Date().getTime()+500000)/1000),
      questCount,
      0,
      ethers.parseUnits("10", stableDecimal),
      ethers.parseUnits("10", stableDecimal),
      tether.target,
      true,
      true,
      {}
    )
    
    //Check transaction Hash
    await tx_maker.wait()
    expect(tx_maker.hash).to.not.be.equal("0x00000000000000000000000000000000000000000000000000000000000000");

    // check is contract quest id is increamented
    expect(await HikuruPassportFactoryWithMaker.getQuestCount()).to.equal(questCount);


    let quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    expect(quest.participantsCount).to.be.equal(0);

    const participantsAcc = [user_reward1]

    const user_reward1USDTBalance = await tether.balanceOf(user_reward1.address);


    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user_reward1.address)
      await tx_attand.wait()
    }



    const tx_find_winner = await HikuruQuestsFactoryV1Contract["FinishQuest(uint256,uint256[])"](questCount,[1,2,3,4,5,6])
    await tx_find_winner.wait();


    quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    // Check is Participants increased
    expect(quest.participantsCount).to.be.equal(1);
    // Chekc is Completed
    expect(quest.isCompleted).to.be.true;

    expect(ethers.formatUnits(await tether.balanceOf(user_reward1.address)-user_reward1USDTBalance), stableDecimal).to.be.equal("10.0")
  
    //check - refund of balances (nothing to refund just minus value) (10 usdt reward and 10 usdt fees)
    expect(ethers.formatUnits(await tether.balanceOf(user_task_maker.address)-user_task_makerUSDTBalance), stableDecimal).to.be.equal("-20.0");
  });

  it('Quest creation with Native fee + reward', async function () {
   questCount+=1;
    const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
    const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
      1,
      Math.floor((new Date().getTime())/1000),
      Math.floor((new Date().getTime()+500000)/1000),
      questCount,
      0,
      ethers.parseUnits("10", stableDecimal),
      ethers.parseUnits("50", stableDecimal),
      tether.target,
      true,
      true,
      { value: ethers.parseEther("0.01") }
    )
    
    //Check transaction Hash
    await tx_maker.wait()
    expect(tx_maker.hash).to.not.be.equal("0x00000000000000000000000000000000000000000000000000000000000000");
    
    // check is contract quest id is increamented
    expect(await HikuruPassportFactoryWithMaker.getQuestCount()).to.equal(questCount);

    let quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    expect(quest.participantsCount).to.be.equal(0);
    
    const participantsAcc = [user_reward1]

    const user_reward1USDTBalance = await tether.balanceOf(user_reward1.address);
    const user_task_makerUSDTBalance = await tether.balanceOf(user_task_maker.address);


    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user_reward1.address)
      await tx_attand.wait()
    }


    const tx_find_winner = await HikuruQuestsFactoryV1Contract["FinishQuest(uint256,uint256[])"](questCount,[1,5,8])
    await tx_find_winner.wait();

    quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    // Check is Participants increased
    expect(quest.participantsCount).to.be.equal(1);
    // Chekc is Completed
    expect(quest.isCompleted).to.be.true;

    expect(ethers.formatUnits(await tether.balanceOf(user_reward1.address)-user_reward1USDTBalance), stableDecimal).to.be.equal("10.0");


    //check - refund of balances 
    expect(ethers.formatUnits(await tether.balanceOf(user_task_maker.address)-user_task_makerUSDTBalance), stableDecimal).to.be.equal("40.0");
  

  });


  it('Dont allow to acceptanceParticipation if Quest Ended',  async function () {
    const participantsAcc = [user_reward2]
    try {
      for(const user of participantsAcc){
        const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
        const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user_reward1.address)
        await tx_attand.wait()
      }
      expect.fail('Transaction should have thrown an error');

    } catch (error) {
      // All good 
    }
  });


  it('Dont allow to acceptanceParticipation twice',  async function () {
   questCount+=1;
    const participantsAcc = [user_reward2, user_reward2];

    const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
    const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
      1,
      Math.floor((new Date().getTime())/1000),
      Math.floor((new Date().getTime()+500000)/1000),
      questCount,
      0,
      ethers.parseUnits("10", stableDecimal),
      ethers.parseUnits("10", stableDecimal),
      tether.target,
      true,
      true,
      { value: ethers.parseEther("0.01") }
    )

    try {
      for(const user of participantsAcc){
        const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
        const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user_reward1.address)
        await tx_attand.wait()
      }
      expect.fail('Transaction should have thrown an error');

    } catch (error) {
      // All good 
    }
  });



  it('Quest creation with Tether fee without reward', async function () {
    questCount+=1;
    const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);
    const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
      tether.target,
      1,
      Math.floor((new Date().getTime())/1000),
      Math.floor((new Date().getTime()+500000)/1000),
      questCount,
      0,
      ethers.parseUnits("10", stableDecimal),
      ethers.parseUnits("100", stableDecimal),
      "0x0000000000000000000000000000000000000000",
      false,
      true,
      { value: ethers.parseEther("0.01")}
    )
    
    //Check transaction Hash
    await tx_maker.wait()
    expect(tx_maker.hash).to.not.be.equal("0x00000000000000000000000000000000000000000000000000000000000000");


    // check is contract quest id is increamented
    expect(await HikuruPassportFactoryWithMaker.getQuestCount()).to.equal(questCount);


    let quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    expect(quest.participantsCount).to.be.equal(0);

    // Check is Contract Dont take User tether's  - total pool should be 0
    expect(ethers.formatUnits(quest.totalRewardPool, stableDecimal)).to.be.equal("0.0");

    const participantsAcc = [user_reward1]

    const user_reward1USDTBalance = await tether.balanceOf(user_reward1.address);


    for(const user of participantsAcc){
      const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
      const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](questCount, user_reward1.address)
      await tx_attand.wait()
    }


    const tx_find_winner = await HikuruQuestsFactoryV1Contract["FinishQuest(uint256,uint256[])"](questCount,[2,4,6])
    await tx_find_winner.wait();


    quest = await HikuruPassportFactoryWithMaker.quests(questCount);
    // Check is Participants increased
    expect(quest.participantsCount).to.be.equal(1);
    // Chekc is Completed
    expect(quest.isCompleted).to.be.true;

    expect(ethers.formatUnits(await tether.balanceOf(user_reward1.address)-user_reward1USDTBalance), stableDecimal).to.be.equal("0.0")
  
  });

});
