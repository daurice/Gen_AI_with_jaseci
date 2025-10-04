node user{
    has name:str;#first and last name
    has email:str;#unique identifier
    has phoneno:str;#in international format
    has business_type:str;#retail,services,manufacturing
    has location:str;#city,country
    has language:str;#en,sw
    has entries_count:int=0;#track no of entries
    has is_premium:bool=False;#premium users get more features
    has transactions:list=[];#list of transactions node ids
    has reminders_sent:list=[];#list of reminders
    }
node transactions{
    has trans_type:str;#income,sales,expenses
    has description:str;
    has amount:float;
    has category:str;#food,transport,utilities,salary,rent
    has date:str=datetime.datetime.now().isoformat()[:19];
    


    }
node reminders{
    has message:str;
    has date:str=datetime.datetime.now().isoformat()[:19];
    has sent:bool=False;
    }