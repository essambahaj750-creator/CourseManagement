document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('[data-confirm]').forEach((element) => {
        element.addEventListener('click', (event) => {
            const message = element.getAttribute('data-confirm') || 'هل أنت متأكد من تنفيذ العملية؟';
            if (!window.confirm(message)) event.preventDefault();
        });
    });

    if (window.DataTable) {
        document.querySelectorAll('[data-datatable]').forEach((table) => {
            if (table.dataset.enhanced === 'true') return;
            table.dataset.enhanced = 'true';
            new DataTable(table, {
                searchable: true,
                sortable: true,
                perPage: 8,
                perPageSelect: [8, 15, 25, 50],
                labels: {
                    placeholder: 'بحث في السجلات...',
                    perPage: '{select} عنصر لكل صفحة',
                    noRows: 'لا توجد بيانات مطابقة',
                    noResults: 'لا توجد نتائج لهذا البحث',
                    info: 'عرض {start} إلى {end} من {rows} عنصر'
                }
            });
        });
    }

    document.querySelectorAll('form').forEach((form) => {
        form.addEventListener('submit', () => {
            const submit = form.querySelector('button[type="submit"]');
            if (!submit || submit.dataset.allowRepeat === 'true') return;
            submit.disabled = true;
            submit.classList.add('disabled');
            submit.dataset.originalText = submit.innerHTML;
            submit.innerHTML = '<span class="spinner-border spinner-border-sm ms-2" role="status" aria-hidden="true"></span> جارٍ التنفيذ...';
            window.setTimeout(() => {
                submit.disabled = false;
                submit.classList.remove('disabled');
                if (submit.dataset.originalText) submit.innerHTML = submit.dataset.originalText;
            }, 8000);
        });
    });

    document.querySelectorAll('.alert').forEach((alert) => {
        window.setTimeout(() => {
            const instance = window.bootstrap?.Alert.getOrCreateInstance(alert);
            instance?.close();
        }, 6500);
    });

    document.querySelectorAll('.offcanvas .nav-link').forEach((link) => {
        link.addEventListener('click', () => {
            const drawer = document.querySelector('.offcanvas.show');
            if (drawer && window.bootstrap) window.bootstrap.Offcanvas.getOrCreateInstance(drawer).hide();
        });
    });
});
