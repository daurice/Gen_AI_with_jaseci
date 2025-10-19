import streamlit as st;
import requests;
import base64;

def bootstrap_front(token:str){
    st.set_page_config(layout="wide");
    st.title('Welcome to Mshauri');
    st.header('Your AI- powered Business Cosultant');
    
    #intialize session state
    if 'messages' not in st.session_state{
        st.session_state.messages=[];

    }
    if 'session_id' not in st.session_state{
        st.session_state.session_id = "user_session_321";
    }
    uploaded_file=st.file_uploader("Upload your file here");
    if uploaded_file is not None{
        file_b64=base64.b64encode(uploaded_file.read()).decode('utf-8');
        file_extension=uploaded_file.name.lower().split('.')[-1];
        filetype= uploaded_file.type or "";
        supported_filetypes=["pdf","docx","txt","png","jpg","jpeg","webp","mp4","avi","mov"];
        if file_extension not in supported_filetypes and (filetype.startswith("image") or filetype.startswith("video")){
            st.error(f"Unsupported file type: {filetype}. Please upload a file of type: {supported_filetypes}");
            return;
            
        }
        #use upload_file walker endpoint for all uploads saving in uploads/{session_id}
        payload={
            "filename": uploaded_file.name,
            "filedata": file_b64,
            "session_id": st.session_state.session_id
        };
        response=requests.post(
            "http://localhost:8000/walker/upload_file",
             json=payload,
             headers={"Authorization": f"Bearer {token}"}
        );
        if response.status_code==200{
            st.success(f"File uploaded successfully: {uploaded_file.name} to uploads/{st.session_state.session_id}.");
            #Track last uploaded file path in session state
            st.session_state.last_uploaded_file_path=f"uploads/{st.session_state.session_id}/{uploaded_file.name}";

        } else{
            st.error(f"Failed to upload file{uploaded_file.name}.Error: {response.text}");
        }
}
#Display chat messages from session state
for message in st.session_state.messages{
    with st.chat_message(message["role"]){
        st.markdown(message["content"]);
    }

}
if prompt:=st.chat_input("How can I help you?"){
    #add user message to chat history
    st.session_state.messages.append({"role": "user", "content": prompt});

    #display user message in chat message container
    with st.chat_message("user"){
        st.markdown(prompt);
    }
    #display assistant response
    with st.chat_message("assistant"){
        with st.spinner("Deep Thinking..."){
            #call walker API
            payload={
                "message":prompt,
                "session_id":st.session_state.session_id
            };

          #if a file  was uploaded include a path
          if "last_uploaded_path" in st.session_state{
            payload['file_path']=st.session_state.last_uploaded_file_path;
          }
          response=requests.post(
            "http://localhost:8000/walker/chat",
            json=payload,
            headers={"Authorization": f"Bearer {token}"}
          );
            if response.status_code==200{
                response=response.json();
                print("response is:", response);
                st.write(response["reports"][0]["response"]);
                #add assistant response to chat history
                st.session_state.messages.append({"role": "assistant", "content": response["reports"][0]["response"]});
            }

        }
    }
}
}
with entry{
    INSTANCE_URL="http://localhost:8000";
    TEST_USER_EMAIL="test@example.com";
    TEST_USER_PASSWORD="testpassword";

    response=requests.post(
        f"{INSTANCE_URL}/user/login",
        json={"email":TEST_USER_EMAIL, "password":TEST_USER_PASSWORD}
    );
    if response.status_code!=200{
        #try registering the user if login fails
        response=requests.post(
            f" {INSTANCE_URL}/user/register",
            json={"email":TEST_USER_EMAIL, "password":TEST_USER_PASSWORD}
        );
        assert response.status_code==201;
        response=requests.post(
            f"{INSTANCE_URL}/user/login",
            json={"email":TEST_USER_EMAIL, "password":TEST_USER_PASSWORD}
        );
        assert response.status_code==200;

    }
    token=response.json()["access_token"];
    print("Token :", token);
    bootstrap_front(token);
}
