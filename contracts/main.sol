// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

pragma solidity ^0.8.0;

contract Main is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public token;

    uint256 public price;

    struct CustomerDetails {
        uint256 activestart;
        uint256 activeEnd;
        bytes32 name;
        uint256 dob;
        bytes32 policy;
        bool enroll;
        uint256 lockedTokens;
    }

    struct PolicyHealth {
        bytes32 holderName;
        uint256 status;
        uint256 date;
        uint256 claimCount;
        uint256 nextPay;
        uint256 lastPay;
        uint256 paymentCount;
    }

    modifier checkOrg(address org) {
        require(organisation[org] == true, "Invalid organisation");
        _;
    }

    event Enrolled(address indexed user, uint256 date);

    event DuePaid(address indexed to, uint256 tokens, uint256 date);

    event ClaimeAdded(address indexed user, string document);

    event Claimed(address indexed user, string document, uint256 tokens);

    mapping(address => CustomerDetails) private customersDetails;
    mapping(address => PolicyHealth) public policies;
    mapping(string => address) public claimDataB;
    mapping(address => bool) public organisation;

    function initialize(IERC20Upgradeable _token, uint256 _price)
        public
        initializer
    {
        ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
        __Ownable_init();
        token = _token;
        change_price(_price);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function change_price(uint256 _price) public onlyOwner {
        price = _price;
    }

    function enroll(
        // address sender,
        bytes32 name,
        uint256 dob
    ) external // uint256 tokens
    {
        require(customersDetails[_msgSender()].enroll == false, "enrolled !");
        require(
            token.balanceOf(_msgSender()) >= 50,
            "insuffient amount to enroll"
        );
        token.transferFrom(_msgSender(), address(this), 50);

        if (customersDetails[_msgSender()].dob != 0) {
            customersDetails[_msgSender()].enroll = true;
            policies[_msgSender()].status = 1;
            policies[_msgSender()].nextPay = block.timestamp + 31556926;
        } else {
            customersDetails[_msgSender()].enroll = true;
            customersDetails[_msgSender()].name = name;
            customersDetails[_msgSender()].policy = bytes32("health01");
            customersDetails[_msgSender()].dob = dob;
            customersDetails[_msgSender()].activestart = block.timestamp;

            policies[_msgSender()].holderName = name;
            policies[_msgSender()].status = 1;
            policies[_msgSender()].date = block.timestamp;
            policies[_msgSender()].nextPay = block.timestamp + 31556926;
        }

        emit Enrolled(_msgSender(), block.timestamp);
    }

    function remove(address user)
        external
        // uint256 tokens
        onlyOwner
    {
        customersDetails[user].activeEnd = block.timestamp;
        customersDetails[user].enroll = false;
        policies[user].status = 0;
    }

    function addOrganisation(address org) external onlyOwner {
        organisation[org] = true;
    }

    function removeOrganisation(address org) external onlyOwner {
        organisation[org] = false;
    }

    function payDue() external {
        require(
            customersDetails[_msgSender()].enroll == true,
            "Not enrolled !"
        );
        require(
            block.timestamp >= policies[_msgSender()].nextPay &&
                block.timestamp <= policies[_msgSender()].nextPay + 604800,
            "due date invalid"
        );
        require(
            token.balanceOf(_msgSender()) >= 24050,
            "insuffient tokens for due payment"
        ); //50 tokens for transaction fee

        token.transferFrom(_msgSender(), address(this), 24050);

        policies[_msgSender()].nextPay = block.timestamp + 31556926;

        policies[_msgSender()].paymentCount++;

        emit DuePaid(_msgSender(), block.timestamp, 24050);
    }

    function addClaim(address user, string memory document)
        external
        checkOrg(_msgSender())
    {
        claimDataB[document] = user;

        emit ClaimeAdded(user, document);
    }

    function claim(
        address user,
        string memory document,
        uint256 tokens
    ) external onlyOwner {
        require(
            customersDetails[user].enroll == true && policies[user].status == 1,
            "INAVLID CALLED"
        );
        require(claimDataB[document] == user, "INAVLID DOCUMENT");

        token.transfer(_msgSender(), tokens);

        policies[_msgSender()].claimCount++;

        delete (claimDataB[document]);

        emit Claimed(user, document, tokens);
    }
}
