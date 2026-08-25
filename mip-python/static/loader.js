const loader = document.getElementById('global-loader');

window.addEventListener('load', () => {
    loader.classList.add('hidden');
    setTimeout(() => loader.style.display = 'none', 100);
});
window.addEventListener('beforeunload', () => {
    loader.style.display = 'flex';
    loader.classList.remove('hidden');
});
window.addEventListener('pageshow', (e) => {
    if (e.persisted) loader.style.display = 'none';
});
