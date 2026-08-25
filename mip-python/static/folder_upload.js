
document.addEventListener('DOMContentLoaded', function () {
    const folderInput = document.getElementById('folder_input');
    const uploadFolderBtn = document.getElementById('uploadFolderBtn');
    const uploadProgress = document.getElementById('uploadProgress');
    const progressFill = document.getElementById('progressFill');
    const progressText = document.getElementById('progressText');
    const errorModal = document.getElementById('errorModal');
    const modalMessage = document.getElementById('modalMessage');
    const closeModal = document.getElementById('closeModal');

    function getCurrentFolderId() {
        const pathParts = window.location.pathname.split('/');
        return pathParts[pathParts.length - 1] !== 'home' ? pathParts[pathParts.length - 1] : 'root';
    }

    uploadFolderBtn.addEventListener('click', async function (e) {
        e.preventDefault();

        const files = folderInput.files;

        if (!files || files.length === 0) {
            showError('Please select a folder to upload');
            return;
        }

        // Show progress
        uploadProgress.style.display = 'block';
        uploadFolderBtn.disabled = true;

        try {
            const formData = new FormData();
            const parentId = getCurrentFolderId();

            formData.append('parent_id', parentId);

            for (let i = 0; i < files.length; i++) {
                const file = files[i];
                const relativePath = file.webkitRelativePath || file.name;

                formData.append('files[]', file);
                formData.append('paths[]', relativePath);

                const progress = Math.round(((i + 1) / files.length) * 50); // First 50% for preparing
                updateProgress(progress, `Preparing files: ${i + 1}/${files.length}`);
            }

            updateProgress(50, 'Uploading to Google Drive...');

            const response = await fetch('/upload_folder', {
                method: 'POST',
                body: formData
            });

            const result = await response.json();

            if (response.ok && result.success) {
                updateProgress(100, 'Upload complete!');

                setTimeout(() => {
                    folderInput.value = '';
                    uploadProgress.style.display = 'none';
                    uploadFolderBtn.disabled = false;
                    window.location.reload();
                }, 1000);
            } else {
                throw new Error(result.error || 'Upload failed');
            }

        } catch (error) {
            console.error('Upload error:', error);
            showError(`Upload failed: ${error.message}`);
            uploadProgress.style.display = 'none';
            uploadFolderBtn.disabled = false;
        }
    });

    function updateProgress(percent, text) {
        progressFill.style.width = percent + '%';
        progressText.textContent = text || `Uploading: ${percent}%`;
    }

    function showError(message) {
        modalMessage.textContent = '🚨 ' + message;
        errorModal.classList.add('show');
    }

    closeModal.addEventListener('click', function () {
        errorModal.classList.remove('show');
    });

    window.addEventListener('click', function (event) {
        if (event.target === errorModal) {
            errorModal.classList.remove('show');
        }
    });

    folderInput.addEventListener('change', function () {
        if (this.files.length > 0) {
            const folderName = this.files[0].webkitRelativePath.split('/')[0];
            uploadFolderBtn.textContent = `📁 Upload "${folderName}" (${this.files.length} files)`;
        } else {
            uploadFolderBtn.textContent = '📁 Upload Folder';
        }
    });
});