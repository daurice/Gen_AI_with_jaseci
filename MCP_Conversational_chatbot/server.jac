import from byllm.llm{Model}
import from byllm.types{Image,Video,Text}
import from tools {RagEngine}
import os;
import base64;
import mcp_client;

glob rag_Engine:RagEngine=RagEngine();
glob llm = Model(model_name="gpt-40",verbose=True);
glob MCP_SERVER_URL:str=os.getenv('MCP_SERVER_URL','http://localhost:8899/mcp');

enum ChatType{
    RAG,
    QA,
    IMAGE,
    VIDEO
}

node Router{
    def classify(message:str)-> ChatType by llm(method='reason',temperature=0.9);

}

node Chat{
    has chat_type:ChatType;
}

walker infer{
    has message:str;
    has chat_history:list[dict];
    has response:str ="";
    has file_path:str="";

    can int_router with `root entry{
        visit [-->](`?Router) else{
            router_node = here ++> Router();
            router_node ++> RagChat();
            router_node ++>QAChat();
            router_node ++> ImaageChat();
            router_node ++> VideoChat();
            visit router_node;


        }
    }
    can route with Router entry{
        classification =  here.classify(message =self.message);     
        print("Routing Message:",self.message," to ",classification);
        visit [-->](`?Chat)(?chat_type==classification);
    }

}
node ImageChat(Chat) {
    has chat_type: ChatType = ChatType.IMAGE;

    def respond_with_image(img: Image, text: Text, chat_history: list[dict]) -> str by llm(tools=([use_mcp_tool, list_mcp_tools]));

    can chat with infer entry;
}
node VideoChat(Chat) {
    has chat_type: ChatType = ChatType.VIDEO;

    def respond_with_video(video: Video, text: Text, chat_history: list[dict]) -> str by llm(
        method="Chain-of-Thoughts");
    can chat with infer entry;

}
node RagChat(Chat) {
    has chat_type: ChatType = ChatType.RAG;

    def respond(message:str, chat_history:list[dict]) -> str by llm(
            method="ReAct",
            tools=([list_mcp_tools, use_mcp_tool]),
            messages=chat_history,
            max_react_iterations=6
        );

    can chat with infer entry;
}

node QAChat(chat){
    
}