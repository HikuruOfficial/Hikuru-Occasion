// SPDX-License-Identifier: MIT
// author: Hikuru Labs
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";



interface IERC1155Mintable is IERC1155 {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
}



interface IFeeClaimer {
    function deposit(address _user, uint256 _amount) external payable returns (bool);
}




enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

enum GasMode {
    VOID,
    CLAIMABLE 
}

interface IBlast{
    // configure
    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external;
    function configure(YieldMode _yield, GasMode gasMode, address governor) external;

    // base configuration options
    function configureClaimableYield() external;
    function configureClaimableYieldOnBehalf(address contractAddress) external;
    function configureAutomaticYield() external;
    function configureAutomaticYieldOnBehalf(address contractAddress) external;
    function configureVoidYield() external;
    function configureVoidYieldOnBehalf(address contractAddress) external;
    function configureClaimableGas() external;
    function configureClaimableGasOnBehalf(address contractAddress) external;
    function configureVoidGas() external;
    function configureVoidGasOnBehalf(address contractAddress) external;
    function configureGovernor(address _governor) external;
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external;

    // claim yield
    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external returns (uint256);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256);
    function readYieldConfiguration(address contractAddress) external view returns (uint8);
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode);
}




// make domain
// make sign vertif
contract HikuruQuestsFactoryV1_2 is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Holder {
    using SafeERC20 for IERC20; 

    struct Quest {
        address payable creator;
        address rewardContract;
        uint256 questsRewardType;
        uint256 startTime;
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

    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    
    // Reward Types:
    // 0 - Native Token
    // 1 - ERC20
    // 2 - ERC721
    // 3 - ERC1155 - reward for every user
    // 4 - ERC1155 - reward for random selected (maxParticipant) users
    // 5 - Whitelist


    mapping(uint256 => Quest) public quests;
    mapping(uint256 => bool) private _qidIsCreated;

    uint256 private _questCount;
    uint256 private _creationQuestFee;  // Creation fee in terms of native
    // uint256 private _creationQuestFeeStable;  // Creation fee in terms of native
    bool private _allowedAcceptStable;  // Switcher is Stable is Allowed to pay fees
    // mapping(address => bool) private _isAcceptedToken; // Which ERC20 tokens are accepted for the registration fee

    address payable private _hikuruPiggyBank; // Address where will transfered funds
    IFeeClaimer public feeClaimer; // Reference to the FeeClaimer contract

    

    // Event for quest creation
    event HikuruPiggyBankUpdated(address indexed newPiggyBank);
    event QuestCreated(address creator, uint256 hikuruQuestId);
    event QuestModified(address creator, uint256 hikuruQuestId);
    event UserParticipated(address user, uint256 hikuruQuestId);
    event WinnerSelected(address winner, uint256 hikuruQuestId);
    event RewardDistributed(address recipient, uint256 hikuruQuestId, uint256 amount);
    event FundsReturned(address creator, uint256 hikuruQuestId, uint256 amount);
    event ForcedFinish(address owner_or_creator, uint256 hikuruQuestId);

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    modifier onlyHikuruOwner() {
        require(msg.sender == owner(), "Permission denied");
        _;
    }

    modifier onlyOwnerOrQuestCreator(uint256 _hikuruQid) {
        require(msg.sender == owner() || msg.sender == quests[_hikuruQid].creator, "Permission denied");
        _;
    }

    function initialize(address initialOwner, address payable _newPiggyBank, uint256 _newCreationQuestFee, bool _newAllowedAcceptStable, address _feeClaimer) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        _hikuruPiggyBank = _newPiggyBank;
        _creationQuestFee = (_newCreationQuestFee != 0) ? _newCreationQuestFee : 0.01 ether;
        _allowedAcceptStable = _newAllowedAcceptStable;
        // _creationQuestFeeStable = _newCreationQuestFeeStable;
        feeClaimer = IFeeClaimer(_feeClaimer);

        // Set initial accepted tokens
        // for (uint256 i = 0; i < _initialAcceptedTokens.length; i++) {
        //     _isAcceptedToken[_initialAcceptedTokens[i]] = true;
        // }

        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas(); 
    }

    function claimAllYield() external onlyHikuruOwner {
        // allow only the owner to claim the yield
        BLAST.claimAllYield(address(this), _hikuruPiggyBank);
    }

    function claimMyContractsGas() external onlyHikuruOwner {
        // allow only the owner to claim the gas
        BLAST.claimAllGas(address(this), _hikuruPiggyBank);
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

    // function setCreationFeeStable(uint256 _newCreationQuestFeeStable) external onlyOwner {
    //     _creationQuestFeeStable = _newCreationQuestFeeStable;
    // }

    // function setAcceptedToken(address _token, bool _isAccepted) external onlyOwner {
    //     _isAcceptedToken[_token] = _isAccepted;
    // }


    function setHikuruPiggyBank(address payable _newPiggyBank) external onlyOwner {
        require(_newPiggyBank != address(0), "Address cannot be zero");
        _hikuruPiggyBank = _newPiggyBank;
        emit HikuruPiggyBankUpdated(_newPiggyBank);
    }
    
    function setFeeClaimer(address _feeClaimer) external onlyHikuruOwner {
        require(_feeClaimer != address(0), "New fee claimer is the zero address");
        feeClaimer = IFeeClaimer(_feeClaimer);
    }

    // Native transfer
    function questCreation(
        uint256 _questsRewardType,
        uint256 _startTime,
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
            _startTime,
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

    // Native transfer with referral
    function questCreation(
        uint256 _questsRewardType,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _hikuruQid,
        uint256 _maxParticipation,
        uint256 _maxRewardPerUser,
        uint256 _totalRewardPool,
        address _rewardContract,
        bool _withReward,
        bool _referralSystem,
        address _referralAddress
    ) external payable whenNotPaused {
        require(msg.value >= _creationQuestFee, "Creation fee not met");

        uint256 halfFee = msg.value / 2;

        // Transfer tokens instead of other
        (bool feeTransferSuccess, ) = _hikuruPiggyBank.call{value: halfFee}("");
        require(feeTransferSuccess, "Fee transfer failed");

        bool success = feeClaimer.deposit{value: halfFee}(payable(_referralAddress), msg.value-halfFee);
        require(success, "Deposit to FeeClaimer failed");
        
        // Common quest creation logic
        commonQuestCreation(
            _questsRewardType,
            _startTime,
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
    // function questCreation(
    //     IERC20 stableToken,
    //     uint256 _questsRewardType,
    //     uint256 _startTime,
    //     uint256 _endTime,
    //     uint256 _hikuruQid,
    //     uint256 _maxParticipation,
    //     uint256 _maxRewardPerUser,
    //     uint256 _totalRewardPool,
    //     address _rewardContract,
    //     bool _withReward,
    //     bool _referralSystem,
    //     address _referralAddress
    // ) external payable whenNotPaused {
    //     require(_allowedAcceptStable, "Token not accepted");
    //     require(_isAcceptedToken[address(stableToken)], "Token not accepted");
        
    //     // Check if referralAddress is not zero than check if user has enough balance and allowance
    //     if _referralAddress != address(0) {
    //         uint256 userBalance = stableToken.balanceOf(msg.sender);
    //         require(userBalance >= _creationQuestFeeStable, "Insufficient tfee balance");
    //         require(stableToken.allowance(msg.sender, address(this)) >= _creationQuestFeeStable, "Token allowance too low");

    //         if(_questsRewardType==1){
    //             // get half of the fee
    //             uint256 halfFee = _creationQuestFeeStable / 2;

    //             // Transfer tokens instead of other
    //             bool tokenTransferSuccess_bank = IERC20(stableToken).transferFrom(msg.sender, _hikuruPiggyBank, halfFee);
    //             require(tokenTransferSuccess_bank, "Reward transfer failed");

    //             bool tokenTransferSuccess_ref = IERC20(stableToken).transferFrom(msg.sender, _referralAddress, _creationQuestFeeStable - halfFee);
    //             require(tokenTransferSuccess_bank, "Reward transfer failed");
    //         }
    //     }
    //     else{
    //         uint256 userBalance = stableToken.balanceOf(msg.sender);
    //         require(userBalance >= _creationQuestFeeStable, "Insufficient tfee balance");
    //         require(stableToken.allowance(msg.sender, address(this)) >= _creationQuestFeeStable, "Token allowance too low");

    //         if(_questsRewardType==1){
    //             // Transfer tokens instead of other
    //             bool tokenTransferSuccess = IERC20(stableToken).transferFrom(msg.sender, _hikuruPiggyBank, _creationQuestFeeStable);
    //             require(tokenTransferSuccess, "Reward transfer failed");
    //         }

    //     }

    //     // Common quest creation logic
    //     commonQuestCreation(
    //         _questsRewardType,
    //         _startTime,
    //         _endTime,
    //         _hikuruQid,
    //         _maxParticipation,
    //         _maxRewardPerUser,
    //         _totalRewardPool,
    //         _rewardContract,
    //         _withReward,
    //         _referralSystem
    //     );
    // }


    //HIDDEN only allowed run from this contract
    function commonQuestCreation(
        uint256 _questsRewardType,
        uint256 _startTime,
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
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > block.timestamp, "End time must be in the future");
        require(_startTime < _endTime, "start time must be less than end");
        require(_totalRewardPool >= _maxRewardPerUser, "Insufficient reward pool");

        // check is hikuruQid not exist
        require(!_qidIsCreated[_hikuruQid], "Quest id must be unique");


        // Transfer Full Reward Now to the contract
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




        Quest storage newQuest = quests[_hikuruQid];
        newQuest.creator = payable(msg.sender);
        newQuest.questsRewardType = _questsRewardType;
        newQuest.startTime = _startTime;
        newQuest.endTime = _endTime;
        newQuest.hikuruQid = _hikuruQid;
        newQuest.maxParticipation = _maxParticipation;
        newQuest.maxRewardPerUser = _maxRewardPerUser;
        newQuest.totalRewardPool = _totalRewardPool;
        newQuest.rewardContract = _rewardContract;
        newQuest.isCompleted = false;
        newQuest.withReward = _withReward;
        newQuest.referralSystem = _referralSystem;

        _qidIsCreated[_hikuruQid] = true;
        emit QuestCreated(msg.sender, _hikuruQid);
        _questCount += 1;

    }


    function questModification(
        uint256 _hikuruQid,
        uint256 _newQuestsRewardType,
        uint256 _newStartTime,
        uint256 _newEndTime,
        uint256 _newMaxParticipation,
        uint256 _newMaxRewardPerUser,
        bool _referralSystem
    ) external onlyOwnerOrQuestCreator(_hikuruQid) whenNotPaused {
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        require(_newStartTime >= block.timestamp, "Start time must be in the future");
        require(_newEndTime > block.timestamp, "End time must be in the future");
        require(_newStartTime < _newEndTime, "start time must be less than end");

        Quest storage quest = quests[_hikuruQid];
        require(!quest.isCompleted, "Quest is already completed");

        quest.questsRewardType = _newQuestsRewardType;
        quest.startTime = _newStartTime;
        quest.endTime = _newEndTime;
        quest.maxParticipation = _newMaxParticipation;
        quest.maxRewardPerUser = _newMaxRewardPerUser;
        quest.referralSystem = _referralSystem;

        emit QuestModified(msg.sender, quest.hikuruQid);
    }

    function acceptanceParticipation(uint256 _hikuruQid, address _referral) external whenNotPaused {
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        Quest storage quest = quests[_hikuruQid];
        
        require(!quest.participants[msg.sender], "You have already participated in this quest");
        require(!quest.isCompleted, "Quest is already completed");
        require(quest.startTime < block.timestamp, "Quest not started yet");
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
        emit UserParticipated(msg.sender, _hikuruQid);
    }


    function ForceFinishQuest(uint256 _hikuruQid) external onlyOwnerOrQuestCreator(_hikuruQid) whenNotPaused returns (bool){
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        Quest storage quest = quests[_hikuruQid];
        quest.isCompleted = true;
        emit ForcedFinish(msg.sender, _hikuruQid);
        return true;
    }

    function FinishQuest(uint256 _hikuruQid, uint256[] memory random_winners) external onlyOwner whenNotPaused returns (bool){
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        Quest storage quest = quests[_hikuruQid];
        require(block.timestamp > quest.endTime, "Quest has not yet ended");
        _selectRandomWinners(quest, random_winners);
        return true;
    }
    

    function _selectRandomWinners(Quest storage quest, uint256[] memory random_winners) internal whenNotPaused onlyOwner{
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
                                emit WinnerSelected(selectedWinner, quest.hikuruQid);
                            }
                        }

                        if(quest.questsRewardType==1){
                            // return to creator value which not used
                            uint256 refundsAmount = quest.totalRewardPool;
                            if(quest.totalRewardPool>0){
                                quest.totalRewardPool -= refundsAmount;
                                IERC20(quest.rewardContract).safeTransfer(quest.creator, refundsAmount);
                                emit FundsReturned(quest.creator, quest.hikuruQid, quest.totalRewardPool);
                            }
                        }
                    }
                    else {
                        address[] memory winners = new address[](numberOfWinners);            
                        
                        for(uint256 i = 0; i < numberOfWinners; i++) {
                            if(i<random_winners.length-1){
                                uint256 randomIndex = random_winners[i] % quest.participantsCount;
                                
                                address selectedWinner = quest.participantsList[randomIndex];

                                if(!quest.hasReceivedReward[selectedWinner]) {
                                    winners[i] = selectedWinner;

                                    _distributeReward(selectedWinner, quest);
                                    emit WinnerSelected(selectedWinner, quest.hikuruQid);
                                } 
                            }
                        }
                        if(quest.questsRewardType==1){
                            // return to creator value which not used
                            uint256 refundsAmount = quest.totalRewardPool;
                            if(quest.totalRewardPool>0){
                                quest.totalRewardPool -= refundsAmount;
                                IERC20(quest.rewardContract).safeTransfer(quest.creator, refundsAmount);
                                emit FundsReturned(quest.creator, quest.hikuruQid, quest.totalRewardPool);
                            }
                        }
                        // return winners;
                    }
                }
            }
        }
    }


    function _distributeReward(address _selectedWinner, Quest storage quest) internal whenNotPaused {
        if(quest.withReward && quest.rewardContract != address(0) && _selectedWinner != address(0)) {
            // Additional security to prevent reentracy attack
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
                emit RewardDistributed(_selectedWinner, quest.hikuruQid, rewardAmount);
            }
        }
    }

    function getParticipants(uint256 _hikuruQid) external whenNotPaused onlyOwnerOrQuestCreator(_hikuruQid) view returns (address[] memory) {
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        Quest storage quest = quests[_hikuruQid];
        return quest.participantsList;
    }

    function getCountOfReferrals(uint256 _hikuruQid, address _referral) external whenNotPaused view returns (uint256){
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        Quest storage quest = quests[_hikuruQid];
        return quest.referrals[_referral];
    }


    function getQuestRewardPool(uint256 _hikuruQid) external view whenNotPaused returns (uint256) {
        require(_qidIsCreated[_hikuruQid], "Quest does not exist");
        Quest storage quest = quests[_hikuruQid];
        return quest.totalRewardPool;
    }

    function getQuestCount() external view whenNotPaused returns (uint256) {
        return _questCount;
    }

}
