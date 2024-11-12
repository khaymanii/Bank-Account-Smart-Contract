// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


contract BankAccount {
    //Events

    event Deposit(address indexed user, uint indexed accountId, uint value, uint timestamp);
    event WithdrawRequested(address indexed user, uint256 indexed accountId, uint256 indexed withdrawId, uint256 amount, uint256 timestamp);
    event Withdraw (uint indexed withdrawId, uint timestamp);
    event AccountCreated(address[] owners, uint indexed id, uint timestamp);

    // Structs
    struct WithdrawRequest {
        address user;
        uint amount;
        uint approvals;
        mapping(address => bool) ownersApproved;
        bool approved;
    }

    struct Account {
        address[] owners;
        uint balance;
        mapping(uint => WithdrawRequest) withdrawRequests;
    }

    mapping(uint => Account) accounts;
    mapping(address => uint[]) userAccounts;

    uint nextAccountId;
    uint nextWithdrawId;

    // Modifiers

    modifier accountOwner (uint accountId) {
        bool isOwner;
        for (uint idx; idx < accounts[accountId].owners.length; idx++) {
            if (accounts[accountId].owners[idx] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "you are not an owner of this account");
        _;
    }

    modifier validOwners(address[] calldata owners){
        require(owners.length + 1 <= 4, "maximum of 4 owners per account");
        for (uint256 i; i < owners.length; i++) {
            if(owners[i] == msg.sender) {
                revert("no duplicate owners");
            }
            for(uint256 j = i; j <owners.length; j++) {
                if (owners[i] == owners[j]) {
                    revert("no duplicate owners");
                }
            }
        }
        _;
    }

    modifier sufficientBalance(uint256 accountId, uint256 amount) {
        require(accounts[accountId].balance >= amount, "insufficient balance");
        _;
    }

    modifier canApprove(uint256 accountId, uint256 withdrawId) {
        require(!accounts[accountId].withdrawRequests[withdrawId].approved, "this request is already approved");
        require(accounts[accountId].withdrawRequests[withdrawId].user != msg.sender, "you cannot approve this request");
        require(accounts[accountId].withdrawRequests[withdrawId].user != address(0), "this request does not exist");
        require(!accounts[accountId].withdrawRequests[withdrawId].ownersApproved[msg.sender], "you have already approved this request");
        _;

    }

    modifier canWithdraw(uint256 accountId, uint256 withdrawId) {
        require(accounts[accountId].withdrawRequests[withdrawId].user == msg.sender, "you did not create this request");
        require(accounts[accountId].withdrawRequests[withdrawId].approved, "this request is not approved");
        _;
    }

    // Functions

    function deposit (uint accountId) external payable accountOwner(accountId) {
        accounts[accountId].balance += msg.value;
    }

    function createAccount (address[] calldata otherOwners) external validOwners(otherOwners) {
        address[] memory owners = new address[](otherOwners.length + 1);
        owners[otherOwners.length] = msg.sender;

        uint256 id = nextAccountId;

        for (uint256 idx; idx < owners.length; idx++) {
            if(idx < owners.length - 1) {
                owners[idx] = otherOwners[idx];
            }

            if (userAccounts[owners[idx]].length > 2) {
                revert("each user can have a max of 3 accounts");
            }
            userAccounts[owners[idx]].push(id);
        }

        accounts[id].owners = owners;
        nextAccountId++;
        emit AccountCreated(owners, id, block.timestamp);
    }

    function requestWithdrawal (uint256 accountId, uint256 amount) external accountOwner(accountId) sufficientBalance(accountId, amount) {
        uint256 id = nextWithdrawId;
        WithdrawRequest storage request = accounts[accountId].withdrawRequests[id];
        request.user = msg.sender;
        request.amount = amount;
        nextWithdrawId++;
        emit WithdrawRequested(msg.sender, accountId, id, amount, block.timestamp);
    }

    function approveWithdrawal(uint256 accountId, uint256 withdrawId) external accountOwner(accountId) canApprove(accountId, withdrawId){
        WithdrawRequest storage request = accounts[accountId].withdrawRequests[withdrawId];
        request.approvals++;
        request.ownersApproved[msg.sender] = true;

        if(request.approvals == accounts[accountId].owners.length - 1) {
            request.approved = true;
        }
    }

    function withdraw(uint256 accountId, uint256 withdrawId) external canWithdraw(accountId, withdrawId) {
        uint amount = accounts[accountId].withdrawRequests[withdrawId].amount;
        require(accounts[accountId].balance >= amount, "insufficient balance");

        accounts[accountId].balance -= amount;
        delete accounts[accountId].withdrawRequests[withdrawId];

        (bool sent,) = payable(msg.sender).call {value: amount}("");
        require(sent);

        emit Withdraw(withdrawId, block.timestamp);
    }

    function getBalance (uint256 accountId) public view returns (uint) {
        return accounts[accountId].balance;
    }

    function getOwners (uint256 accountId) public view returns (address[] memory) {
        return accounts[accountId].owners;
    }

    function getApprovals (uint256 accountId, uint256 withdrawId) public view returns (uint) {
        return accounts[accountId].withdrawRequests[withdrawId].approvals;

    }

    function getAccounts () public view returns (uint[] memory) {
        return userAccounts[msg.sender];
    }
}
