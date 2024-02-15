// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 



//make domain
// make sign vertif
contract HikuruQuestsFactoryV1 is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20; 

    struct Quest {
        address payable creator;
        address rewardContract;
        string title;
        string description;
        uint256 questsRewardType;
        uint256 endTime;
        uint256 hikuruQid;
        uint256 maxParticipation;
        uint256 participantsCount;
        uint256 maxRewardPerUser;
        uint256 totalRewardPool;
        address[] participantsList;
        mapping(address => bool) participants;
        mapping(address => bool) hasWon;
        mapping (address => uint256) referrals; // username who invite participants
        bool isCompleted;
        bool withReward;
        bool referralSystem;
    }
    
    // Reward Types:
    // 1 - ERC20
    // 2 - ERC721

    mapping(uint256 => Quest) public quests;
    uint256 private _questCount;
    uint256 private _creationQuestFee;  // Creation fee in terms of native
    bool private _allowedAcceptStable;  // Switcher is Stable is Allowed to pay fees
    uint256 private _creationQuestFeeStable;  // Creation fee in terms of native
    mapping(address => bool) private _isAcceptedToken; // Which ERC20 tokens are accepted for the registration fee

    address payable private _hikuruPiggyBank; // Address where will transfered funds
    

    // Event for quest creation
    event HikuruPiggyBankUpdated(address indexed newPiggyBank);
    event QuestCreated(uint256 questId, address creator, string Quest);
    event QuestModified(uint256 questId, address creator, string Quest);
    event UserParticipated(uint256 questId, address user);
    event WinnerSelected(uint256 questId, address winner);
    event RewardDistributed(uint256 questId, address recipient, uint256 amount);
    event FundsReturned(uint256 questId, address creator, uint256 amount);

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
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


    function questCreation(
        string memory _title,
        string memory _description,
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
            _title,
            _description,
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

    function questCreation(
        IERC20 stableToken,
        string memory _title,
        string memory _description,
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
        
        // Transfer tokens instead of ether
        bool tokenTransferSuccess = IERC20(stableToken).transferFrom(msg.sender, _hikuruPiggyBank, _creationQuestFeeStable);
        require(tokenTransferSuccess, "Fee transfer failed");
        
        // Common quest creation logic
        commonQuestCreation(
            _title,
            _description,
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
        string memory _title,
        string memory _description,
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


        if (_withReward && _rewardContract != address(0)) {
            uint256 userBalance = IERC20(_rewardContract).balanceOf(msg.sender);
            require(userBalance >= _totalRewardPool, "Insufficient token balance");
            require(_totalRewardPool > 0, "TotalRewardPool isnt natural");

            require(IERC20(_rewardContract).allowance(msg.sender, address(this)) >= _totalRewardPool, "Token allowance too low");
            

            bool successTransfer = IERC20(_rewardContract).transferFrom(msg.sender, address(this), _totalRewardPool);
            require(successTransfer, "Transfer of ERC20 tokens failed");
        }


        Quest storage newQuest = quests[_questCount];
        newQuest.creator = payable(msg.sender);
        newQuest.title = _title;
        newQuest.description = _description;
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

        emit QuestCreated(_questCount, msg.sender, _title);
        _questCount += 1;

    }




    function questModification(
        uint256 _questId,
        string memory _newTitle,
        string memory _newDescription,
        uint256 _newQuestsRewardType,
        uint256 _newEndTime,
        uint256 _newHikuruQid,
        uint256 _newMaxParticipation,
        uint256 _newMaxRewardPerUser,
        uint256 _newTotalRewardPool,
        bool _referralSystem
    ) external onlyOwner whenNotPaused {
        require(_questId < _questCount, "Quest does not exist");
        require(_newTotalRewardPool >= _newMaxRewardPerUser * _newMaxParticipation, "Insufficient reward pool");

        Quest storage quest = quests[_questId];
        require(!quest.isCompleted, "Quest is already completed");

        quest.title = _newTitle;
        quest.description = _newDescription;
        quest.questsRewardType = _newQuestsRewardType;
        quest.endTime = _newEndTime;
        quest.hikuruQid = _newHikuruQid;
        quest.maxParticipation = _newMaxParticipation;
        quest.maxRewardPerUser = _newMaxRewardPerUser;
        quest.totalRewardPool = _newTotalRewardPool;
        quest.referralSystem = _referralSystem;

        emit QuestModified(_questId, msg.sender, _newTitle);
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
        emit UserParticipated(_questId, msg.sender);
    }


    function forceStopQuest(uint256 _questId) external onlyOwner whenNotPaused returns (bool){
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        quest.isCompleted = true;
        return false;
    }
    
    function selectRandomWinners(uint256 _questId) external onlyOwner whenNotPaused  {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        // require(block.timestamp > quest.endTime, "Quest has not yet ended");
        require(!quest.isCompleted, "Quest is already completed");
        require(quest.participantsCount > 0, "No participants to select from");
        
        uint256 numberOfWinners = quest.totalRewardPool / quest.maxRewardPerUser;

        quest.isCompleted = true;

        if(quest.withReward && quest.rewardContract!=address(0) && quest.totalRewardPool>0){
            
            if (numberOfWinners >= quest.participantsCount) {
                // Distribute rewards to all participants
                for (uint256 i = 0; i < quest.participantsCount; i++) {
                    address participant = quest.participantsList[i];

                    // prevent to user to receive reward again
                    if(!quest.hasWon[participant]){
                        quest.hasWon[participant] = true;
                    
                        _distributeReward(participant, quest);
                        emit WinnerSelected(_questId, participant);
                    }
                }

                // return to creator value which not used
                uint256 refundsAmount = quest.totalRewardPool;
                if(quest.totalRewardPool>0){
                    quest.totalRewardPool -= refundsAmount;
                    IERC20(quest.rewardContract).safeTransfer(quest.creator, refundsAmount);
                    emit FundsReturned(quest.hikuruQid, quest.creator, quests[_questId].totalRewardPool);
                }

                // return quest.participantsList;
            } else {
                address[] memory winners = new address[](numberOfWinners);            

                if(!quest.referralSystem){ // if referralSystem is disabled
                    uint256 retries = 0;
                    for(uint256 i = 0; i < numberOfWinners; i++) {
                        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, quest.participantsCount, i, _questId, retries))) % quest.participantsCount;
                        address selectedWinner = quest.participantsList[randomIndex];

                        if(!quest.hasWon[selectedWinner]) {
                            winners[i] = selectedWinner;
                            quest.hasWon[selectedWinner] = true;

                            _distributeReward(selectedWinner, quest);
                            emit WinnerSelected(_questId, selectedWinner);

                            retries = 0; // Reset retries count
                        } else {
                            // If a duplicate is found, try again, but limit the number of retries to prevent infinite loops.
                            i--;
                            retries++;
                            require(retries < numberOfWinners*5, "Too many retries to select unique winners.");
                        }
                    }
                }
                //enabled referral system
                else {
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
                        uint256 randomWeight = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, totalParticipants, i, _questId))) % totalWeight;
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
                        emit WinnerSelected(_questId, selectedWinner);
                    }
                }

                // return to creator value which not used
                uint256 refundsAmount = quest.totalRewardPool;
                if(quest.totalRewardPool>0){
                    quest.totalRewardPool -= refundsAmount;
                    IERC20(quest.rewardContract).safeTransfer(quest.creator, refundsAmount);
                    emit FundsReturned(quest.hikuruQid, quest.creator, quests[_questId].totalRewardPool);
                }

                // return winners;
            }
        }
    }


    function _distributeReward(address _selectedWinner, Quest storage quest) internal {
        if(quest.withReward && quest.rewardContract != address(0) && _selectedWinner != address(0)) {
            uint256 rewardAmount = quest.maxRewardPerUser;
            if (quest.questsRewardType == 1) { // ERC20
                if(quest.totalRewardPool >= rewardAmount) {
                    quest.totalRewardPool -= rewardAmount;
                    IERC20(quest.rewardContract).safeTransfer(_selectedWinner, rewardAmount);
                }
            } else if (quest.questsRewardType == 2) { // ERC 721
                // if(quest.totalRewardPool >= rewardAmount) {
                //     quest.totalRewardPool -= rewardAmount;
                //     IERC20(quest.rewardContract).safeTransfer(_selectedWinner, rewardAmount);
                // }
            }
            emit RewardDistributed(quest.hikuruQid, _selectedWinner, rewardAmount);
        }
    }


    function getParticipants(uint256 _questId) external whenNotPaused view returns (address[] memory) {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];

        // Check if the sender is either the quest creator or the contract owner
        require(msg.sender == quest.creator || msg.sender == owner(), "Permission denied: Not quest creator or contract owner");

        return quest.participantsList;
    }

    function getCountOfReferrals(uint256 _questId, address _referral) external whenNotPaused view returns (uint256){
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        return quest.referrals[_referral];
    }


    function withdrawFromQuestRewardPool(uint256 _questId, address _to, uint256 _amount) external onlyOwner whenNotPaused {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        
        require(quest.withReward && quest.rewardContract != address(0), "This quest doesn't have a reward!");
        require(quest.totalRewardPool >= _amount && quest.totalRewardPool>0, "Insufficient funds in the reward pool");
        require(quest.withReward && quest.rewardContract!=address(0), "Quest don't have any funds to withdraw!");

        // Deduct the amount from the quest's totalRewardPool
        quest.totalRewardPool -= _amount;

        // Transfer the tokens to the specified address
        IERC20(quest.rewardContract).safeTransfer(_to, _amount);
    }


    function withdrawSpecificTokenContract(address _tokenContract, address _to, uint256 _amount) external onlyOwner whenNotPaused {
        IERC20(_tokenContract).safeTransfer(_to, _amount);
    }



    function getQuestRewardPool(uint256 _questId) external view  returns (uint256) {
        require(_questId < _questCount, "Quest does not exist");
        Quest storage quest = quests[_questId];
        return quest.totalRewardPool;
    }

}
