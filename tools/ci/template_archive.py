"""Read selected members of the official template ZIP over HTTPS byte ranges."""
from concurrent.futures import ThreadPoolExecutor
import io
import urllib.request


class RangeArchive(io.RawIOBase):
    def __init__(self, url):
        response = urllib.request.urlopen(urllib.request.Request(url, headers={"Range": "bytes=0-0"}), timeout=120)
        with response:
            if response.status != 206:
                raise ValueError("Template CDN must support byte ranges")
            self.url = response.geturl()
            self.size = int(response.headers["Content-Range"].split("/")[-1])
        self.position = 0

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.size + offset
        return self.position

    def _range(self, span):
        start, end = span
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}"})
        with urllib.request.urlopen(request, timeout=180) as response:
            if response.status != 206 or response.headers.get("Content-Range") != f"bytes {start}-{end}/{self.size}":
                raise ValueError("Unexpected template range response")
            data = response.read()
        if len(data) != end - start + 1:
            raise ValueError("Truncated template range")
        return data

    def read(self, count=-1):
        count = self.size - self.position if count < 0 else min(count, self.size - self.position)
        if count <= 0:
            return b""
        chunk = 8 * 1024 * 1024
        spans = [(start, min(start + chunk, self.position + count) - 1) for start in range(self.position, self.position + count, chunk)]
        if len(spans) == 1:
            data = self._range(spans[0])
        else:
            with ThreadPoolExecutor(max_workers=8) as workers:
                data = b"".join(workers.map(self._range, spans))
        self.position += count
        return data
