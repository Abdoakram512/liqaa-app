import urllib.request
import urllib.parse
import json

def search_hf(query):
    encoded = urllib.parse.quote(query)
    url = f"https://huggingface.co/api/models?search={encoded}&limit=20"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print(f"=== Search for {query} ===")
            for item in data:
                print(f"  - {item.get('id')} (gated: {item.get('gated')})")
    except Exception as e:
        print(f"Error {query}: {e}")

if __name__ == '__main__':
    search_hf('sherpa-onnx arabic')
    search_hf('k2-fsa arabic')
    search_hf('moonshine arabic')
    search_hf('rnnoise')
