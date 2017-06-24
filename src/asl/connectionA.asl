
shopHasItem(Item,Qtd,ListOfItens) :- .member(item(Item,_,QtdInShop),ListOfItens) & (Qtd <= QtdInShop).
shopsHasItem(Item,Qtd,[],Temp,Result) :- Result = Temp.
shopsHasItem(Item,Qtd,[shop(IdShop,ItensShop) | ListOfShops],Temp,Result) :- shopHasItem(Item,Qtd,ItensShop) & shopsHasItem(Item,Qtd,ListOfShops,[IdShop | Temp],Result).
shopsHasItem(Item,Qtd,[shop(IdShop,ItensShop) | ListOfShops],Temp,Result) :- shopsHasItem(Item,Qtd,ListOfShops,Temp,Result).
shopsHasItem(Item,Qtd,Result) :- .findall(shop(IdShop,ItensShop),shop(IdShop,_,_,_,ItensShop),ListOfShops) & shopsHasItem(Item,Qtd,ListOfShops,[],Result).

distanceHeuristic(TargetLat, TargetLon, Distance) :- lat(CurrentLat) & lon(CurrentLon) & Distance = 
	math.sqrt(((TargetLat - CurrentLat) * (TargetLat - CurrentLat)) + ((TargetLon - CurrentLon) * (TargetLon - CurrentLon))).

lowBattery :- role(_,_,_,Battery,_) & charge(Charge) & (Charge < (Battery*0.2)).

buyingList([]).
realLastAction(skip).

+lastAction(Action) : lastActionResult(Result) & lastActionParams(Parameters) & 
	(Result = useless) & not (Action = randomFail) & not (Result = successful_partial) & hasItem(Item, Quantity) 
<-
	.print("Item was already delivered. Discarding...");
	+discardItemAtDump(Item, Quantity)
	.

+lastAction(Action) : lastActionResult(Result) & lastActionParams(Parameters) & 
	not (Result = successful) & not (Action = randomFail) & not (Result = successful_partial)
<-
	.print("Error when executing action ", Action);
	.print("Action parameters: ", Parameters);
	.print("Action result: ", Result);
	.

+charge(0) <- +chargingSolarPanels.

@updateBuyingList[atomic]
+buyingList(List)[source(Agent)] : (Agent \== self) 
<-
	.print("Updating buying list");
	-buyingList(List)[source(Agent)];
	-+buyingList(List)[source(self)];
	.

@newJob[atomic]
+job(Name,Storage,Reward,Begin,End,Requirements) : Reward >= 500 & not executingJob(_,_,_,_,_,_) & not charging
<-
	.print("Job ", Name, " analyzed and accepted");	
	-job(Name,Storage,Reward,Begin,End,Requirements);	
	!call_the_other_agents(Name,Storage,Reward,Begin,End,Requirements);
	.	

@callingAgents[atomic]
+!call_the_other_agents(Name,Storage,Reward,Begin,End,Requirements) : not executingJob(_,_,_,_,_,_)
<-
	.print("Calling the other agents to join me in the job ", Name);
	.broadcast(tell,executingJob(Name,Storage,Reward,Begin,End,Requirements));
	+executingJob(Name,Storage,Reward,Begin,End,Requirements);
	-+buyingList(Requirements);
	.

+executingJob(Name,_,_,_,_,Requirements) : not executingJob(_,_,_,_,_,_)
<- 
	.print("I will do the job ", Name); 
     -+buyingList(Requirements);
	.	
	
+jobCompleted(Name)[source(Agent)] : true
<- 
	.print(Agent, " told me job ", Name, " is complete");
	.abolish(executingJob(Name,_,_,_,_,_));
	-going;
	-jobCompleted(Name)[source(Agent)];
	-waitingForJobBeComplete;
	.

+lastAction(deliver_job) : lastActionResult(successful) & executingJob(Name,_,_,_,_,_)
<-
	.print("Job ", Name, " completed!");
	.broadcast(tell,jobCompleted(Name));
	.abolish(executingJob(Name,_,_,_,_,_));
	-going
	.

+lastAction(buy)  : lastActionResult(successful) & buying & lastActionParams([Item,Quantity]) 
<-
	-buying
	.

+charge(C) : role(_,_,_,ChargeCapacity,_) & (C = ChargeCapacity) & charging
<- 
	.print("Full charged");
	-charging.

+charge(C) : role(_,_,_,ChargeCapacity,_) & (C = ChargeCapacity) & chargingSolarPanels
<- 
	.print("Full charged");
	-chargingSolarPanels.

+step(X) : true <- !choose_my_action(X).

+!choose_my_action(Step) : lastAction(noAction) & realLastAction(Action)
<-
	.print("Recovering from fail on action ",Action);	
	Action;
	.

+!choose_my_action(Step) : charging & chargingStation(ChargingStation,_,_,_)
<-
	!what_to_do_in_facility(ChargingStation, Step)
	.

+!choose_my_action(Step) : chargingSolarPanels & charge(Charge)
<-
	.print("Recharing using solar panels ", Charge);
	!perform_action(recharge)
	.

+!choose_my_action(Step) : going(Destination) & facility(Facility) & (Destination == Facility)
<-
	-going(Destination);
	.print("I have arrived at ",Destination);	
	!what_to_do_in_facility(Facility, Step);
	.

+!choose_my_action(Step) : going(Destination)
<-
	!perform_action(continue);
	.

+!choose_my_action(Step) : discardItemAtDump(Item, _) & dump(DumpName,_,_) <- !goto_facility(DumpName).
	
+!choose_my_action(Step) : hasItem(_,_) & executingJob(_,Storage,_,_,_,_)
<-
	.print("Going delivery item at ",Storage);	
	!goto_facility(Storage);
	.
	
+!choose_my_action(Step) : executingJob(_,_,_,_,_,_) & not buyingList([]) & buyingList(Requirements) & not hasItem(_,_)
<-
	.nth(0,Requirements,required(Item, Quantity));
	!choose_shop_to_go_buying(Step, Item, Quantity);
	.
	
+!choose_my_action(Step) :true
<-
	.print("I'm doing nothing at step ",Step);
	!perform_action(skip);
	.

+!goto_facility(Facility) : Facility <- .print("There's no where to go").

+!goto_facility(Facility) : true
<-
	+going(Facility);
	!perform_action(goto(Facility));	
	.

+!choose_shop_to_go_buying(Step, Item, Quantity) : shop(Shop,_,_,_,ShopItems) & .member(item(Item,_,StockQuantity),ShopItems) & (Quantity <= StockQuantity)
<-
	.print("Going to buy ", Item, " on ", Shop);
	!updateBuyingList(Item,Quantity);
	!goto_facility(Shop);
	.

+!choose_item_to_buy(Step) : buyingList(Requirements) & .member(required(Item,Qtd),Requirements) & shopsHasItem(Item,Qtd,ShopList)
<-
	.print("Buying ", Item)
	!perform_action(buy(Item,Qtd));
	+buying
	.
	
+!what_to_do_in_facility(Facility, Step) : chargingStation(Facility,_,_,_) & charge(C) & role(_,_,_,ChargeCapacity,_) & (C < ChargeCapacity)
<-
	.print("Charging: ",C);
	+charging;
	!perform_action(charge)
	.

+!what_to_do_in_facility(Facility, Step) : shop(Facility,_,_,_,ListOfItems) & not buyingList([])
<- 
	!choose_item_to_buy(Step);
	.

+!what_to_do_in_facility(Facility, Step) : shop(Facility,_,_,_,ListOfItems) & buyingList([])
<-
	.print("Buying list is empty. Waiting for another job");
	+waitingForJobBeComplete;
	.
	
+!what_to_do_in_facility(Facility, Step) : storage(Facility,_,_,_,_,_) & executingJob(Name,_,_,_,_,_) & hasItem(Item, Quantity)
<- 
	.print("Delivering ",Quantity, " of ", Item, " on ", Facility);
	!perform_action(deliver_job(Name));
	.

+!what_to_do_in_facility(Facility, Step) : hasItem(Item, Quantity) & buyingList(Requirements) & not .member(required(Item,_), Requirements)
<- 
	.print("Item ", Item, " was already delivered");
	+discardItemAtDump(Item, Quantity)
	.		

+!what_to_do_in_facility(Facility, Step) : discardItemAtDump(Item, Quantity) & dump(Facility,_,_) & hasItem(Item, Quantity)
<-
	.print("Discarding ", Item, " at ", Facility);
	dump(Item, Quantity);
	-discardItemAtDump
	.

+!perform_action(continue) <- continue.

+!perform_action(Action)
<- 
	Action;
	-+realLastAction(Action);
	.

+!updateBuyingList(Item,Qtd) : buyingList(List)
<-
	.print("Removing ", Item, " from buying list");
	.delete(required(Item,Qtd),List,NewList);
	.broadcast(tell,buyingList(NewList));
	-+buyingList(NewList);
	.
	