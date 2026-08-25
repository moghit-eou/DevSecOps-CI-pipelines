document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('uploadForm');
    const fileInput = document.getElementById('uploaded_file');
    const modal = document.getElementById('errorModal');
    const closeBtn = document.getElementById('closeModal');
    const uploadError = document.getElementById('uploadError');

    // Enhanced error display with animations
    function showError(message, useModal = true) {
        if (useModal) {
            showModal(message);
        } else {
            showInlineError(message);
        }
    }

    // Enhanced modal with modern styling
    function showModal(message) {
        const modalMessage = document.getElementById('modalMessage');

        // Create enhanced modal structure if it doesn't exist
        const modalContent = modal.querySelector('.modal-content');
        if (!modalContent.querySelector('.modal-body')) {
            modalContent.innerHTML = `
        <span id="closeModal" class="close">&times;</span>
        <div class="modal-particles">
          <div class="particle"></div>
          <div class="particle"></div>
          <div class="particle"></div>
          <div class="particle"></div>
          <div class="particle"></div>
        </div>
        <div class="modal-body">
          <div class="modal-icon">🚨</div>
          <p id="modalMessage">${message}</p>
        </div>
      `;

            // Re-attach close button event listener
            const newCloseBtn = document.getElementById('closeModal');
            newCloseBtn.addEventListener('click', hideModal);
        } else {
            modalMessage.innerHTML = message;
        }

        modal.classList.add('show');
        modal.style.display = 'flex';

        // Add entrance animation
        const modalContentEl = modal.querySelector('.modal-content');
        modalContentEl.style.animation = 'modalSlideIn 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)';
    }

    // Show inline error message
    function showInlineError(message) {
        uploadError.innerHTML = message;
        uploadError.classList.add('show');

        // Auto-hide after 5 seconds
        setTimeout(() => {
            hideInlineError();
        }, 5000);
    }

    // Hide inline error
    function hideInlineError() {
        uploadError.classList.remove('show');
        setTimeout(() => {
            uploadError.innerHTML = '';
        }, 3000);
    }

    // Hide modal with animation
    function hideModal() {
        const modalContent = modal.querySelector('.modal-content');
        modalContent.style.animation = 'modalSlideOut 0.3s ease-in';

        setTimeout(() => {
            modal.classList.remove('show');
            modal.style.display = 'none';
            modalContent.style.animation = '';
        }, 300);
    }

    // Enhanced file validation
    function validateFile(file) {

        if (!file) {
            return { valid: false, message: '🚨 Please choose a file before uploading.' };
        }


        return { valid: true };
    }

    // Enhanced form submission handling
    form.addEventListener('submit', (e) => {
        const file = fileInput.files[0];
        const validation = validateFile(file);

        if (!validation.valid) {
            e.preventDefault();
            showError(validation.message);

            // Add error styling to file input
            fileInput.style.borderColor = '#ff6b6b';
            fileInput.style.background = '#fff5f5';

            // Remove error styling after 3 seconds
            setTimeout(() => {
                fileInput.style.borderColor = '';
                fileInput.style.background = '';
            }, 3000);

            return false;
        }

        // Show loading state
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Uploading...';
        submitBtn.disabled = true;
        submitBtn.style.background = 'linear-gradient(135deg, #95a5a6, #7f8c8d)';

        // Reset button if form submission fails (in case of client-side issues)
        setTimeout(() => {
            if (submitBtn.disabled) {
                submitBtn.textContent = originalText;
                submitBtn.disabled = false;
                submitBtn.style.background = '';
            }
        }, 30000); // 30 second timeout
    });

    fileInput.addEventListener('change', (e) => {
        const file = e.target.files[0];
        hideInlineError();

        if (file) {
            fileInput.style.borderColor = '';
            fileInput.style.background = '';

            const fileInfo = `Selected: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
            showInlineError(`✅ ${fileInfo}`, false);

            const validation = validateFile(file);
            if (!validation.valid) {
                setTimeout(() => {
                    showInlineError(validation.message, false);
                    fileInput.style.borderColor = '#ff6b6b';
                    fileInput.style.background = '#fff5f5';
                }, 1000);
            }
        }
    });

    closeBtn.addEventListener('click', hideModal);

    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            hideModal();
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('show')) {
            hideModal();
        }
    });

    const uploadContainer = document.querySelector('.upload-container');

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        uploadContainer.addEventListener(eventName, preventDefaults, false);
    });

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    ['dragenter', 'dragover'].forEach(eventName => {
        uploadContainer.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        uploadContainer.addEventListener(eventName, unhighlight, false);
    });

    function highlight() {
        uploadContainer.style.transform = 'scale(1.02)';
        uploadContainer.style.boxShadow = '0 25px 50px rgba(102, 126, 234, 0.3)';
    }

    function unhighlight() {
        uploadContainer.style.transform = '';
        uploadContainer.style.boxShadow = '';
    }

    uploadContainer.addEventListener('drop', handleDrop, false);

    function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;

        if (files.length > 0) {
            fileInput.files = files;
            const event = new Event('change', { bubbles: true });
            fileInput.dispatchEvent(event);
        }
    }

    const style = document.createElement('style');
    style.textContent = `
    @keyframes modalSlideOut {
      from {
        opacity: 1;
        transform: scale(1) translateY(0);
      }
      to {
        opacity: 0;
        transform: scale(0.8) translateY(-50px);
      }
    }
  `;
    document.head.appendChild(style);
});