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
                searching: true,
                ordering: true,
                pageLength: 8,
                lengthMenu: [8, 15, 25, 50],
                language: {
                    search: 'بحث:',
                    searchPlaceholder: 'بحث في السجلات...',
                    lengthMenu: 'عرض _MENU_ عنصر لكل صفحة',
                    zeroRecords: 'لا توجد بيانات مطابقة',
                    emptyTable: 'لا توجد بيانات متاحة',
                    info: 'عرض _START_ إلى _END_ من أصل _TOTAL_ عنصر',
                    infoEmpty: 'لا توجد عناصر للعرض',
                    infoFiltered: '(مفلترة من أصل _MAX_ عنصر)',
                    paginate: {
                        first: 'الأول',
                        last: 'الأخير',
                        next: 'التالي',
                        previous: 'السابق'
                    }
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

    const courseContent = document.querySelector('.course-content-section');
    if (courseContent && !courseContent.id) courseContent.id = 'course-content';

    const assetType = document.querySelector('#type');
    if (assetType && assetType.tagName === 'SELECT' && !assetType.querySelector('option[value="4"]')) {
        const previewOption = document.createElement('option');
        previewOption.value = '4';
        previewOption.textContent = 'فيديو معاينة قصير';
        assetType.append(previewOption);
    }

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