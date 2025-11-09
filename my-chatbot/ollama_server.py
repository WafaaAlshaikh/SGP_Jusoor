from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json

app = Flask(__name__)
CORS(app)  # يسمح لـ Flutter بالاتصال

class OllamaChat:
    def __init__(self):
        self.base_url = "http://localhost:11434"
        self.conversations = {}
    
    def chat(self, message, session_id="default"):
        if session_id not in self.conversations:
            self.conversations[session_id] = []
        
        # إضافة رسالة المستخدم
        self.conversations[session_id].append({"role": "user", "content": message})
        
        data = {
            "model": "llama3.2",
            "messages": self.conversations[session_id],
            "stream": False
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/api/chat",
                json=data,
                timeout=120
            )
            
            if response.status_code == 200:
                result = response.json()
                bot_reply = result["message"]["content"]
                
                # إضافة رد البوت
                self.conversations[session_id].append({"role": "assistant", "content": bot_reply})
                return {
                    "success": True,
                    "response": bot_reply,
                    "session_id": session_id
                }
            else:
                return {
                    "success": False,
                    "error": f"Ollama error: {response.status_code}"
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": f"Connection error: {str(e)}"
            }
    
    def clear_history(self, session_id="default"):
        if session_id in self.conversations:
            self.conversations[session_id] = []
        return {"success": True, "message": "History cleared"}

chat_manager = OllamaChat()

@app.route('/api/chat', methods=['POST'])
def chat_endpoint():
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default')
    
    if not message:
        return jsonify({"success": False, "error": "No message provided"})
    
    result = chat_manager.chat(message, session_id)
    return jsonify(result)

@app.route('/api/clear', methods=['POST'])
def clear_endpoint():
    data = request.json
    session_id = data.get('session_id', 'default')
    result = chat_manager.clear_history(session_id)
    return jsonify(result)

@app.route('/api/health', methods=['GET'])
def health_check():
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        return jsonify({
            "success": True,
            "ollama_status": "running",
            "models": response.json() if response.status_code == 200 else "unknown"
        })
    except:
        return jsonify({
            "success": False,
            "ollama_status": "not_responding"
        })

if __name__ == '__main__':
    print("🚀 Starting Ollama Flask Server...")
    print("📡 Server will run on: http://localhost:5001")
    print("🔗 Make sure Ollama is running on: http://localhost:11434")
    app.run(debug=True, port=5001, host='0.0.0.0')