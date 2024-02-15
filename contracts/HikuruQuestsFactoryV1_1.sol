// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "hardhat/console.sol";



interface IERC1155Mintable is IERC1155 {
    /**
     * @dev Mints `amount` tokens of token type `id` to `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement `IERC1155Receiver.onERC1155Received`.
     */
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

    /**
     * @dev Batch version of {mint}.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
}





//make domain
// make sign vertif
contract HikuruQuestsFactoryV1_1 is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Holder {
    using SafeERC20 for IERC20; 


    struct Quest {
        address payable creator;
        address rewardContract;
        uint256 questsRewardType;
        uint256 endTime;
        uint256 hikuruQid;
        uint256 maxParticipation;
        uint256 participantsCount;
        uint256 maxRewardPerUser;
        uint256 totalRewardPool;
        address[] participantsList;
        mapping(address => bool) participants;
        mapping(address => bool) hasReceivedReward;
        mapping (address => uint256) referrals; // username who invite participants
        bool isCompleted;
        bool withReward;
        bool referralSystem;
    }
    
    // Reward Types:
    // 1 - ERC20
    // 2 - ERC721
    // 3 - ERC1155 - reward for every user
    // 4 - ERC1155 - reward for random selected (maxParticipant) users


    mapping(uint256 => Quest) public quests;
    uint256 private _questCount;
    uint256 private _creationQuestFee;  // Creation fee in terms of native
    bool private _allowedAcceptStable;  // Switcher is Stable is Allowed to pay fees
    uint256 private _creationQuestFeeStable;  // Creation fee in terms of native
    mapping(address => bool) private _isAcceptedToken; // Which ERC20 tokens are accepted for the registration fee

    address payable private _hikuruPiggyBank; // Address where will transfered funds
    

    // Event for quest creation
    event HikuruPiggyBankUpdated(address indexed newPiggyBank);
    event QuestCreated(uint256 questId, address creator, uint256 HikuruQuestId);
    event QuestModified(uint256 questId, address creator, uint256 HikuruQuestId);
    event UserParticipated(uint256 questId, address user);
    event WinnerSelected(uint256 questId, address winner);
    event RewardDistributed(uint256 questId, address recipient, uint256 amount);
    event FundsReturned(uint256 questId, address creator, uint256 amount);
    event ForcedFinish(uint256 questId, address owner_or_creator);

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyOwnerOrQuestCreator(uint256 _questId) {
        require(msg.sender == owner() || msg.sender == quests[_questId].creator, "Permission denied");
        _;
    }

    function initialize(address initialOwner, address payable _newPiggyBank, uint256 _newCreationQuestFee, bool _newAllowedAcceptStable, uint256 _newCreationQuestFeeStable, address[] memory _initialAcceptedTokens) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        _hikuruPiggyBank = _newPiggyBank;
        _creationQuestFee = (_newCreationQuestFee != 0) ? _newCreationQuestFee : 0.01 ether;
        _allowedAcceptStable = _newAllowedAcceptStable;
        _creationQuestFeeStable = _newCreationQuestFeeStable;

        // Set initial accepted tokens
        for (uint256 i = 0; i < _initialAcceptedTokens.length; i++) {
            _isAcceptedToken[_initialAcceptedTokens[i]] = true;
        }
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    
    function setCreationFee(uint256 _newCreationQuestFee) external onlyOwner {
        _creationQuestFee = _newCreationQuestFee;
    }


    // Update stable function's
    function setAllowedAcceptStable(bool _newAllowedAcceptStable) external onlyOwner {
        _allowedAcceptStable = _newAllowedAcceptStable;
    }

    function setCreationFeeStable(uint256 _newCreationQuestFeeStable) external onlyOwner {
        _creationQuestFeeStable = _newCreationQuestFeeStable;
    }

    function setAcceptedToken(address _token, bool _isAccepted) external onlyOwner {
        _isAcceptedToken[_token] = _isAccepted;
    }


    function setHikuruPiggyBank(address payable _newPiggyBank) external onlyOwner {
        require(_newPiggyBank != address(0), "New piggy bank is the zero address");
        _hikuruPiggyBank = _newPiggyBank;
        emit HikuruPiggyBankUpdated(_newPiggyBank);
    }

    // Native transfer
    function questCreation(
        uint256 _questsRewardType,
        uint256 _endTime,
        uint256 _hikuruQid,
        uint256 _maxParticipation,
        uint256 _maxRewardPerUser,
        uint256 _totalRewardPool,
        address _rewardContract,
        bool _withReward,
        bool _referralSystem
    ) external payable whenNotPaused {
        require(msg.value >= _creationQuestFee, "Creation fee not met");

        // Transfer the quest creation fee to hikuru piggy bank
        (bool feeTransferSuccess, ) = _hikuruPiggyBank.call{value: msg.value}("");
        require(feeTransferSuccess, "Fee transfer failed");
        
        // Common quest creation logic
        commonQuestCreation(
            _questsRewardType,
            _endTime,
            _hikuruQid,
            _maxParticipation,
            _maxRewardPerUser,
            _totalRewardPool,
            _rewardContract,
            _withReward,
            _referralSystem
        );
    }

    // Stable Token transfer
    function questCreation(
        IERC20 stableToken,
        uint256 _questsRewardType,
        uint256 _endTime,
        uint256 _hikuruQid,
        uint256 _maxParticipation,
        uint256 _maxRewardPerUser,
        uint256 _totalRewardPool,
        address _rewardContract,
        bool _withReward,
        bool _referralSystem
    ) external payable whenNotPaused {
        require(_allowedAcceptStable, "Token not accepted");
        require(_isAcceptedToken[address(stableToken)], "Token not accepted");
        
        uint256 userBalance = stableToken.balanceOf(msg.sender);
        require(userBalance >= _creationQuestFeeStable, "Insufficient tfee balance");
        require(stableToken.allowance(msg.sender, address(this)) >= _creationQuestFeeStable, "Token allowance too low");
        
        if(_questsRewardType==1){
            // Transfer tokens instead of ether
            bool tokenTransferSuccess = IERC20(stableToken).transferFrom(msg.sender, _hikuruPiggyBank, _creationQuestFeeStable);
            require(tokenTransferSuccess, "Reward transfer failed");
        }

        // Common quest creation logic
        commonQuestCreation(
            _questsRewardType,
            _endTime,
            _hikuruQid,
            _maxParticipation,
            _maxRewardPerUser,
            _totalRewardPool,
            _rewardContract,
            _withReward,
            _referralSystem
        );
    }


    //HIDDEN only allowed run from this contract
    function commonQuestCreation(
        uint256 _questsRewardType,
        uint256 _endTime,
        uint256 _hikuruQid,
        uint256 _maxParticipation,
        uint256 _maxRewardPerUser,
        uint256 _totalRewardPool,
        address _rewardContract,
        bool _withReward,
        bool _referralSystem
    ) internal {

        require((_withReward && _rewardContract != address(0)) || (!_withReward && _rewardContract == address(0)), "Invalid reward configuration");
        require(_endTime > block.timestamp, "End time must be in the future");
        require(_totalRewardPool >= _maxRewardPerUser, "Insufficient reward pool");

        // Trnsfer Full Reward Now to the contract
        if (_withReward && _rewardContract != address(0)) {

            if(_questsRewardType==1){
                uint256 userBalance = IERC20(_rewardContract).balanceOf(msg.sender);
                require(userBalance >= _totalRewardPool, "Insufficient token balance");
                require(_totalRewardPool > 0, "TotalRewardPool isnt natural");

                require(IERC20(_rewardContract).allowance(msg.sender, address(this)) >= _totalRewardPool, "Token allowance too low");
                
                bool successTransfer = IERC20(_rewardContract).transferFrom(msg.sender, address(this), _totalRewardPool);
                require(successTransfer, "Transfer of ERC20 tokens failed");
            }
            else if(_questsRewardType==3 || _questsRewardType==4){
                require(IERC1155Mintable(_rewardContract).supportsInterface(type(IERC1155).interfaceId), "Contract does not support ERC1155");
                require(_maxParticipation<=_totalRewardPool, "Not enough NFT in Pool");
            }
            else{
                require(false, "Unknown reward type");
            }
        }
        else{
            _maxRewardPerUser = 0;
            _totalRewardPool = 0;
        }


        Quest storage newQuest = quests[_questCount];
        newQuest.creator = payable(msg.sender);
        newQuest.questsRewardType = _questsRewardType;
        newQuest.endTime = _endTime;
        newQuest.hikuruQid = _hikuruQid;
        newQuest.maxParticipation = _maxParticipation;
        newQuest.maxRewardPerUser = _maxRewardPerUser;
        newQuest.totalRewardPool = _totalRewardPool;
        newQuest.rewardContract = _rewardContract;
        newQuest.isCompleted = false;
        newQuest.withReward = _withReward;
        newQuest.referralSystem = _referralSystem;

        emit QuestCreated(_questCount, msg.sender, _hikuruQid);
        _questCount += 1;

    }




    function questModification(
        uint256 _questId,
        uint256 _newQuestsRewardType,
        uint256 _newEndTime,
        uint256 _newHikuruQid,
        uint256 _newMaxParticipation,
        uint256 _newMaxRewardPerUser,
        uint256 _newTotalRewardPool,
        bool _referralSystem
    ) external onlyOwnerOrQuestCreator(_questId) whenNotPaused {
        require(_questId < _questCount, "Quest does not exist");
        require(_newTotalRewardPool >= _newMaxRewardPerUser * _newMaxParticipation, "Insufficient reward pool");
        require(_newEndTime > block.timestamp, "End time must be in the future");


        Quest storage quest = quests[_questId];
        require(!quest.isCompleted, "Quest is already completed");

        quest.questsRewardType = _newQuestsRewardType;
        quest.endTime = _newEndTime;
        quest.hikuruQid = _newHikuruQid;
        quest.maxParticipation = _newMaxParticipation;
        quest.maxRewardPerUser = _newMaxRewardPerUser;
        quest.totalRewardPool = _newTotalRewardPool;
        quest.referralSystem = _referralSystem;

        emit QuestModified(_questId, msg.sender, _newHikuruQid);
    }

    function acceptanceParticipation(uint256 _questId, address _referral) external whenNotPaused {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        
        require(!quest.participants[msg.sender], "You have already participated in this quest");
        require(!quest.isCompleted, "Quest is already completed");
        require(quest.endTime > block.timestamp, "Quest has ended");
        require(quest.maxParticipation == 0 || (quest.participantsCount < quest.maxParticipation), "Maximum participants reached");

        quest.participants[msg.sender] = true;
        quest.participantsCount++;
        quest.participantsList.push(msg.sender);
        // user can't be referral for himself
        if(address(0)!=_referral && msg.sender!=_referral){
            quest.referrals[_referral]++;
        }

        if(!quest.hasReceivedReward[msg.sender] && quest.questsRewardType==3){
            quest.hasReceivedReward[msg.sender] = true;

            if(quest.withReward && quest.rewardContract != address(0) && msg.sender != address(0)){
                // if ERC1155 make mint of nft
                if(quest.participantsCount<quest.maxParticipation || quest.maxParticipation==0){
                    // additional check is user does not have any NFT 
                    IERC1155Mintable nftContract = IERC1155Mintable(quest.rewardContract);
                    require(nftContract.balanceOf(msg.sender, 1)==0, "User already has NFT");

                    quest.totalRewardPool-=quest.maxRewardPerUser;

                    nftContract.mint(msg.sender, quest.participantsCount, quest.maxRewardPerUser, "");
                }
            }
        }
        emit UserParticipated(_questId, msg.sender);
    }


    function ForceFinishQuest(uint256 _questId) external onlyOwnerOrQuestCreator(_questId) whenNotPaused returns (bool){
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        _selectRandomWinners(quest);
        emit ForcedFinish(_questId, msg.sender);
        return true;
    }

    function FinishQuest(uint256 _questId) external onlyOwnerOrQuestCreator(_questId) whenNotPaused returns (bool){
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        require(block.timestamp > quest.endTime, "Quest has not yet ended");
        _selectRandomWinners(quest);
        return true;
    }
    


    function _selectRandomWinners(Quest storage quest) internal whenNotPaused {
        require(!quest.isCompleted, "Quest is already completed");

        quest.isCompleted = true;

        // If some participants and reward 
        if(quest.participantsCount > 0){


            if(quest.questsRewardType==1 || quest.questsRewardType==4){

                if(quest.withReward && quest.rewardContract!=address(0) && quest.totalRewardPool>0 && quest.maxRewardPerUser>0){

                    uint256 numberOfWinners = quest.totalRewardPool / quest.maxRewardPerUser;

                    if (numberOfWinners >= quest.participantsCount) {
                        // Distribute rewards to all participants
                        for (uint256 i = 0; i < quest.participantsCount; i++) {
                            address selectedWinner = quest.participantsList[i];

                            // prevent to user to receive reward again
                            if(!quest.hasReceivedReward[selectedWinner]){
                                _distributeReward(selectedWinner, quest);
                                emit WinnerSelected(quest.hikuruQid, selectedWinner);
                            }
                        }

                        if(quest.questsRewardType==1){
                            // return to creator value which not used
                            uint256 refundsAmount = quest.totalRewardPool;
                            if(quest.totalRewardPool>0){
                                quest.totalRewardPool -= refundsAmount;
                                IERC20(quest.rewardContract).safeTransfer(quest.creator, refundsAmount);
                                emit FundsReturned(quest.hikuruQid, quest.creator, quest.totalRewardPool);
                            }
                        }

                        // return quest.participantsList;
                    } else {
                        address[] memory winners = new address[](numberOfWinners);            
                        
                        //enabled referral system
                        if(quest.referralSystem){
                            // Temporary list of participants that can be altered during the loop.
                            address[] memory tempParticipants = new address[](quest.participantsCount);
                            for (uint256 index = 0; index < quest.participantsCount; index++) {
                                tempParticipants[index] = quest.participantsList[index];
                            }

                            uint256 totalParticipants = quest.participantsCount;

                            // Calculate total weight
                            uint256 totalWeight = totalParticipants; // Every participant has a weight of at least 1 for participating
                            for (uint256 k = 0; k < totalParticipants; k++) {
                                totalWeight += quest.referrals[tempParticipants[k]];
                            }

                            // Calculate max weight any participant can have (51% of totalWeight)
                            uint256 maxWeightPerParticipant = (totalWeight * 51) / 100;

                            for (uint256 i = 0; i < numberOfWinners && totalParticipants > 0; i++) {
                                uint256 randomWeight = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, totalParticipants, i, quest.hikuruQid))) % totalWeight;
                                uint256 accumulatedWeight = 0;
                                address selectedWinner = address(0);

                                for (uint256 j = 0; j < totalParticipants; j++) {
                                    address participant = tempParticipants[j];
                                    uint256 participantWeight = (1 + quest.referrals[participant]);

                                    // Cap participant's weight if it exceeds the max
                                    if (participantWeight > maxWeightPerParticipant) {
                                        participantWeight = maxWeightPerParticipant;
                                    }

                                    accumulatedWeight += participantWeight;

                                    if (randomWeight < accumulatedWeight) {
                                        selectedWinner = participant;

                                        // Adjust totalWeight
                                        totalWeight -= participantWeight;

                                        // Remove this participant from tempParticipants
                                        tempParticipants[j] = tempParticipants[totalParticipants - 1];
                                        totalParticipants--;

                                        break;
                                    }
                                }

                                // Check if a winner was found
                                while(selectedWinner == address(0) && totalParticipants > 0) {
                                    // Adjust randomWeight and try again
                                    randomWeight = (randomWeight + 1) % totalWeight;
                                    accumulatedWeight = 0;

                                    for (uint256 j = 0; j < totalParticipants; j++) {
                                        address participant = tempParticipants[j];
                                        uint256 participantWeight = (1 + quest.referrals[participant]);

                                        // Cap participant's weight if it exceeds the max
                                        if (participantWeight > maxWeightPerParticipant) {
                                            participantWeight = maxWeightPerParticipant;
                                        }

                                        accumulatedWeight += participantWeight;

                                        if (randomWeight < accumulatedWeight) {
                                            selectedWinner = participant;

                                            // Adjust totalWeight
                                            totalWeight -= participantWeight;

                                            // Remove this participant from tempParticipants
                                            tempParticipants[j] = tempParticipants[totalParticipants - 1];
                                            totalParticipants--;

                                            break;
                                        }
                                    }
                                }
                                _distributeReward(selectedWinner, quest);
                                emit WinnerSelected(quest.hikuruQid, selectedWinner);
                            }
                        }
                        // if referralSystem is disabled
                        else{ 
                            uint256 retries = 0;
                            for(uint256 i = 0; i < numberOfWinners; i++) {
                                uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, quest.participantsCount, i, quest.hikuruQid, retries))) % quest.participantsCount;
                                address selectedWinner = quest.participantsList[randomIndex];

                                if(!quest.hasReceivedReward[selectedWinner]) {
                                    winners[i] = selectedWinner;

                                    _distributeReward(selectedWinner, quest);
                                    emit WinnerSelected(quest.hikuruQid, selectedWinner);

                                    retries = 0; // Reset retries count
                                } else {
                                    // If a duplicate is found, try again, but limit the number of retries to prevent infinite loops.
                                    i--;
                                    retries++;
                                    require(retries < numberOfWinners*5, "Too many retries to select unique winners.");
                                }
                            }
                        }

                        if(quest.questsRewardType==1){
                            // return to creator value which not used
                            uint256 refundsAmount = quest.totalRewardPool;
                            if(quest.totalRewardPool>0){
                                quest.totalRewardPool -= refundsAmount;
                                IERC20(quest.rewardContract).safeTransfer(quest.creator, refundsAmount);
                                emit FundsReturned(quest.hikuruQid, quest.creator, quest.totalRewardPool);
                            }
                        }

                        // return winners;
                    }
                }
            }
        }
    }


    function _distributeReward(address _selectedWinner, Quest storage quest) internal {
        if(quest.withReward && quest.rewardContract != address(0) && _selectedWinner != address(0)) {
            if(!quest.hasReceivedReward[_selectedWinner]){
                quest.hasReceivedReward[_selectedWinner] = true;
                uint256 rewardAmount = quest.maxRewardPerUser;


                if (quest.questsRewardType == 1) { // ERC20 - random select winners
                    if(quest.totalRewardPool >= rewardAmount) {
                        quest.totalRewardPool -= rewardAmount;
                        IERC20(quest.rewardContract).safeTransfer(_selectedWinner, rewardAmount);
                    }
                }
                else if (quest.questsRewardType == 4) { // ERC1155 - random select winners
                    if(quest.totalRewardPool >= rewardAmount) {
                        IERC1155Mintable nftContract = IERC1155Mintable(quest.rewardContract);
                        require(nftContract.balanceOf(msg.sender, 1)==0, "User already has NFT");

                        quest.totalRewardPool -= rewardAmount;

                        nftContract.mint(_selectedWinner, quest.totalRewardPool+1, rewardAmount, "");
                    }
                }
                emit RewardDistributed(quest.hikuruQid, _selectedWinner, rewardAmount);
            }
        }
    }


    function getParticipants(uint256 _questId) external whenNotPaused onlyOwnerOrQuestCreator(_questId) view returns (address[] memory) {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        return quest.participantsList;
    }

    function getCountOfReferrals(uint256 _questId, address _referral) external whenNotPaused view returns (uint256){
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        return quest.referrals[_referral];
    }


    function getQuestRewardPool(uint256 _questId) external view  returns (uint256) {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        return quest.totalRewardPool;
    }

    function getQuestCount() external view returns (uint256) {
        return _questCount;
    }

}
