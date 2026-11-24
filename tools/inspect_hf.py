import urllib.request
import json

def list_hf_files(repo_id):
    url = f"https://huggingface.co/api/models/{repo_id}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print(f"=== {repo_id} ===")
            for s in data.get('siblings', []):
                rfile = s.get('rfilename')
                print(f"  - {rfile}")
    except Exception as e:
        print(f"Error {repo_id}: {e}")

if __name__ == '__main__':
    list_hf_files('Quran-Lab/zipformer_p-arabic-v3')
    list_hf_files('Muno459/zipformer_p-arabic-v2')
