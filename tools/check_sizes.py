import urllib.request
import json

def check_file(url):
    req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            size_mb = int(resp.headers.get('Content-Length', 0)) / (1024 * 1024)
            print(f"{url} -> {size_mb:.2f} MB")
    except Exception as e:
        print(f"Error {url}: {e}")

if __name__ == '__main__':
    check_file("https://raw.githubusercontent.com/snakers4/silero-vad/master/src/silero_vad/data/silero_vad.onnx")
    check_file("https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/resolve/main/tokens.txt")
    check_file("https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/resolve/main/phoneme_units.json")
    check_file("https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/resolve/main/zipformer_p_arabic_v3.int8.onnx")
    check_file("https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/resolve/main/left_context_probe/zipformer_p_arabic_v3.1_left64.int8.onnx")
