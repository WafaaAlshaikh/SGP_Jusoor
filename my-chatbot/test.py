from flask import Flask, request, jsonify
import requests
import time

app = Flask(__name__)

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return response

print("=" * 60)
print("🚀 ULTIMATE SERVER - Fast & Reliable")
print("=" * 60)

# إعدادات محسنة
FAST_MODEL = "gemma2:2b"  # نموذج سريع
# أو جرب: "qwen2.5:0.5b" - أسرع لكن أقل دقة

@app.route('/api/chat', methods=['POST'])
def chat():
    start_time = time.time()
    data = request.json
    message = data.get('message', '').strip()
    
    print(f"📨 User: {message}")
    
    if not message:
        return jsonify({"success": False, "error": "No message"})
    
    # ⚡ إعدادات محسنة للنموذج
    ollama_data = {
        "model": FAST_MODEL,
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant. Keep responses clear and concise. Respond in the same language as the user."
            },
            {
                "role": "user", 
                "content": message
            }
        ],
        "stream": False,
        "options": {
            "num_predict": 100,  # ردود أقصر = أسرع
            "temperature": 0.7,
            "top_k": 40
        }
    }
    
    try:
        response = requests.post(
            "http://localhost:11434/api/chat",
            json=ollama_data,
            timeout=15  # وقت أقل
        )
        
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            bot_reply = result["message"]["content"]
            print(f"🤖 AI ({response_time:.1f}s): {bot_reply[:80]}...")
            
            return jsonify({
                "success": True,
                "response": bot_reply,
                "response_time": response_time
            })
        else:
            print(f"❌ Ollama error: {response.status_code}")
            return jsonify({
                "success": False,
                "error": f"Ollama error: {response.status_code}"
            })
            
    except requests.exceptions.Timeout:
        return jsonify({
            "success": False,
            "error": "⏰ Request timeout - Ollama is busy. Try a shorter question."
        })
    except Exception as e:
        error_msg = f"Ollama connection failed: {str(e)}"
        print(f"❌ {error_msg}")
        return jsonify({
            "success": False,
            "error": "Ollama stopped responding. Try again in a moment."
        })

@app.route('/api/quick', methods=['POST'])
def quick_chat():
    """أسرع endpoint - بدون إعدادات معقدة"""
    data = request.json
    message = data.get('message', '').strip()
    
    if not message:
        return jsonify({"success": False, "error": "No message"})
    
    try:
        ollama_data = {
            "model": FAST_MODEL,
            "messages": [{"role": "user", "content": message}],
            "stream": False
        }
        
        response = requests.post(
            "http://localhost:11434/api/chat",
            json=ollama_data,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            return jsonify({
                "success": True,
                "response": result["message"]["content"]
            })
        else:
            return jsonify({"success": False, "error": "Ollama busy"})
            
    except:
        return jsonify({"success": False, "error": "Please try again"})

@app.route('/')
def home():
    return '''
    <html>
        <body style="font-family: Arial; padding: 20px;">
            <h1>⚡ Ultimate AI Server</h1>
            <p><strong>Model:</strong> gemma2:2b (Fast & Reliable)</p>
            <p><strong>Endpoints:</strong></p>
            <ul>
                <li><code>POST /api/chat</code> - Normal chat</li>
                <li><code>POST /api/quick</code> - Fast chat</li>
            </ul>
            <div>
                <h3>Test Chat:</h3>
                <input type="text" id="message" placeholder="Type a message..." style="padding: 8px; width: 200px;">
                <button onclick="sendMessage()">Send</button>
                <button onclick="sendQuick()">Quick Send</button>
                <div id="result" style="margin-top: 10px;"></div>
            </div>
            <script>
                async function sendMessage() {
                    const message = document.getElementById('message').value;
                    const response = await fetch('/api/chat', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({message: message})
                    });
                    const data = await response.json();
                    document.getElementById('result').innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
                }
                
                async function sendQuick() {
                    const message = document.getElementById('message').value;
                    const response = await fetch('/api/quick', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({message: message})
                    });
                    const data = await response.json();
                    document.getElementById('result').innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
                }
            </script>
        </body>
    </html>
    '''

if __name__ == '__main__':
    print(f"⚡ Using model: {FAST_MODEL}")
    print("📡 Server: http://localhost:5001")
    print("💡 Tip: Use short questions for faster responses")
    app.run(port=5001, host='0.0.0.0', debug=False)