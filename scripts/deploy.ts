const { ethers, upgrades, network} = require("hardhat");








async function main() {
	// const [deployer, user_task_maker, user_reward1, user_reward2, user_reward3, user_reward4, user_reward5, user_reward6, user_reward7, user_reward8, user_reward9, user_reward10, user_reward11] = await ethers.getSigners();
	// const tether = await ethers.deployContract("Tether", [], {
	// });
	// const provider = ethers.provider;

	const [deployer] = await ethers.getSigners();

	const hikuruPiggyBank = "0x1bCec961363dC355558421E8a66423006aB75a25";
	console.log("Piggy Bank Address: ", hikuruPiggyBank)

	const hikuruFeeClaimer = "0xAb5266344F7784d2FCdEF1460dB9E047eC483204";
	console.log("Fee Claimer Address: ", hikuruFeeClaimer)

	// console.log("hikuruPiggyBank: ", ethers.formatEther(await provider.getBalance(hikuruPiggyBank)), "eth")

	// await tether.waitForDeployment();
	// console.log(`Tether deployed: ${tether.target}`);
	

	console.log("Deployer: ", deployer.address);
	console.log("Deploying HikuruQuestsFactoryV1.2...");


	// Transfer 1000 tokens to another address (replace with your recipient address)
	// await tether.mint(user_task_maker.address, ethers.parseUnits("1000", 18));


    const HikuruQuestsFactoryV1 = await ethers.getContractFactory("HikuruQuestsFactoryV1_2");
	const HikuruQuestsFactoryV1Contract = await upgrades.deployProxy(
        HikuruQuestsFactoryV1, 
        ["0x2D1CC54da76EE2aF14b289527CD026B417764fAB", hikuruPiggyBank, ethers.parseEther("0.002"), true, hikuruFeeClaimer],
    {
        initializer: "initialize",
        kind: "uups"
    });
	console.log(`HikuruQuestsFactoryV1 deployed: ${HikuruQuestsFactoryV1Contract.target}`);
	return;


	// //making approve Tether for HikuruQuestsFactoryV1
    // const TetherWithMaker = tether.connect(user_task_maker);
	// await TetherWithMaker.approve(HikuruQuestsFactoryV1Contract.target, ethers.parseUnits("500", 18));

	// console.log("- = - = - = - = - = - = - = - = - = - = - = - = -")

    // const HikuruPassportFactoryWithMaker = HikuruQuestsFactoryV1Contract.connect(user_task_maker);

	// const tx_maker = await HikuruPassportFactoryWithMaker["questCreation(string,string,uint256,uint256,uint256,uint256,uint256,uint256,address,bool,bool)"](
	// 	"_title",
	// 	"_description",
	// 	1,
	// 	new Date().getTime(),
	// 	1,
	// 	0,
	// 	ethers.parseUnits("50", 18),
	// 	ethers.parseUnits("150", 18),
	// 	tether.target,
	// 	true,
	// 	true,
    //     { value: ethers.parseEther("0.01")}
	// )
	
	// await tx_maker.wait()
    // console.log("Task created, TX hash: ", tx_maker.hash);

	// console.log(await HikuruQuestsFactoryV1Contract.quests(0))
	// console.log("HikuruQuestsFactoryV1.2 balance: ", ethers.formatEther(await tether.balanceOf(HikuruQuestsFactoryV1Contract.target))+"usdt");
	
	// for(const user of [user_reward1, user_reward2, user_reward3, user_reward4, user_reward5, user_reward6, user_reward7, user_reward8, user_reward9, user_reward10, user_reward11]){
	// 	const HikuruPassportFactoryWithReward2 = HikuruQuestsFactoryV1Contract.connect(user);
	// 	const tx_attand = await HikuruPassportFactoryWithReward2["acceptanceParticipation(uint256,address)"](0, user_reward1.address)
		
	// 	await tx_attand.wait()
	// 	console.log("Attend to Quests, TX hash: ", tx_attand.hash);
	// }

	// console.log("Quests: ", await HikuruQuestsFactoryV1Contract.quests(0))
	// console.log("Invited reffs: ", await HikuruQuestsFactoryV1Contract.getCountOfReferrals(0, user_reward1.address))
	// console.log("- = - = - = - = - = - = - = - = - = - = - = - = -")


    // const tx_find_winner = await HikuruQuestsFactoryV1Contract["selectRandomWinners(uint256)"](0)
	// await tx_find_winner.wait();

	// console.log("HikuruQuestsFactoryV1 balance: ", ethers.formatEther(await tether.balanceOf(HikuruQuestsFactoryV1Contract.target))+"usdt");


	// for(const user of [user_reward1, user_reward2, user_reward3, user_reward4, user_reward5, user_reward6, user_reward7, user_reward8, user_reward9, user_reward10, user_reward11]){
	// 	console.log(`${user.address} balance: `, ethers.formatEther(await tether.balanceOf(user.address))+"usdt");
	// }

	// console.log("\n\nQuest pool amount: ", ethers.formatEther(await HikuruQuestsFactoryV1Contract.getQuestRewardPool(0)));

	// console.log("hikuruPiggyBank: ", ethers.formatEther(await provider.getBalance(hikuruPiggyBank)), "eth")
	// console.log("hikuruPiggyBank balance: ", ethers.formatEther(await tether.balanceOf(hikuruPiggyBank))+"usdt");

}




// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
