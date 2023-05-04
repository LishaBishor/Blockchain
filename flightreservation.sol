// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract FlightReservation{
 
   // struct to to define different cancellation and delay penalties for different time range(Advance Feature)  
   struct PenaltyTimeRange{
     uint8 timeRange; 
     uint256 percentageCancellationPenalty;
     uint256 percentageDelayPenalty;
   }
   PenaltyTimeRange[] _penaltyTimeRanges;
   uint8 delayedDepartureHours;

    
    enum FlightStatus {ONTIME, DELAYED, CANCELLED, NOTSTARTED} //code 0 for ONTIME, 1 for DELAYED, 2 for CANCELLED and 3 for NOTSTARTED
    enum TicketStatus {CONFIRMED, CANCELLED, REFUNDED} //code 0 for CONFIRMED, 1 for CANCELLED and 2 for REFUNDED
    enum SeatCategory {BUSINESS, ECONOMY}      

      

  struct Airline {
    // Id of airlines
    uint256 airlineId;   
    // Ethereum address of the owner who will manage this airline
    address payable airlineOwner;
    // Initial number of seats
    uint256 initialSeatNumber;   
    // flight date time
    uint256 departureDateTime;
    // status of current flight
    FlightStatus fStatus; 
    //percentage amount would be deducted from ticket price
    // uint8 percentagePenaltyBeforTwoHour; // comented after advance feature implementation
    //Airline ticket price in ether
    uint256 airlineTicketPrice;

    //Percentage compensation would be paid to customer in case of flight delay
    //uint8 percentageCompensationForFlighDelay; 

    // Airline should update flight status within 24 hours of flight departure time, default value is set as false
    // in the constructor
    bool flightStatusUpdated;
      
  }
   
  struct Ticket {
    // ticket confirmationid
    uint256 ticketConfirmationId;
    // ID of the airline that provides this ticket
    uint256 airlineId;
    // From and To, cities connected by the flight
    string  FromCity;
    string  ToCity;
    // Ticket price in ether
    uint256 ticketPrice;
    // Number of seats available 
    uint256 ticketQuantity;
    // Timestamps of planned departure and arrival, epoch time
    uint256 departureTime;
    uint256 arrivalTime;
    // customer address
    address payable ticketHolder;
    // ticket status
    TicketStatus tStatus;
    // seat category
    SeatCategory sCategory;
       
  }

  // A reference of particular entry into array
  struct ArrayIndex {
    bool exists;
    uint256 index;
  }
  Airline _airlineData;  
  // Storage of tickets
  Ticket[] public tickets;  // The list of tickets 
  mapping(uint256 => ArrayIndex) private ticketIdIndex;  // Index to find Ticket by its confirmationID  
  uint256 private confirmationIdLast; // confirmation id generated for each ticket booking  

  // This function returns available seats for the booking
  function getAvailableSeats() public view returns (uint256) {
    return _airlineData.initialSeatNumber;
  }
  
  //get Ticket by confirmation id
  function getTicketByConfirmationId(uint256 _confirmationId) public view returns(
    uint256 ticketConfirmationId,   
    uint256 airlineId,
    string memory FromCity,
    string memory ToCity,
    uint256 ticketPrice,
    uint256 ticketQuantity, 
    uint256 departureTime,
    uint256 arrivalTime,
    address ticketHolder,
    TicketStatus tStatus,
    SeatCategory sCategory
    ) {

    require(ticketIdIndex[_confirmationId].exists, "Ticket does not exist");
    Ticket storage ticket = tickets[ticketIdIndex[_confirmationId].index];
    return (ticket.ticketConfirmationId, ticket.airlineId, ticket.FromCity, ticket.ToCity, ticket.ticketPrice, ticket.ticketQuantity, ticket.departureTime, ticket.arrivalTime, ticket.ticketHolder, ticket.tStatus, ticket.sCategory);
  }
   
    
    //Dummy airline data for ticket booking
    constructor() {
        _airlineData = Airline({
                                    airlineId: 9988,                                   
                                    airlineOwner: payable(msg.sender), 
                                    initialSeatNumber: 100,                                                                  
                                    departureDateTime: 1667128123,
                                    fStatus: FlightStatus.NOTSTARTED,
                                    //percentagePenaltyBeforTwoHour: 30,  //commented after advance feature implementation
                                    airlineTicketPrice: 2, // price is in ether
                                    //percentageCompensationForFlighDelay: 10, //commented after advance feature implementation
                                    flightStatusUpdated: false
                                    
                            }); 
        //Advance feature
        //different slabs for cancellation and delay penalty
        // time range 2 hours before departure cancellation and 2 hours of delay penalties are 30% and 10% respectivaly 
        // time range 6 hours before departure cancellation and 6 hours of delay penalties are 20% and 15% respectivaly 
        // time range 12 hours before departure cancellation and 12 hours of delay penalties are 15% and 20% respectivaly 
        _penaltyTimeRanges.push(PenaltyTimeRange(2, 30, 10)); 
        _penaltyTimeRanges.push(PenaltyTimeRange(6, 20, 15)); 
        _penaltyTimeRanges.push(PenaltyTimeRange(12, 15, 20));         
    }

  //set ticket price, just in case if airline wants to increase ticket price dynamically
  function setDynamicTicketPrice(uint256 _ticketPrice) public OnlyAirlineOwner(){    
    _airlineData.airlineTicketPrice = _ticketPrice;
  }
  
  //set or change departure time
  function setDepartureDateTime(uint256 _departureDateTime) public OnlyAirlineOwner(){    
   _airlineData.departureDateTime = _departureDateTime;
  }

  //set flight status
  event showFlightStatus(FlightStatus _fStatus);
  function updateFlightStatus(uint8 _flightStatus, uint256 _airlineId, uint8 _delayedHours) public OnlyAirlineOwner() {  
   
   // function to update flight status 
   // If status update is requested within 24 hours of flight departure time, flag flightStatusUpdated is set to true
    if(_airlineData.departureDateTime - block.timestamp <= 24*60*60){  

      if(_flightStatus == 0){
        _airlineData.fStatus = FlightStatus.ONTIME;
      }
      else if(_flightStatus == 1){
        require((_airlineData.fStatus != FlightStatus.CANCELLED), "Flight is already cancelled");
        delayedDepartureHours = _delayedHours;   // setting delay hours to delayedDepartureHours to calculate delay penalties   
        _airlineData.fStatus = FlightStatus.DELAYED;       
      }
      else if(_flightStatus == 2){            
        _airlineData.fStatus = FlightStatus.CANCELLED;
        cancelAllAirlineTicket(_airlineId); 
      }     
      _airlineData.flightStatusUpdated = true;    

    }     
    emit showFlightStatus(_airlineData.fStatus);
  }


  // get flight status
  function getFlightStatus() public view returns(FlightStatus) {   
    return _airlineData.fStatus;
  }

  
  //function to book ticket, send ticket money to contract and get confirmation id and flight details in response
   function bookTicket(string memory _FromCity, string memory _ToCity, uint256 _ticketQuantity, uint8 _seatCategory) public payable returns(Ticket memory) {
    
    require(_airlineData.fStatus != FlightStatus.CANCELLED, "Flight is Cancelled");
    require(_airlineData.initialSeatNumber - _ticketQuantity>=0, "No seats available"); 
    require(_airlineData.departureDateTime > block.timestamp, "Seats no longer available, flight has departed");  
  

    //dynamically increase confirmation id
    uint256 _confirmationId = confirmationIdLast + 1;
    confirmationIdLast = _confirmationId;

    //create ticket
    // and transfer ticket money to contract    
    require((msg.value/1 ether ==_airlineData.airlineTicketPrice * _ticketQuantity), "Insufficient funds");
    uint256 _ticketPrice = msg.value;
    uint256 _airlineId = _airlineData.airlineId;       
    uint256 _departureTime = _airlineData.departureDateTime;
    uint256 _arrivalTime = _departureTime + 4*60*60; // assuming that flight duration is 4 hours
    TicketStatus _tStatus = TicketStatus.CONFIRMED;
    address payable _ticketHolder = payable(msg.sender);

    //choose seat category
    SeatCategory _sCategory;
    if (_seatCategory == 0){
       _sCategory = SeatCategory.BUSINESS;
    }else if(_seatCategory == 1){
       _sCategory = SeatCategory.ECONOMY;
    }
    
    Ticket memory newTicket;    
    newTicket = Ticket({
                                    ticketConfirmationId: _confirmationId,    
                                    airlineId: _airlineId,
                                    FromCity: _FromCity,
                                    ToCity: _ToCity,
                                    ticketPrice: _ticketPrice,
                                    ticketQuantity: _ticketQuantity, 
                                    departureTime: _departureTime,
                                    arrivalTime: _arrivalTime,
                                    ticketHolder: _ticketHolder,
                                    tStatus:_tStatus,
                                    sCategory:_sCategory                                   
                                    
                            });    

    //push created ticket to ticket storage
    tickets.push(newTicket);

    // set the index of created ticket to the list   
    uint256 _index = tickets.length - 1;
    ticketIdIndex[_confirmationId].exists = true;
    ticketIdIndex[_confirmationId].index =  _index;

    //to decrease available tickets for booking after booking of this ticket
    _airlineData.initialSeatNumber = _airlineData.initialSeatNumber - _ticketQuantity;

    // return confirmation id along with all ticket details     
    return newTicket;    
   
   }

  // emit mesage for ticket cancellation
  event CancelMessage(string cancelMessage);

  // function to cancel the ticket, cancellation penalty will be applied according to time range of the cacellation
  function cancelTicket(uint256 _confirmationId) public  {

    // check if flight is not already cancelled by airlines
    require(_airlineData.fStatus != FlightStatus.CANCELLED, "Flight already cancelled by airlines");

    Ticket storage ticket = tickets[ticketIdIndex[_confirmationId].index];

    require(ticket.ticketHolder == msg.sender, "You are not owner of this ticket");

   //deleted ticket to be added back to ticket pool
    uint256 numberOfSeatToBeAddedInPool = ticket.ticketQuantity;     
    // sending cancelled ticket back to ticket pool
    _airlineData.initialSeatNumber = _airlineData.initialSeatNumber + numberOfSeatToBeAddedInPool;
    ticket.tStatus = TicketStatus.CANCELLED;

    //advance feature to check different slabs for cancellation penalty
    uint256 _ticketPrice = ticket.ticketPrice;
    //check if cancellation requested before two hours of departure time
    if(block.timestamp<_airlineData.departureDateTime -2*60*60 && block.timestamp>_airlineData.departureDateTime -6*60*60){ 
     
      PenaltyTimeRange memory _penaltyTimeRange = _penaltyTimeRanges[0]; // get slab for 2 hours

      //function call to calculate cancellation penalty 
      calculateCancellationPenalty(_penaltyTimeRange.percentageCancellationPenalty, _ticketPrice, ticket.ticketHolder);
       ticket.tStatus = TicketStatus.REFUNDED;
      string memory _cancelMsg = "customer cancelled ticket before 2 hours of departure";
      emit CancelMessage(_cancelMsg);
    }
    
    //check if cancellation requested before 6 hours of departure
    if(block.timestamp<_airlineData.departureDateTime -6*60*60 && block.timestamp>_airlineData.departureDateTime -12*60*60){
      PenaltyTimeRange memory _penaltyTimeRange = _penaltyTimeRanges[1]; // get slab for 6 hours

      //function call to calculate cancellation penalty 
      calculateCancellationPenalty(_penaltyTimeRange.percentageCancellationPenalty, _ticketPrice, ticket.ticketHolder);     
      ticket.tStatus = TicketStatus.REFUNDED;
      string memory _cancelMsg = "customer cancelled ticket before 6 hours of departure";
      emit CancelMessage(_cancelMsg);

    }
    //check if cancellation requested before 12 hours of departure time
    if(block.timestamp<_airlineData.departureDateTime -12*60*60 ){
      PenaltyTimeRange memory _penaltyTimeRange = _penaltyTimeRanges[2]; // get slab for 12 hours

      //function call to calculate cancellation penalty 
      calculateCancellationPenalty(_penaltyTimeRange.percentageCancellationPenalty, _ticketPrice, ticket.ticketHolder);   
      ticket.tStatus = TicketStatus.REFUNDED;
      string memory _cancelMsg = "customer cancelled ticket before 12 hours of departure";
      emit CancelMessage(_cancelMsg);

    }  
     
 }
   //function to calculate cancellation penalty
    function calculateCancellationPenalty(uint256 _percentageCancellationPenalty, uint256 _ticketPrice, address payable _ticketHolder) internal{

      uint256 penaltyAmountToAirline;
      uint256 restAmountRefundToCustomer;
      penaltyAmountToAirline = (_percentageCancellationPenalty * _ticketPrice) / 100;
      restAmountRefundToCustomer = _ticketPrice - penaltyAmountToAirline;
      _airlineData.airlineOwner.transfer(penaltyAmountToAirline);
      _ticketHolder.transfer(restAmountRefundToCustomer);     
    }  

    // In case of Flight cancellation by Airlines
    // all tickets belonging to that airline id will be cancelled
  function cancelAllAirlineTicket(uint256 _airlineId) internal{
   
   //Cancel all tickets of that airlineId   
     for(uint256 _ticket = 0; _ticket <tickets.length; _ticket++){
       if(tickets[_ticket].airlineId==_airlineId){
         if(tickets[_ticket].tStatus != TicketStatus.CANCELLED || tickets[_ticket].tStatus != TicketStatus.REFUNDED){
           tickets[_ticket].tStatus = TicketStatus.CANCELLED;
          }
         
        }
          
      }
   
    }

    // Airline will call this function to get ticket money to it's account     
    function getTicketMoneyToAirline(uint256 _confirmationId) public OnlyAirlineOwner{

        require(block.timestamp>=_airlineData.departureDateTime, "ticket money is locked till departure");
        require(_airlineData.fStatus == FlightStatus.ONTIME, "Flight is delayed or cancelled, ticket holder will trigger claim");

        //get ticket price from the booked ticket       
        Ticket storage ticket = tickets[ticketIdIndex[_confirmationId].index];          
        uint256 _ticketPrice = ticket.ticketPrice;
        _airlineData.airlineOwner.transfer(_ticketPrice);   
                     
          
    } 


    // function to calculate ticket money payment in case of flight cancelled,  delayed or flight status not updated by airline 
    //refund money to customer and(or) Airline   
    // Claim function can be called only after 24 hours of flight departure 
    event RefundStatusMessage(string message);
    function claimRefund(uint256 _confirmationId) public {

      //require((block.timestamp > _airlineData.departureDateTime + 2*60), "Claim can be requested only after 24 hours of departure");
      require((block.timestamp > _airlineData.departureDateTime + 24*60*60), "Claim can be requested only after 24 hours of departure");
         
      //get ticket price from the booked ticket
      Ticket storage ticket = tickets[ticketIdIndex[_confirmationId].index];
      require(ticket.ticketHolder == msg.sender, "you are not owner of this ticket");
      uint256 _ticketPrice = ticket.ticketPrice;      
      
      require(ticket.tStatus != TicketStatus.REFUNDED, "Ticket money is already refunded");     
      if(_airlineData.fStatus == FlightStatus.CANCELLED){          
        ticket.ticketHolder.transfer(_ticketPrice); // full ticket price is refunded to ticket holder
        ticket.tStatus = TicketStatus.REFUNDED;
        emit RefundStatusMessage("flight cancelled by airline, 100% of ticket price would be refunded"); 
      }
      if(_airlineData.fStatus == FlightStatus.DELAYED){
        PenaltyTimeRange memory _penaltyTimeRange;
        //advance feature to check varoius flight delay slabs and pay compensation to customer accordingly
        if(delayedDepartureHours == 2){
          _penaltyTimeRange = _penaltyTimeRanges[0];
        }
        else if((delayedDepartureHours == 6)){
          _penaltyTimeRange = _penaltyTimeRanges[1];
        }
        else if((delayedDepartureHours == 12)){
          _penaltyTimeRange = _penaltyTimeRanges[2];
        }  
        uint256 percentageAmountCompensation = (_penaltyTimeRange.percentageDelayPenalty * _ticketPrice) / 100;
        uint256 restAmountToBePaidToAirline = _ticketPrice - percentageAmountCompensation;
        ticket.ticketHolder.transfer(percentageAmountCompensation);
        _airlineData.airlineOwner.transfer(restAmountToBePaidToAirline);
        ticket.tStatus = TicketStatus.REFUNDED;
         emit RefundStatusMessage("flight is delayed, compensation amount would be refunded to ticket holder");

      }
      // If flight status is not updated by airlines then flightStatusUpdated flag will remain false
      // and airline will have to pay 100% of ticket money to customer as this is considerd as cancellation by airline 
      if(_airlineData.flightStatusUpdated == false){
        ticket.ticketHolder.transfer(_ticketPrice);
        ticket.tStatus = TicketStatus.REFUNDED;
        emit RefundStatusMessage("Airline has not updated status, 100% of ticket price would be refunded"); 
      }                 
      
    } 

    // ***test function*** to check balance of airline and ticketholder account and ticket price for that transaction
    function returnCurrentaddressBalance(uint256 _confirmationId)public  view returns(uint, uint, uint256){
       Ticket storage ticket = tickets[ticketIdIndex[_confirmationId].index];
      
      //get ticket price from the booked ticket
      uint256 _ticketPrice = ticket.ticketPrice;
      address payable _customerAccount = ticket.ticketHolder; 
      return (_airlineData.airlineOwner.balance, _customerAccount.balance, _ticketPrice);
    } 

     
    // function to remove the ticket from Tickets storage
    // after ticket is cancelled
    event LogTicketRemoved(uint256 indexed ticketConfirmationId);
    function removeTicket(uint256 _confirmationId) public  {
      Ticket storage ticket = tickets[ticketIdIndex[_confirmationId].index];
      require((block.timestamp > ticket.arrivalTime), "Flight is not reached to destination");     
    
      ticketIdIndex[_confirmationId].exists = false;
      uint256 numberOfSeatToBeAddedInPool = ticket.ticketQuantity;
      if (tickets.length >= 1) {
        // get index of the array element being removed
        uint256 _index = ticketIdIndex[_confirmationId].index;      
        // move the last element of the array in place of the removed one
        tickets[_index] = tickets[tickets.length-1];
        // update the ID index
        ticketIdIndex[tickets[_index].ticketConfirmationId].index = _index;      
        tickets.pop();       
        // sending cancelled ticket back to ticket pool
        _airlineData.initialSeatNumber = _airlineData.initialSeatNumber + numberOfSeatToBeAddedInPool;
        emit LogTicketRemoved(_confirmationId);  
      }
         
    }
    //modifiers 
    //modifier to check if caller has airline account   
    modifier OnlyAirlineOwner() {        
        require(msg.sender == _airlineData.airlineOwner, "Not airline owner");        
        _;
    }
   
     
}
  