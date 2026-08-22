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

    const filterToggle = document.querySelector('[data-filter-toggle]');
    const filterPanel = document.querySelector('#courseFilters');
    if (filterToggle && filterPanel) {
        filterToggle.addEventListener('click', () => {
            const isOpen = filterPanel.classList.toggle('is-open');
            filterToggle.setAttribute('aria-expanded', String(isOpen));
            document.body.classList.toggle('filters-open', isOpen);
        });

        filterPanel.querySelectorAll('a, button[type="submit"]').forEach((element) => {
            element.addEventListener('click', () => {
                if (window.innerWidth < 992) {
                    filterPanel.classList.remove('is-open');
                    filterToggle.setAttribute('aria-expanded', 'false');
                    document.body.classList.remove('filters-open');
                }
            });
        });
    }

    document.querySelectorAll('.view-switch').forEach((switcher) => {
        const buttons = [...switcher.querySelectorAll('button')];
        const grid = document.querySelector('.course-grid');
        if (!grid || buttons.length < 2) return;
        buttons.forEach((button, index) => {
            button.addEventListener('click', () => {
                buttons.forEach((item) => item.classList.remove('active'));
                button.classList.add('active');
                grid.classList.toggle('is-list', index === 1);
                button.setAttribute('aria-pressed', 'true');
                buttons.filter((item) => item !== button).forEach((item) => item.setAttribute('aria-pressed', 'false'));
            });
        });
    });

    document.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
            const search = document.querySelector('#courseSearch');
            if (!search) return;
            event.preventDefault();
            search.focus();
            search.select();
        }
    });

    document.querySelectorAll('form').forEach((form) => {
        form.addEventListener('submit', () => {
            const submit = form.querySelector('button[type="submit"]');
            if (!submit || submit.dataset.allowRepeat === 'true' || form.dataset.noSubmitLock === 'true') return;
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
