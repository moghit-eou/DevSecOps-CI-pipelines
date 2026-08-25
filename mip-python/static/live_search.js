const searchBox = document.getElementById('searchBox');
const suggestions = document.getElementById('suggestions');
let searchTimeout;

searchBox.addEventListener('input', function () {
    const query = this.value.trim();

    clearTimeout(searchTimeout);

    if (query.length === 0) {
        suggestions.style.display = 'none';
        return;
    }

    searchTimeout = setTimeout(() => {
        fetch(`/search?q=${encodeURIComponent(query)}`)
            .then(response => response.json())
            .then(data => {
                if (data.error) {
                    console.error('Search error:', data.error);
                    return;
                }

                displaySuggestions(data);
            })
            .catch(error => {
                console.error('Search failed:', error);
                suggestions.style.display = 'none';
            });
    }, 300);
    
});

function displaySuggestions(results) {
    if (results.length === 0) {
        suggestions.style.display = 'none';
        return;
    }

    suggestions.innerHTML = results.map(item => `
        <div style="
            padding: 10px; 
            border-bottom: 1px solid #eee; 
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
        " 
        onmouseover="this.style.backgroundColor='#f5f5f5'" 
        onmouseout="this.style.backgroundColor='white'">
            <div>
                <div style="font-weight: bold; color: #333;">
                    ${item.type === 'folder' ? '📁' : '📄'} ${item.name}
                </div>
                <div style="font-size: 12px; color: #666; margin-top: 2px;">
                    ${item.path}
                </div>
            </div>
            <div style="display: flex; gap: 5px;">
                <a href="${item.webViewLink}" target="_blank" 
                   style="padding: 5px 8px; background: #4285f4; color: white; text-decoration: none; border-radius: 3px; font-size: 12px;">
                   View
                </a>
                ${item.downloadLink ? `
                    <a href="${item.downloadLink}" 
                       style="padding: 5px 8px; background: #34a853; color: white; text-decoration: none; border-radius: 3px; font-size: 12px;">
                       Download
                    </a>
                ` : ''}
                <a href="${item.deleteLink}" 
                   style="padding: 5px 8px; background: #ea4335; color: white; text-decoration: none; border-radius: 3px; font-size: 12px;"
                   onclick="return confirm('Are you sure you want to delete this ${item.type}?')">
                   Delete
                </a>
            </div>
        </div>
    `).join('');

    suggestions.style.display = 'block';
}

document.addEventListener('click', function (e) {
    if (!searchBox.contains(e.target) && !suggestions.contains(e.target)) {
        suggestions.style.display = 'none';
    }
});

searchBox.addEventListener('focus', function () {
    if (this.value.trim().length > 0 && suggestions.innerHTML.trim().length > 0) {
        suggestions.style.display = 'block';
    }
});
