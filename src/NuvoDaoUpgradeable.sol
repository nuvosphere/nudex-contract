// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {INuvoDao} from "./interfaces/INuvoDao.sol";
import {INuvoLock} from "./interfaces/INuvoLock.sol";
import {IProxy} from "./interfaces/IProxy.sol";

import {UintToString} from "./libs/UintToString.sol";

contract NuvoDAOUpgradeable is INuvoDao, OwnableUpgradeable {
    uint256 public constant MIN_LOCK_AMOUNT = 10000 * 10 ** 18; // 10,000 Nuvo tokens
    uint256 public constant MIN_LOCK_DURATION = 3 days;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint256)) public votes;
    mapping(address => address) public delegation;
    mapping(address => address[]) public delegatees;
    mapping(address => uint256) public activityScore;
    mapping(address => uint256) public participationRewards;
    mapping(address => uint256) public reputationScore;
    mapping(address => uint256) public lastActive;

    INuvoLock public nuvoLock;
    address public multisigWallet;

    uint32 public proposalId;
    uint256 public quorumPercentage;
    uint256 public proposalFee;
    uint256 public executionDelay;
    uint256 public fundingThreshold;
    uint256 public reputationDecayRate; // Rate at which reputation decays over time
    uint256 public activityScoreMultiplier;
    uint256 public reputationScoreMultiplier;

    function initialize(
        address _owner,
        INuvoLock _nuvoLock,
        address _multisigWallet,
        uint256 _quorumPercentage,
        uint256 _proposalFee,
        uint256 _executionDelay,
        uint256 _fundingThreshold,
        uint256 _activityScoreMultiplier,
        uint256 _reputationScoreMultiplier,
        uint256 _reputationDecayRate
    ) public initializer {
        __Ownable_init(_owner);
        nuvoLock = _nuvoLock;
        multisigWallet = _multisigWallet;
        quorumPercentage = _quorumPercentage;
        proposalFee = _proposalFee;
        executionDelay = _executionDelay;
        fundingThreshold = _fundingThreshold;
        reputationDecayRate = _reputationDecayRate;
        activityScoreMultiplier = _activityScoreMultiplier;
        reputationScoreMultiplier = _reputationScoreMultiplier;
    }

    modifier onlyMember() {
        require(
            nuvoLock.lockedBalanceOf(msg.sender) >= MIN_LOCK_AMOUNT &&
                nuvoLock.lockedTime(msg.sender) >= MIN_LOCK_DURATION,
            "You must lock at least 10,000 Nuvo tokens for 3 days to participate."
        );
        _;
    }

    function getVotingPower(address _member) public view returns (uint256 total) {
        if (_member == address(0)) return 0;
        return _getVotingPower(_member);
    }

    function getVotingPower(address[] memory _members) public view returns (uint256 total) {
        if (_members.length == 0) return 0;
        for (uint8 i; i < _members.length; ++i) {
            total += _getVotingPower(_members[i]);
        }
    }

    function delegateVote(address _delegate) external onlyMember {
        require(_delegate != msg.sender, "You cannot delegate to yourself");
        require(
            nuvoLock.lockedBalanceOf(_delegate) >= MIN_LOCK_AMOUNT,
            "Delegate must be a valid DAO member"
        );

        address previousDelegate = delegation[msg.sender];
        if (previousDelegate != address(0)) {
            address[] storage delegatee = delegatees[previousDelegate];
            for (uint8 i; i < delegatee.length; ++i) {
                if (delegatee[i] == msg.sender) {
                    delegatee[i] = delegatee[delegatee.length - 1];
                    delegatee.pop();
                    return;
                }
            }
        }

        // Set new delegation
        delegation[msg.sender] = _delegate;
        delegatees[_delegate].push(msg.sender);
    }

    function removeDelegation() external onlyMember {
        address previousDelegate = delegation[msg.sender];
        if (previousDelegate != address(0)) {
            delegation[msg.sender] = address(0);
            address[] storage delegatee = delegatees[previousDelegate];
            for (uint8 i; i < delegatee.length; ++i) {
                if (delegatee[i] == msg.sender) {
                    delegatee[i] = delegatee[delegatee.length - 1];
                    delegatee.pop();
                    return;
                }
            }
        }
    }

    function createProposal(
        uint256 _votingPeriod,
        ProposalType _proposalType,
        ProposalCategory _proposalCategory,
        string memory _description,
        bytes memory _parameters
    ) external payable onlyMember {
        require(msg.value >= proposalFee, "Proposal fee must be paid");
        uint32 newProposalId = ++proposalId;

        proposals[newProposalId] = Proposal({
            id: newProposalId,
            proposer: msg.sender,
            proposalType: _proposalType,
            proposalCategory: _proposalCategory,
            executed: false,
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + _votingPeriod),
            executionTime: uint32(block.timestamp + _votingPeriod + executionDelay),
            voteCount: 0,
            description: _description,
            parameters: _parameters
        });

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            _proposalType,
            _proposalCategory,
            _description
        );
    }

    function vote(uint256 _proposalId, uint256 _voteCount) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.startTime, "Voting hasn't started yet");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(votes[_proposalId][msg.sender] == 0, "You have already voted on this proposal");

        _decayReputation(msg.sender);

        uint256 votingPower = getVotingPower(msg.sender);
        require(_voteCount <= votingPower, "Insufficient voting power");

        proposal.voteCount += _voteCount;
        votes[_proposalId][msg.sender] = _voteCount;
        _markAsVoted(_proposalId, delegatees[msg.sender]); // FIXME: this might use a lot of gas

        // Increase activity & reputationscore
        activityScore[msg.sender] += 1;
        reputationScore[msg.sender] += 1;

        // Reward participation
        participationRewards[msg.sender] += _voteCount;

        emit Voted(_proposalId, msg.sender, votingPower, _voteCount);
    }

    function executeProposal(uint256 _proposalId) public onlyOwner {
        Proposal memory proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "Voting period is not over yet");
        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(!proposal.executed, "Proposal already executed");

        uint256 totalLockedTokens = nuvoLock.totalLocked();
        uint256 quorum = (totalLockedTokens * quorumPercentage) / 100;

        // FIXME: checked twice?
        bool passed = proposal.voteCount > (totalLockedTokens / 2) && proposal.voteCount >= quorum;
        if (passed) {
            if (proposal.proposalType == ProposalType.Funding) {
                _executeFundingProposal(proposal.parameters);
            } else if (proposal.proposalType == ProposalType.Governance) {
                _executeGovernanceProposal(proposal.parameters);
            } else if (proposal.proposalType == ProposalType.Bundle) {
                _executeBundleProposal(proposal.parameters);
            } else if (proposal.proposalType == ProposalType.Upgrade) {
                _executeUpgradeProposal(proposal.parameters);
            } else {
                _executeBasicProposal(proposal.parameters);
            }
        }
        proposal.executed = true;

        emit ProposalExecuted(_proposalId, passed);
    }

    function _executeFundingProposal(bytes memory _parameters) internal {
        FundingProposalParameters memory params = abi.decode(
            _parameters,
            (FundingProposalParameters)
        );
        require(params.amount > 0, "Invalid funding amount");
        if (params.amount >= fundingThreshold) {
            // FIXME: this can only be called by owner, is multisigWallet also the owner?
            require(
                msg.sender == multisigWallet,
                "Multisig approval required for large funding proposals"
            );
        }
        if (params.token == address(0)) {
            // Handle native cryptocurrency (e.g., ETH)
            require(address(this).balance >= params.amount, "Insufficient balance");
            params.recipient.transfer(params.amount);
        } else {
            // Handle ERC20 tokens
            IERC20(params.token).transfer(params.recipient, params.amount);
        }

        emit FundingProposalExecuted(params.recipient, params.amount, params.token, params.purpose);
    }

    function _executeGovernanceProposal(bytes memory _parameters) internal {
        // Decode the parameters and adjust the DAO settings accordingly
        (
            uint256 newQuorumPercentage,
            uint256 newProposalFee,
            uint256 newExecutionDelay,
            uint256 newFundingThreshold,
            uint256 newReputationDecayRate
        ) = abi.decode(_parameters, (uint256, uint256, uint256, uint256, uint256));

        if (newQuorumPercentage > 0 && newQuorumPercentage <= 100) {
            quorumPercentage = newQuorumPercentage;
        }

        if (newProposalFee > 0) {
            proposalFee = newProposalFee;
        }

        if (newExecutionDelay > 0) {
            executionDelay = newExecutionDelay;
        }

        if (newFundingThreshold > 0) {
            fundingThreshold = newFundingThreshold;
        }

        if (newReputationDecayRate > 0) {
            reputationDecayRate = newReputationDecayRate;
        }
    }

    function _executeBundleProposal(bytes memory _parameters) internal {
        uint256[] memory proposalIds = abi.decode(_parameters, (uint256[]));

        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 bundleProposalId = proposalIds[i];
            Proposal storage bundleProposal = proposals[bundleProposalId];

            if (!bundleProposal.executed) {
                executeProposal(bundleProposalId);
            }
        }
    }

    function _executeUpgradeProposal(bytes memory _parameters) internal {
        (address proxy, address newImplementation) = abi.decode(_parameters, (address, address));
        IProxy(proxy).upgrade(newImplementation);
        emit Upgraded(newImplementation);
    }

    function _executeBasicProposal(bytes memory _parameters) internal {
        // Logic for basic proposal execution
    }

    function _decayReputation(address _member) internal {
        uint256 decayAmount = (block.timestamp - lastActive[_member]) * reputationDecayRate;
        if (reputationScore[_member] > decayAmount) {
            reputationScore[_member] = reputationScore[_member] - decayAmount;
        } else {
            reputationScore[_member] = 0;
        }
        lastActive[_member] = block.timestamp;
    }

    function _getVotingPower(address _member) internal view returns (uint256 total) {
        // delegation vote
        total += getVotingPower(delegatees[_member]);
        // timeWeightedPower
        total +=
            nuvoLock.lockedBalanceOf(_member) *
            (block.timestamp - nuvoLock.lockedTime(_member));
        // reputationBonus
        total += reputationScore[_member] * reputationScoreMultiplier;
        // activityScore
        total += activityScore[_member] * activityScoreMultiplier;
    }

    function _markAsVoted(uint256 _proposalId, address[] memory _member) internal {
        if (_member.length == 0) return;
        for (uint8 i; i < _member.length; ++i) {
            votes[_proposalId][_member[i]] = 1;
            _markAsVoted(_proposalId, delegatees[_member[i]]);
        }
    }

    function claimRewards() external {
        uint256 reward = participationRewards[msg.sender];
        require(reward > 0, "No rewards available");

        participationRewards[msg.sender] = 0;
        payable(msg.sender).transfer(reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function receiveRevenue() external payable {
        // Function to receive native cryptocurrency (e.g., ETH)
    }

    function receiveERC20(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    // Automated Reporting and Visualization

    function generateParticipationReport()
        public
        view
        returns (
            uint256 totalMembers,
            uint256 totalProposals,
            uint256 totalVotes,
            uint256 totalReputation
        )
    {
        totalMembers = proposalId; // Number of members who have created proposals
        totalProposals = proposalId;
        totalVotes = 0;
        totalReputation = 0;

        for (uint256 i = 1; i <= proposalId; i++) {
            Proposal memory proposal = proposals[i];
            totalVotes = totalVotes + proposal.voteCount;
        }

        for (uint256 i = 1; i <= proposalId; i++) {
            Proposal memory proposal = proposals[i];
            totalReputation = totalReputation + reputationScore[proposal.proposer];
        }
    }

    function visualizeMetrics() external view returns (string memory) {
        // This function would return a string representation of key metrics.
        // For example, it could return a JSON or CSV format of metrics data.
        // For simplicity, we assume it returns a basic string with comma-separated values.
        uint256 totalMembers;
        uint256 totalProposals;
        uint256 totalVotes;
        uint256 totalReputation;

        (totalMembers, totalProposals, totalVotes, totalReputation) = generateParticipationReport();

        return
            string(
                abi.encodePacked(
                    "Total Members: ",
                    UintToString.uint256ToString(totalMembers),
                    ", Total Proposals: ",
                    UintToString.uint256ToString(totalProposals),
                    ", Total Votes: ",
                    UintToString.uint256ToString(totalVotes),
                    ", Total Reputation: ",
                    UintToString.uint256ToString(totalReputation)
                )
            );
    }

    // Governance control functions (can only be executed via governance proposals)
    function setQuorumPercentage(uint256 _quorumPercentage) external onlyOwner {
        quorumPercentage = _quorumPercentage;
    }

    function setProposalFee(uint256 _proposalFee) external onlyOwner {
        proposalFee = _proposalFee;
    }

    function setExecutionDelay(uint256 _executionDelay) external onlyOwner {
        executionDelay = _executionDelay;
    }

    function setFundingThreshold(uint256 _fundingThreshold) external onlyOwner {
        fundingThreshold = _fundingThreshold;
    }

    function setMultisigWallet(address _multisigWallet) external onlyOwner {
        multisigWallet = _multisigWallet;
    }

    function setReputationDecayRate(uint256 _reputationDecayRate) external onlyOwner {
        reputationDecayRate = _reputationDecayRate;
    }
}
