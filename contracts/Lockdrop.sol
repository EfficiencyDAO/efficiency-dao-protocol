// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./EIP20Interface.sol";
import "./SafeMath.sol";
import "./ReentrancyGuard.sol";
import "./ExponentialNoError.sol";
import "./CToken.sol";

contract Lockdrop is ExponentialNoError, ReentrancyGuard {
    using SafeMath for uint256;

    address owner;
    uint256 public totalDeposits;
    bool public depositLocked;
    string public name;
    address public ctoken;
    uint256 public claimUnlockTime;

    // Official record of ctoken balances for each account.
    mapping(address => uint256) internal accountBalances;

    event Deposit(address indexed _depositor, uint256 amount);
    event Claim(address indexed _claimer, uint256 amount);

    constructor(
        string memory name_,
        address ctoken_,
        uint256 claimUnlockTime_
    ) public {
        require(
            claimUnlockTime_ > block.timestamp,
            "claim unlock time is before current time"
        );
        require(
            claimUnlockTime_ < (block.timestamp + 730 days),
            "claim unlock time is greater than 2 years"
        );
        name = name_;
        ctoken = ctoken_;
        claimUnlockTime = claimUnlockTime_;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Message sender must be the contract's owner."
        );
        _;
    }

    /**
     * @notice
     * @param amount The amount of ctokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant returns (bool) {
        require(!depositLocked, "Depositing is locked");
        require(amount > 0, "Depositing nothing");
        CToken ct = CToken(ctoken);
        bool transferStatus = ct.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(transferStatus);
        accountBalances[msg.sender] = accountBalances[msg.sender].add(amount);
        totalDeposits = totalDeposits.add(amount);
        emit Deposit(msg.sender, amount);
        return true;
    }

    /**
     * @return ctoken balance of the depositor
     */
    function balanceOf(address depositor) external view returns (uint256) {
        return accountBalances[depositor];
    }

    function claim() external nonReentrant {
        require(block.timestamp > claimUnlockTime, "Claim Functionality Still Locked");
        uint256 claimAnnouncement = accountBalances[msg.sender];
        require(claimAnnouncement > 0, "Nothing to claim");
        accountBalances[msg.sender] = 0; // Zero out balance before external call

        CToken ct = CToken(ctoken);
        bool transferStatus = ct.transfer(
            msg.sender,
            claimAnnouncement
        );
        require(transferStatus, "Transfer Failed");

        emit Claim(msg.sender, claimAnnouncement);
    }

    function setLock(bool lockStatus) external onlyOwner {
        depositLocked = lockStatus;
    }

    function setOwner(address newOwner) external onlyOwner returns (bool) {
        require(newOwner != address(0), "DANGER: Attempted to set owner to 0");
        require(
            newOwner != address(this),
            "DANGER: Attempted to throw away ownership"
        );
        owner = newOwner;
    }
}
