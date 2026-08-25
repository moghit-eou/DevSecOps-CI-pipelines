from flask import Flask, request, redirect, session, url_for, render_template_string , render_template , session , jsonify , flash
import os
import json
import google_auth_oauthlib.flow
import google.oauth2.credentials
import googleapiclient.discovery
from googleapiclient.http import MediaIoBaseDownload
from googleapiclient.http import MediaIoBaseUpload
from io import BytesIO
from flask import send_file
from helper import annotate_files, filter_and_sort , get_folder_path, credentials_to_dict
from dotenv import load_dotenv
from datetime import timedelta 






load_dotenv()

os.environ['OAUTHLIB_INSECURE_TRANSPORT'] = '1'
os.environ['OAUTHLIB_RELAX_TOKEN_SCOPE'] = '1'

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY')

if not app.secret_key:
    raise ValueError("LOL FLASK_SECRET_KEY env var not set FIX IT lol")

app.config.update(
    SESSION_COOKIE_SECURE=True,
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE='Lax',
    PERMANENT_SESSION_LIFETIME=timedelta(hours=24),
)

SCOPES = ['https://www.googleapis.com/auth/drive']

def get_flow():
    creds_json = os.getenv("GOOGLE_CREDENTIALS")

    if not creds_json: #debugging purposes
        raise ValueError("GOOGLE_CREDENTIALS environment variable not set FIX IT lol")
    
    creds_data = json.loads(creds_json)
    
    redirect_uri = url_for('oauth_callback', _external=True)
    
    flow = google_auth_oauthlib.flow.Flow.from_client_config(
        creds_data,
        scopes=SCOPES,
        redirect_uri=redirect_uri  
    )
    
    return flow



def get_service():
    creds = google.oauth2.credentials.Credentials(**session['credentials'])
    if creds.expired and creds.refresh_token:
        try:
            from google.auth.transport.requests import Request
            creds.refresh(Request())
            session['credentials'] = credentials_to_dict(creds)
        except Exception as e:
            print(f"For god sake , the problem is : {e}")
            session.pop('credentials', None)
            return redirect(url_for('index'))

    return googleapiclient.discovery.build('drive', 'v3', credentials=creds)





@app.route('/')
def index():
    if 'credentials' not in session:
        return render_template('login.html')

    return redirect(url_for('home_page'))

@app.route('/authorize')
def authorize():
    flow = get_flow()
    auth_url, state = flow.authorization_url(access_type='offline', include_granted_scopes='true',prompt='consent')
    session['state'] = state
    return redirect(auth_url)



@app.route('/oauth_callback')
def oauth_callback():
    flow = get_flow()
    flow.fetch_token(authorization_response=request.url)
    credentials = flow.credentials
    session['credentials'] = credentials_to_dict(credentials)
    session.permanent = True
    return redirect(url_for('home_page'))




# Replace your home_page route with this efficient version:

@app.route('/home', defaults={'folder_id': None})
@app.route('/home/<folder_id>')
def home_page(folder_id):
    if 'credentials' not in session:
        return redirect(url_for('index'))

    required_fields = ['token', 'refresh_token', 'token_uri', 'client_id', 'client_secret']
    if not all(field in session['credentials'] for field in required_fields):
        session.clear()
        return redirect(url_for('authorize'))

    service = get_service()
    parent = folder_id if folder_id else 'root'
    
    # Pagination settings
    page = request.args.get('page', 1, type=int)
    per_page = 16
    
    # First, get ONLY folders (always show all folders)
    folder_resp = service.files().list(
        q=f"'{parent}' in parents and trashed=false and mimeType='application/vnd.google-apps.folder'",
        fields="files(id,name,mimeType)",
        pageSize=100
    ).execute()
    folders = folder_resp.get('files', [])
    
    # Get filter/sort params
    filter_type = request.args.get('type', 'all')
    sort_by = request.args.get('sort', 'name')
    
    # Build query for files only (no folders)
    file_query = f"'{parent}' in parents and trashed=false and mimeType!='application/vnd.google-apps.folder'"
    
    # Fetch files with pagination - fetch extra to handle potential filtering
    fetch_amount = per_page * 3  # Buffer for filtering
    file_resp = service.files().list(
        q=file_query,
        fields="files(id,name,mimeType,size,webViewLink,parents)",
        pageSize=fetch_amount,
        orderBy='name' if sort_by == 'name' else 'modifiedTime desc'
    ).execute()
    
    files = file_resp.get('files', [])
    files = annotate_files(files)
    files = filter_and_sort(files, wanted_type=filter_type, sort_by=sort_by)
    
    # Pagination logic
    total_files = len(files)
    total_pages = max(1, (total_files + per_page - 1) // per_page)
    page = max(1, min(page, total_pages))
    
    # Get page slice
    start = (page - 1) * per_page
    end = start + per_page
    paginated_files = files[start:end]

    return render_template('home.html',
                          files=paginated_files,
                          folders=folders,
                          current_folder=parent,
                          wanted_type=filter_type,
                          sort_by=sort_by,
                          current_page=page,
                          total_pages=total_pages)


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))
    
@app.route('/search')
def search():
    """Real-time search endpoint"""
    if 'credentials' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    query = request.args.get('q', '').strip()
    if not query:
        return jsonify([])
    
    try:
        service = get_service()
        
        # Search for files and folders that contain the query in their name
        search_query = f"name contains '{query}' and trashed=false"
        
        results = service.files().list(
            q=search_query,
            pageSize=20,
            fields="files(id,name,mimeType,parents,webViewLink)"
        ).execute()
        
        files = results.get('files', [])
        suggestions = []
        
        for file in files:
            # Get the full path for each file/folder
            full_path = get_folder_path(service, file['id'])
            
            # Determine if it's a folder or file
            is_folder = file['mimeType'] == 'application/vnd.google-apps.folder'
            
            suggestions.append({
                'id': file['id'],
                'name': file['name'],
                'path': full_path,
                'type': 'folder' if is_folder else 'file',
                'webViewLink': file.get('webViewLink', ''),
                'downloadLink': url_for('download_file', file_id=file['id']) if not is_folder else None,
                'deleteLink': url_for('delete_file', file_id=file['id'])
            })
        
        # Sort by relevance (exact matches first, then by name)
        suggestions.sort(key=lambda x: (
            not x['name'].lower().startswith(query.lower()),
            x['name'].lower()
        ))
        
        return jsonify(suggestions)
    
    except Exception as e:
        print(f"Search error: {e}")
        return jsonify({'error': 'Search failed'}), 500

@app.route('/upload', methods=['POST'])
def upload():
    if 'credentials' not in session:
        return redirect(url_for('index'))

    service = get_service()
    folder_id = request.args.get('folder_id')
    uploaded_files = request.files.getlist('uploaded_file')

    if not uploaded_files:
        return redirect(url_for('home_page'))

    for uploaded_file in uploaded_files:
        file_metadata = {'name': uploaded_file.filename}
        if folder_id:
            file_metadata['parents'] = [folder_id]

        file_stream = BytesIO(uploaded_file.read())
        file_stream.seek(0)

        media = MediaIoBaseUpload(
            file_stream,
            mimetype=uploaded_file.content_type or 'application/octet-stream',
            resumable=True
        )

        service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()

    return redirect(url_for('home_page', folder_id=folder_id))


@app.route('/delete/<file_id>')
def delete_file(file_id):

    if 'credentials' not in session:
        return redirect(url_for('index'))

    service = get_service()
    service.files().update(
        fileId=file_id,
        body={'trashed': True}
    ).execute()

    folder_id = request.args.get('folder_id')
    if folder_id:
        return redirect(url_for('home_page',folder_id=folder_id))

    return redirect(url_for('home_page'))

@app.route('/download/<file_id>')
def download_file(file_id):
    if 'credentials' not in session:
        return redirect(url_for('index'))
    service = get_service()
    meta = service.files().get(fileId=file_id, fields='name,mimeType').execute()
    mime = meta['mimeType']
    if mime.startswith('application/vnd.google-apps'):
        export_map = {
            'application/vnd.google-apps.document': 'application/pdf',
            'application/vnd.google-apps.spreadsheet': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.google-apps.presentation': 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
        }
        export_mime = export_map.get(mime, 'application/pdf')
        data = service.files().export(fileId=file_id, mimeType=export_mime).execute()
    else:
        data = service.files().get_media(fileId=file_id).execute()
    buf = BytesIO(data)
    return send_file(buf, as_attachment=True ,
      download_name=meta['name'],
      mimetype=export_mime 
      if mime.startswith('application/vnd.google-apps') else mime)


@app.route('/add_folder', methods=['POST'])
def add_folder():
    if 'credentials' not in session:
        return redirect(url_for('home'))

    service   = get_service()
    parent_id = request.args.get('parent_id') or 'root'
    folder_name = request.form.get('folder_name', '').strip()
    if not folder_name:
        return redirect(url_for('home_page', folder_id=parent_id))

    metadata = {
        'name':     folder_name,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents':  [parent_id]
    }

    service.files().create(body=metadata, fields='id').execute()
    return redirect(url_for('home_page', folder_id=parent_id))


@app.route('/delete_folder/<folder_id>')
def delete_folder(folder_id):

    if 'credentials' not in session:
        return redirect(url_for('index'))

    service = get_service()
    # move the folder to trash
    service.files().update(
        fileId=folder_id,
        body={'trashed': True}
    ).execute()

    # read parent_id to know where to redirect
    parent = request.args.get('parent_id')
    return redirect(url_for('home_page', folder_id=parent))


@app.route('/rename_folder/<folder_id>', methods=['POST'])
def rename_folder(folder_id):
    if 'credentials' not in session:
        return redirect(url_for('index'))

    new_name = request.form.get('new_name', '').strip()
    if not new_name:
        flash('Folder name cannot be empty', 'warning')
        return redirect(request.referrer or url_for('home_page'))
    service = get_service()
    service.files().update(fileId=folder_id, body={'name': new_name}).execute()
    flash(f'Folder renamed to "{new_name}"', 'success')
    parent = request.form.get('parent_id')
    if parent: 
        return redirect(url_for('home_page', folder_id=parent))
    return redirect(url_for('home_page'))

#_________________________________________________
@app.route('/bin')
def bin_page():
    """View trashed files and folders"""
    if 'credentials' not in session:
        return redirect(url_for('index'))
    
    service = get_service()
    
    try:
        # Get all trashed items
        results = service.files().list(
            q="trashed=true",
            fields="files(id,name,mimeType,size,trashedTime,parents)",
            pageSize=100,
            orderBy='modifiedTime desc'
        ).execute()

         
        items = results.get('files', [])
        
        # Annotate items to add type information
        items = annotate_files(items)
        
        return render_template('bin.html', items=items)
    
    except Exception as e:
        print(f"Error loading bin: {e}")
        flash('Error loading bin', 'error')
        return redirect(url_for('home_page'))


@app.route('/restore/<file_id>')
def restore_file(file_id):
    """Restore a file/folder from trash"""
    if 'credentials' not in session:
        return redirect(url_for('index'))
    
    service = get_service()
    
    try:
        # Restore the item by setting trashed to False
        service.files().update(
            fileId=file_id,
            body={'trashed': False}
        ).execute()
        
        flash('Item restored successfully', 'success')
    except Exception as e:
        print(f"Error restoring item: {e}")
        flash('Error restoring item', 'error')
    
    return redirect(url_for('bin_page'))


@app.route('/delete_permanently/<file_id>')
def delete_permanently(file_id):
    """Permanently delete a file/folder"""
    if 'credentials' not in session:
        return redirect(url_for('index'))
    
    service = get_service()
    
    try:
        service.files().delete(fileId=file_id).execute()
        flash('Item permanently deleted', 'success')
    except Exception as e:
        print(f"Error deleting item: {e}")
        flash('Error deleting item', 'error')
    
    return redirect(url_for('bin_page'))


@app.route('/empty_bin', methods=['POST'])
def empty_bin():
    """Empty the entire bin (permanently delete all trashed items)"""
    if 'credentials' not in session:
        return redirect(url_for('index'))
    
    service = get_service()
    
    try:
        # Get all trashed items
        results = service.files().list(
            q="trashed=true",
            fields="files(id)",
            pageSize=100
        ).execute()
        
        items = results.get('files', [])
        deleted_count = 0
        
        # Delete each item permanently
        for item in items:
            try:
                service.files().delete(fileId=item['id']).execute()
                deleted_count += 1
            except Exception as e:
                print(f"Error deleting {item['id']}: {e}")
        
        flash(f'Bin emptied: {deleted_count} items permanently deleted', 'success')
    except Exception as e:
        print(f"Error emptying bin: {e}")
        flash('Error emptying bin', 'error')
    
    return redirect(url_for('bin_page'))

# Add this new route to your app.py file

@app.route('/upload_folder', methods=['POST'])
def upload_folder():
    if 'credentials' not in session:
        return redirect(url_for('index'))

    service = get_service()
    folder_id = request.args.get('folder_id')
    uploaded_files = request.files.getlist('files[]')

    if not uploaded_files:
        return redirect(url_for('home_page'))

    # Dictionary to cache created folders {relative_path: folder_id}
    folder_cache = {}
    
    for uploaded_file in uploaded_files:
        # Get the relative path (browser provides this for folder uploads)
        relative_path = uploaded_file.filename
        
        # Extract the directory path from the relative path
        path_parts = relative_path.split('/')
        file_name = path_parts[-1]
        folder_path_parts = path_parts[:-1]
        
        # Navigate/create the folder structure
        current_parent = folder_id if folder_id else 'root'
        
        for i, folder_name in enumerate(folder_path_parts):
            # Build the path up to this point
            partial_path = '/'.join(folder_path_parts[:i+1])
            
            # Check if we've already created this folder
            if partial_path in folder_cache:
                current_parent = folder_cache[partial_path]
            else:
                # Search for existing folder
                query = f"name='{folder_name}' and '{current_parent}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
                results = service.files().list(
                    q=query,
                    spaces='drive',
                    fields='files(id, name)',
                    pageSize=1
                ).execute()
                
                existing_folders = results.get('files', [])
                
                if existing_folders:
                    # Folder exists, use it
                    current_parent = existing_folders[0]['id']
                else:
                    # Create new folder
                    folder_metadata = {
                        'name': folder_name,
                        'mimeType': 'application/vnd.google-apps.folder',
                        'parents': [current_parent]
                    }
                    created_folder = service.files().create(
                        body=folder_metadata,
                        fields='id'
                    ).execute()
                    current_parent = created_folder['id']
                
                # Cache the folder ID
                folder_cache[partial_path] = current_parent
        
        # Upload the file to the final parent folder
        file_metadata = {'name': file_name, 'parents': [current_parent]}
        
        file_stream = BytesIO(uploaded_file.read())
        file_stream.seek(0)
        
        media = MediaIoBaseUpload(
            file_stream,
            mimetype=uploaded_file.content_type or 'application/octet-stream',
            resumable=True
        )
        
        service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()

    return redirect(url_for('home_page', folder_id=folder_id))

@app.route('/test')
def test_page():
    return render_template('test.html')

if __name__ == '__main__':
    app.run(host = "0.0.0.0", port = 5000, debug=True)