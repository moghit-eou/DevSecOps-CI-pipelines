# Add these routes to your app.py file

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
            orderBy='trashedTime desc'
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
        # Permanently delete the item
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