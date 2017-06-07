
fullCharged :- 
   chargeCapacity(Capacity) &
   charge(CurrentCharge) &
   CurrentCharge = Capacity.
   
!start.

+!start <- +currentShop(none).
	
+step(0) : charge(Charge) <- +chargeCapacity(Charge).	

//+charge(50) 
//<-
//	.print("need to charge");
//	!gotoChargeStationAndCharge;
//	.

+job(Id, Storage, Reward, Start, End, Items) : not commitedToJob
<-
	+commitedToJob;
	.print("Commited to job ", Id);
	!executeJob(Id, Storage, Items);
	.

@alabel[atomic] 
+lastActionResult(failed_no_route)
<-
	.print("Battery is emtpy. Recharging with solar panels");
	!rechargeUntilFullCharge
	.

//@alabel[atomic] 
+!gotoChargeStationAndCharge : chargingStation(Name,_,_,_) 
<-	
	.print("going to charge at ", Name);
	!go(Name);
	!chargeUntilFullCharge
	.

+!chargeUntilFullCharge : facility(Facility) & chargingStation(Facility,_,_,_) & not(fullCharged)
<-
	charge;
	!chargeUntilFullCharge
	.

+!chargeUntilFullCharge : fullCharged
<-
	.print("Charge complete");
	.	

+!rechargeUntilFullCharge : not(fullCharged) <- recharge;!rechargeUntilFullCharge.
+!rechargeUntilFullCharge : fullCharged <- .print("Charge complete").

+!executeJob(JobId, Storage, ItemsRequired)
<-
	for ( .member(required(Item, ItemQuantity), ItemsRequired)) {
		!getItem(Item, Quantity);
	}
	
	!go(Storage);
	deliver_job(JobId);
	.print("Items for Job ", JobId, " delivered")
	
//	.nth(0,ItemsRequired,required(FirstItem,FirstItemQuantity));
//	!transferItem(Storage, FirstItem, FirstItemQuantity);

//	.delete(0, ItemsRequired, RemainingItems);	
//	.nth(0,RemainingItems,required(FirstItem,FirstItemQuantity));
//	.print("opa2", FirstItem);
	.

+!getItem(Item, Quantity) : shop(Shop,_,_,_,L) & .member(item(Item,_,_),L)
<-
	.print("Getting item ", Item, " at Shop ", Shop);
	!go(Shop);	
	buy(Item, Quantity);
	.print("Item ", Item, " bought")
	buy(Item, Quantity);
	.print("22 Item ", Item, " bought")
	.

+!getItem(Item, Quantity) : item(Item, Volume, Tools, parts(Parts))
<-
	.print("Getting parts for item ", Item);
	for ( .member([PartName, PartQuantity],Parts) ) {
		!getPart(PartName, PartQuantity);
     }
	.

+!getPart(Part, Quantity) : shop(Shop,_,_,_,L) & .member(item(Part,_,_),L)
<-
	.print("Getting ", Quantity, " of ", Part);
	!go(Shop);
	.print("Buying ", Quantity, " of ", Part);
	buy(Item, Quantity)
	.print("Bought ", Quantity, " of ", Item);	
	.

+!transferItem(Storage, Item, Quantity)
<- 
	.print("Transfering ", Quantity, " of item ", Item, " to ", Storage);
	!getItem(Item, Quantity);
	!go(Storage);
	// release item
	.	

+!go(Facility) : not facility(Facility)
<-
	goto(Facility);
	!go(Facility)
.

+!go(Facility) : facility(Facility) <- .print("I am at ", Facility).
	
+step(X) <- skip.	
	