pragma solidity >=0.5.0 <0.6.0;

contract HotelReservation {
    // structure containing details of the room
    struct RoomRegister {
        address client;
        uint32 room;
        uint fromTime;
        uint toTime;
    }
    
    address public owner;
    uint public costPerRoom;
    uint32 public noOfRooms;
    uint32 public refundPercent1 = 100;
    uint32 public refundPercent2 = 50;
    uint32 public refundPercent3 = 0;
    
    mapping (uint32 => bytes32[]) roomToRegId;
    mapping (bytes32 => RoomRegister) idToDetails;
    mapping (address => uint) addressToRefund;
    
    event RoomBooked(address client, bytes32 regId);
    event RoomCancelled(address client, uint32 room, uint fromTime, uint toTime);
    
    constructor (uint32 _noOfRooms, uint _costPerRoom) public {
        owner = msg.sender;
        noOfRooms = _noOfRooms;
        costPerRoom = _costPerRoom * 10**18; // converting ether to wei
    }
    
    // find available room 
    function _roomAvailable(bytes32[] memory _regIds, uint _fromTime, uint _toTime) private view returns (bool) {
        for(uint i=0; i<_regIds.length;i++) {
            RoomRegister memory details = idToDetails[_regIds[i]];
            if((details.fromTime <= _fromTime && details.toTime>=_fromTime)||(details.fromTime <= _toTime && details.toTime>=_toTime)) {
                return false;
            }
        }
        return true;
    }
    
    // book room in the hotel if there is free room
    function bookRoom(uint _fromTime, uint _toTime) public payable returns(bytes32){
        require(msg.value >= costPerRoom);
        require(_fromTime<_toTime && _fromTime > now);
        bytes32 regId = keccak256(abi.encodePacked(msg.sender, _fromTime, _toTime, now));
        for(uint32 i=1; i<=noOfRooms; i++) {
            if(_roomAvailable(roomToRegId[i], _fromTime, _toTime)) {
                roomToRegId[i].push(regId);
                idToDetails[regId] = RoomRegister({client: msg.sender, room: i, fromTime: _fromTime, toTime: _toTime});
                
                msg.sender.transfer(msg.value-costPerRoom);
                emit RoomBooked(msg.sender, regId);
                return regId;
            }
        }
        return bytes32(0);
    }
    
    // cancel or checkout from the hotel 
    function cancelOrCheckout(bytes32 _regId) public {
        require(idToDetails[_regId].client == msg.sender, "Invalid Registration id");
        RoomRegister memory details = idToDetails[_regId];
        
        emit RoomCancelled(details.client, details.room, details.fromTime, details.toTime);
        
        // remove registration id from idToDetails and roomToRegId
        idToDetails[_regId] = RoomRegister({client: address(0), room: 0, fromTime: 0, toTime: 0});
        uint32 room = details.room;
        bool j = false;
        for(uint i=0; i<roomToRegId[room].length;i++) {
            if(j) roomToRegId[room][i-1] = roomToRegId[room][i];
            else if(roomToRegId[room][i] == _regId) j=true;
        }
        roomToRegId[room].length--;
        
        // refund
        uint refund = 0;
        if(details.fromTime - now > 604800) {
            refund = costPerRoom * refundPercent1 / 100;
        }
        else if(details.fromTime - now > 172800) {
            refund = costPerRoom * refundPercent2 / 100;
        }
        else {
            refund = costPerRoom * refundPercent3 / 100;
        }
        addressToRefund[msg.sender] += refund;
        addressToRefund[owner] += (costPerRoom - refund);
    }
    
    // withdraw refund 
    function withdrawRefund() public {
        require(addressToRefund[msg.sender] > 0);
        msg.sender.transfer(addressToRefund[msg.sender]);
        addressToRefund[msg.sender] = 0;
    }
    
    // show details of reservation using registration id
    function showDetails(bytes32 _regId) public view returns(uint32, uint, uint) {
        RoomRegister memory details = idToDetails[_regId];
        return (details.room, details.fromTime, details.toTime);
    }
    
    // change cancellation charges
    function changeRefundStrategy(uint32 _refundPercent1, uint32 _refundPercent2, uint32 _refundPercent3) public {
        require(msg.sender == owner, "This function can be called by the owner only");
        refundPercent1 = _refundPercent1;
        refundPercent2 = _refundPercent2;
        refundPercent3 = _refundPercent3;
    } 
    
    // show current time
    function showTime() public view returns(uint) {
        return now;
    } 
}
