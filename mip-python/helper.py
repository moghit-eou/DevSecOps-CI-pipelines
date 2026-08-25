from pathlib import Path
from functools import lru_cache
import json

CONFIG_PATH = Path(__file__).with_name("file_types.json")

@lru_cache(maxsize=1)
def _cfg():
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)
 

def annotate_files(files):
    """Detect file types and assign 'type' field for icon display"""
    for f in files:
        mime = f.get('mimeType', '')
        name = f.get('name', '').lower()

        if mime.startswith('image/'):
            f['type'] = 'image'
        elif mime.startswith('video/'):
            f['type'] = 'video'
        elif mime.startswith('audio/'):
            f['type'] = 'audio'
        elif 'pdf' in mime or name.endswith('.pdf'):
            f['type'] = 'pdf'
        elif 'sheet' in mime or 'excel' in mime or name.endswith(('.xls', '.xlsx')):
            f['type'] = 'excel'
        elif 'word' in mime or 'document' in mime or name.endswith(('.doc', '.docx')):
            f['type'] = 'doc'
        elif 'presentation' in mime or 'powerpoint' in mime or name.endswith(('.ppt', '.pptx')):
            f['type'] = 'ppt'
        elif 'text' in mime or name.endswith('.txt'):
            f['type'] = 'text'
        elif name.endswith(('.zip', '.rar', '.7z', '.tar', '.gz')):
            f['type'] = 'archive'
        else:
            f['type'] = 'other'
    return files


def filter_and_sort(files, wanted_type="all", sort_by="name"):
    wanted = (wanted_type or "all").lower()
    if wanted != "all":
        files = [f for f in files if f.get("type") == wanted]

    key = (sort_by or "name").lower()
    if key == "type":
        files.sort(key=lambda x: (x.get("type","other"), x.get("name","").lower()))
    else:
        files.sort(key=lambda x: x.get("name","").lower())
    return files

def get_folder_path(service, file_id, folder_cache={}):
    """Get the full path of a file/folder by traversing parent folders"""
    if file_id in folder_cache:
        return folder_cache[file_id]
    
    try:
        file_meta = service.files().get(fileId=file_id, fields='name,parents').execute()
        file_name = file_meta.get('name', '')
        parents = file_meta.get('parents', [])
        
        if not parents:
            folder_cache[file_id] = file_name
            return file_name
        
        parent_path = get_folder_path(service, parents[0], folder_cache)
        full_path = f"{parent_path}/{file_name}" if parent_path else file_name
        folder_cache[file_id] = full_path
        return full_path
    except:
        return "Unknown"

def credentials_to_dict(credentials):
    return {
        'token': credentials.token,
        'refresh_token': credentials.refresh_token,
        'token_uri': credentials.token_uri,
        'client_id': credentials.client_id,
        'client_secret': credentials.client_secret,
        'scopes': credentials.scopes
    }


