import requests

invoke_url = "https://integrate.api.nvidia.com/v1/chat/completions"
stream = False # يمكنك تغييرها إلى True إذا أردت ظهور النص كلمة بكلمة

# 1. ضع مفتاح API الخاص بك هنا
api_key = "nvapi-YOUR_API_KEY_HERE"

headers = {
    "Authorization": f"Bearer {api_key}",
    "Accept": "text/event-stream" if stream else "application/json",
}

payload = {
  "messages": [
    {
      "role": "user",
      # 2. اكتب سؤالك هنا
      "content": "اشرح لي باختصار ما هو الـ API وكيف يعمل؟" 
    }
  ],
  "model": "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
  "max_tokens": 1024, # قللت الرقم قليلاً لتسريع الاستجابة في التجربة الأولى
  "stream": stream,
  "temperature": 0.6,
  "top_p": 0.95
}

response = requests.post(invoke_url, headers=headers, json=payload, stream=stream)

if stream:
    for line in response.iter_lines():
        if line:
            print(line.decode("utf-8"))
else:
    # استخراج وطباعة النص المفيد فقط من الرد
    result = response.json()
    if "choices" in result:
        print("\nالرد:")
        print(result["choices"][0]["message"]["content"])
    else:
        print("\nخطأ أو رد غير متوقع:")
        print(result)





 $env:GEMINI_API_KEY="AQ.Ab8RN6LeSUJRhg84kE_d92lp9lUZWmRZJYCvQ8qWmUsPcyNPAA"
uv tool run --python 3.12 --from aider-chat aider --model gemini/gemini-1.5-flash
aider --model gemini/gemini-1.5-pro
AQ.Ab8RN6LeSUJRhg84kE_d92lp9lUZWmRZJYCvQ8qWmUsPcyNPAA