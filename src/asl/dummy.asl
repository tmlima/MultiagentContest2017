
shopHasItem(Item,Qtd,ListOfItens) :- .member(item(Item,_,QtdInShop),ListOfItens) & (Qtd <= QtdInShop).

shopsHasItem(Item,Qtd,[],Temp,Result) :- Result = Temp.
shopsHasItem(Item,Qtd,[shop(IdShop,ItensShop) | ListOfShops],Temp,Result) :- shopHasItem(Item,Qtd,ItensShop) & shopsHasItem(Item,Qtd,ListOfShops,[IdShop | Temp],Result).
shopsHasItem(Item,Qtd,[shop(IdShop,ItensShop) | ListOfShops],Temp,Result) :- shopsHasItem(Item,Qtd,ListOfShops,Temp,Result).
shopsHasItem(Item,Qtd,Result) :- .findall(shop(IdShop,ItensShop),shop(IdShop,_,_,_,ItensShop),ListOfShops) & shopsHasItem(Item,Qtd,ListOfShops,[],Result).

hasEnoughBattery :- role(_,_,_,Battery,_) & charge(Charge) & (Charge > (Battery*0.8)).

buyingList([]).
realLastAction(skip).

@updateBuyingList[atomic]
+buyingList(List)[source(Agent)]
	: (Agent \== self)
<-
	.print("Updating buying list");
	-buyingList(List)[source(Agent)];
	-+buyingList(List)[source(self)];
	.

@newJob[atomic]
+job(Name,Storage,Reward,Begin,End,Requirements)
	: true
<-
	!analise_job(Name,Storage,Reward,Begin,End,Requirements);
	.
+!analise_job(Name,Storage,Reward,Begin,End,Requirements)
	: doingJob(_,_,_,_,_,_)
<-
	-job(Name,Storage,Reward,Begin,End,Requirements);
	.
+!analise_job(Name,Storage,Reward,Begin,End,Requirements)
	: true
<-
	.print("I received a job, we'll do it");	
	!call_the_other_agents(Name,Storage,Reward,Begin,End,Requirements);
	-job(Name,Storage,Reward,Begin,End,Requirements);	
	.	

@callingAgents[atomic]
+!call_the_other_agents(Name,Storage,Reward,Begin,End,Requirements)
	: not doingJob(_,_,_,_,_,_)
<-
	.print("Calling the other agents to join me in the job");
	.broadcast(tell,doingJob(Name,Storage,Reward,Begin,End,Requirements));
	+doingJob(Name,Storage,Reward,Begin,End,Requirements);
	-+buyingList(Requirements);
	.
+!call_the_other_agents(Name,Storage,Reward,Begin,End,Requirements)
	: true
<-
	.print("I will help in another job");
	.	
	

+doingJob(_,_,_,_,_,_)
	: true
<- 
	!decide_the_job_to_do;
	.
@receivingJob[atomic]
+!decide_the_job_to_do
	: .findall(Name,doingJob(Name,_,_,_,_,_),Jobs)
<- 
	.sort(Jobs,NewListSorted);
	
	.length(NewListSorted,Length);
	for ( .range(I,1,(Length-1)) ) {
        .nth(I,NewListSorted,Source);
        -doingJob(Name,_,_,_,_,_);
     }
     
     ?doingJob(_,_,_,_,_,Requirements);
     -+buyingList(Requirements);
	.
	
+jobCompleted(Name)[source(Agent)]
	: true
<- 
//	-doingJob(Name,_,_,_,_,_);
	.print("### Job Completed ###");
	.abolish(doingJob(Name,_,_,_,_,_));
	-jobCompleted(Name)[source(Agent)];
	.

+bye
<-
	.print("### Simulation has finished ###");
	.
+step(X) 
	: true 
<-
	!choose_my_action(X);
	.

+lastAction(deliver_job)
	: lastActionResult(successful) & doingJob(Name,_,_,_,_,_)
<-
	.print("### Job Completed ###");
	.broadcast(tell,jobCompleted(Name));
	.abolish(doingJob(Name,_,_,_,_,_));
	.

+!choose_my_action(Step)
	: lastAction(noAction) & realLastAction(Action)
<-
	.print("Recovering from fail at step ",Step);	
	Action;
	.
+!choose_my_action(Step)
	: going(Destination) & facility(Facility) & (Destination == Facility)
<-
	-going(Destination);
	.print("I have arrived at ",Destination);	
	!what_to_do_in_facility(Facility, Step);
	.
+!choose_my_action(Step)
	: going(Destination)
<-
	.print("I continue going to ",Destination," at step ",Step);
	!perform_action(continue);
	.
+!choose_my_action(Step)
	: hasItem(_,_) & doingJob(_,Storage,_,_,_,_)
<-
	.print("Going delivery item at ",Storage," at step ",Step);	
	!goto_facility(Storage);
	.
+!choose_my_action(Step)
	: doingJob(_,_,_,_,_,_) & not buyingList([]) & hasEnoughBattery
<-
	.print("I have a job and I am doing nothing");		
	!choose_shop_to_go_buying(Step);
	.
+!choose_my_action(Step)
	: role(_,_,_,Battery,_) & charge(Charge) & (Charge < Battery) & storage(Facility,_,_,_,_,_)
<-
	.print("Recharging at step ",Step);
	!perform_action(recharge);
	.
+!choose_my_action(Step)
	:true
<-
	.print("I'm doing nothing at step ",Step);
	!perform_action(skip);
	.

+!goto_facility(Facility)
	: Facility
<-
	.print("There's no where to go");	
	.
+!goto_facility(Facility)
	: true
<-
	+going(Facility);
	!perform_action(goto(Facility));	
	.print("Going to ",Facility);	
	.

+!recharge_vehicle(Step)
<- 
	.print("Recharging at ",Step);
	!perform_action(charge);
	.

+!choose_shop_to_go_buying(Step)
	: buyingList(Requirements) & .member(required(Item,Qtd),Requirements) & shopsHasItem(Item,Qtd,ShopList)
<-
	.member(Facility,ShopList);
	!goto_facility(Facility);
	.

+!choose_item_to_buy(Step)
	: buyingList(Requirements) & .member(required(Item,Qtd),Requirements) & shopsHasItem(Item,Qtd,ShopList)
<-
	!perform_action(buy(Item,Qtd));
	!updateBuyingList(Item,Qtd);
	.print("I bought ",Item," at step ",Step);
	.
+!choose_item_to_buy(Step)
	: buyingList(Requirements) & .member(required(Item,Qtd),Requirements) & shopsHasItem(Item,Qtd,ShopList)
<-
	!choose_shop_to_go_buying(Step);
	.

+!what_to_do_in_facility(Facility, Step)
	: shop(Facility,_,_,_,ListOfItens) & not buyingList([])
<- 
	!choose_item_to_buy(Step);
	.
+!what_to_do_in_facility(Facility, Step)
	: storage(Facility,_,_,_,_,_) & doingJob(Name,_,_,_,_,_)
<- 
	.print("Delivering job ",Step);
	!perform_action(deliver_job(Name));
	.
+!what_to_do_in_facility(Facility, Step)
	: true
<- 
	.print("I have nothing to do at step ",Step);
	!perform_action(skip);
	.		

+!perform_action(continue) 
<- continue.
+!perform_action(Action)
<- 
	Action;
	-+realLastAction(Action);
	.

+!updateBuyingList(Item,Qtd)
	: buyingList(List)
<-
	.delete(required(Item,Qtd),List,NewList);
	.broadcast(tell,buyingList(NewList));
	-+buyingList(NewList);
	.