// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract MultiCrowdfunding {
    address public creator;

    struct Campaign {
        string name;
        uint256 goal;
        uint256 deadline;
        uint256 totalContributions;
        bool isFunded;
        bool isCompleted;
        address[] contributors;
        uint256 totalVotesApprove;
        uint256 totalVotesAgainst;
        uint256 totalUsersVote;
        bool allowedWithdraw;
    }

    Campaign[] public campaigns;
    // userContributions[address][campaignIndex] = contribution;
    mapping(address => mapping(uint256 => uint256)) public userContributions;
    // isUserVoted[address][campaignIndex] = true/false;
    mapping(address => mapping(uint256 => bool)) public isUserVoted;

    event GoalReached(uint256 campaignIndex, uint256 totalContributions);
    event DeadlineReached(uint256 campaignIndex, uint256 totalContributions);
    event FundTransfer(uint256 campaignIndex, address backer, uint256 amount);
    event FundWithdrawn(uint256 campaignIndex, address recipient, uint256 amount);
    event VoteCasted(uint256 campaignIndex, address voter, bool support);

    constructor() {
        creator = msg.sender;
    }

    modifier onlyCreator() {
        require(msg.sender == creator, "Only the creator can call this function.");
        _;
    }

    modifier validCampaignIndex(uint256 campaignIndex) {
        require(campaignIndex < getCampaignsCount(), "Invalid campaign index.");
        _;
    }

    function createCampaign(string memory campaignName, uint256 fundingGoalInEther, uint256 durationInMinutes) public onlyCreator {
        campaigns.push(Campaign({
            name: campaignName,
            goal: fundingGoalInEther * 1 ether,
            deadline: block.timestamp + durationInMinutes * 1 minutes,
            totalContributions: 0,
            isFunded: false,
            isCompleted: false,
            contributors: new address[](0),
            totalVotesApprove: 0,
            totalVotesAgainst: 0,
            totalUsersVote: 0,
            allowedWithdraw: false
        }));
    }

    function contribute(uint256 campaignIndex) public payable validCampaignIndex(campaignIndex) {
        Campaign storage campaign = campaigns[campaignIndex];
        require(block.timestamp < campaign.deadline, "Funding period has ended.");
        require(!campaign.isCompleted, "Crowdfunding is already completed.");
        require(msg.value > 0, "Contribution amount must be greater than 0.");
        
        uint256 contribution = msg.value;

        if (userContributions[msg.sender][campaignIndex] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.totalContributions += contribution;
        userContributions[msg.sender][campaignIndex] += contribution;

        if (campaign.totalContributions >= campaign.goal) {
            campaign.isFunded = true;
            emit GoalReached(campaignIndex, campaign.totalContributions);
        }

        emit FundTransfer(campaignIndex, msg.sender, contribution);
    }

    function vote(uint256 campaignIndex, bool support) public validCampaignIndex(campaignIndex) {
        Campaign storage campaign = campaigns[campaignIndex];
        require(!campaign.isCompleted, "Crowdfunding is already completed.");
        
        uint256 contribution = userContributions[msg.sender][campaignIndex];
        require(contribution > 0, "You must have contributed to the campaign to vote.");

        require(!isUserVoted[msg.sender][campaignIndex], "You have already voted.");
        isUserVoted[msg.sender][campaignIndex] = true;
        campaign.totalUsersVote += 1;

        if (support) {
            campaign.totalVotesApprove += contribution;
        } else {
            campaign.totalVotesAgainst += contribution;
        }

        if (campaign.totalVotesApprove * 2 > campaign.totalContributions) {
            campaign.allowedWithdraw = true;
        }

        emit VoteCasted(campaignIndex, msg.sender, support);
    }


    function withdrawFunds(uint256 campaignIndex) public onlyCreator validCampaignIndex(campaignIndex) {
        Campaign storage campaign = campaigns[campaignIndex];
        require(campaign.isFunded, "Goal has not been reached.");
        require(campaign.allowedWithdraw, "Withdrawal is not allowed.");
        require(!campaign.isCompleted, "Crowdfunding is already completed.");

        campaign.isCompleted = true;
        payable(creator).transfer(campaign.totalContributions);

        emit FundWithdrawn(campaignIndex, creator, campaign.totalContributions);
    }

    function getRefund(uint256 campaignIndex) public validCampaignIndex(campaignIndex) {
        Campaign storage campaign = campaigns[campaignIndex];
        require(block.timestamp >= campaign.deadline, "Funding period has not ended.");
        require(!campaign.isFunded, "Goal has been reached.");

        uint256 refundAmount = userContributions[msg.sender][campaignIndex];
        require(refundAmount > 0, "No contribution to refund.");

        campaign.totalContributions -= refundAmount;
        userContributions[msg.sender][campaignIndex] = 0;
        require(payable(creator).send(refundAmount), "Transfer failed.");

        emit FundTransfer(campaignIndex, msg.sender, refundAmount);
    }

    function getCampaignDetails(uint256 campaignIndex) public view validCampaignIndex(campaignIndex) returns (
        string memory name,
        uint256 goal,
        uint256 deadline,
        uint256 totalContributions,
        bool isFunded,
        bool isCompleted,
        address[] memory contributors,
        uint256[] memory contributions,
        uint256 totalVotesApprove,
        uint256 totalUsersVote
    ) {
        Campaign memory campaign = campaigns[campaignIndex];
        contributors = campaign.contributors;
        contributions = new uint256[](contributors.length);

        for (uint256 i = 0; i < contributors.length; i++) {
            contributions[i] = userContributions[contributors[i]][campaignIndex];
        }

        return (
            campaign.name,
            campaign.goal,
            campaign.deadline,
            campaign.totalContributions,
            campaign.isFunded,
            campaign.isCompleted,
            contributors,
            contributions,
            campaign.totalVotesApprove,
            campaign.totalUsersVote
        );
    }


    function getTopContributors(uint256 campaignIndex, uint256 count) public view validCampaignIndex(campaignIndex) returns (
        address[] memory,
        uint256[] memory
    ) {
        require(count > 0, "Invalid number of contributors.");
        
        Campaign memory campaign = campaigns[campaignIndex];
        uint256 contributorCount = campaign.contributors.length;

        address[] memory sortedContributors = new address[](contributorCount);
        uint256[] memory sortedContributions = new uint256[](contributorCount);

        for (uint256 i = 0; i < contributorCount; i++) {
            sortedContributors[i] = campaign.contributors[i];
            sortedContributions[i] = userContributions[campaign.contributors[i]][campaignIndex];
        }

        for (uint256 i = 0; i < contributorCount - 1; i++) {
            for (uint256 j = i + 1; j < contributorCount; j++) {
                if (sortedContributions[i] < sortedContributions[j]) {
                    (sortedContributions[i], sortedContributions[j]) = (sortedContributions[j], sortedContributions[i]);
                    (sortedContributors[i], sortedContributors[j]) = (sortedContributors[j], sortedContributors[i]);
                }
            }
        }

        uint256 topCount = contributorCount > count ? count : contributorCount;

        address[] memory topContributors = new address[](topCount);
        uint256[] memory topContributions = new uint256[](topCount);

        for (uint256 i = 0; i < topCount; i++) {
            topContributors[i] = sortedContributors[i];
            topContributions[i] = sortedContributions[i];
        }

        return (topContributors, topContributions);
    }

    function extendDeadline(uint256 campaignIndex, uint256 durationInMinutes) public onlyCreator validCampaignIndex(campaignIndex) {
        Campaign storage campaign = campaigns[campaignIndex];
        
        require(campaign.deadline + durationInMinutes * 1 minutes > campaign.deadline, "New deadline must be after the current deadline.");

        campaign.deadline += durationInMinutes * 1 minutes;
    }

    function getCurrentBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getCampaignsCount() public view returns (uint256) {
        return campaigns.length;
    }
}
