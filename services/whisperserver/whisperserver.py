from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import whisper
import uvicorn
import tempfile
import requests

model = whisper.load_model("base.en")  # Load model ONCE!

app = FastAPI()

# 🚀 CORS middleware for browser access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For local dev; restrict in prod
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🌐 n8n Webhook URL (change if needed)
n8n_webhook_url = "https://n8n.deathraymind.net/webhook-test/whisper-result"

@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    with tempfile.NamedTemporaryFile(delete=False, suffix=".webm") as tmp:
        tmp.write(await file.read())
        tmp.flush()
        result = model.transcribe(tmp.name)

    text = result["text"]

    # 🚀 Send transcription to n8n webhook
    try:
        response = requests.post(n8n_webhook_url, json={"text": text})
        response.raise_for_status()
    except Exception as e:
        print(f"[n8n webhook] Failed to send: {e}")

    return {"text": text}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

