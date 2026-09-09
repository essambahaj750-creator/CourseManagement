document.addEventListener('DOMContentLoaded', () => {
    // Bootstrap backdrops are appended to <body>. Keep modals at the same
    // stacking level so transformed/animated page containers cannot trap
    // the dialog underneath the backdrop.
    document.querySelectorAll('.modal').forEach((modal) => {
        if (modal.parentElement !== document.body) {
            document.body.appendChild(modal);
        }
    });

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

    document.querySelectorAll('[data-instructor-picker]').forEach((picker) => {
        const input = picker.querySelector('[data-instructor-search]');
        const hidden = picker.querySelector('[data-instructor-id]');
        const menu = picker.querySelector('[data-instructor-menu]');
        const clear = picker.querySelector('[data-instructor-clear]');
        const empty = picker.querySelector('[data-instructor-empty]');
        const options = [...picker.querySelectorAll('[data-instructor-option]')];
        let activeIndex = -1;

        if (!input || !hidden || !menu) return;

        const normalize = (value) =>
            (value || '')
                .toLocaleLowerCase('ar')
                .replace(/\s+/g, ' ')
                .trim();

        const visibleOptions = () =>
            options.filter((option) => !option.classList.contains('d-none'));

        const updateActive = (nextIndex) => {
            const visible = visibleOptions();
            visible.forEach((option) => option.classList.remove('is-active'));
            if (!visible.length) {
                activeIndex = -1;
                return;
            }

            activeIndex = Math.max(0, Math.min(nextIndex, visible.length - 1));
            const active = visible[activeIndex];
            active.classList.add('is-active');
            active.scrollIntoView({ block: 'nearest' });
        };

        const openMenu = () => {
            menu.classList.add('is-open');
            input.setAttribute('aria-expanded', 'true');
        };

        const closeMenu = () => {
            menu.classList.remove('is-open');
            input.setAttribute('aria-expanded', 'false');
            options.forEach((option) => option.classList.remove('is-active'));
            activeIndex = -1;
        };

        const filterOptions = () => {
            const query = normalize(input.value);
            let shown = 0;

            options.forEach((option) => {
                const search = normalize(option.dataset.search);
                const matches = !query || search.includes(query);
                option.classList.toggle('d-none', !matches);
                if (matches) shown += 1;
            });

            empty?.classList.toggle('d-none', shown > 0);
            activeIndex = -1;
            openMenu();
        };

        const selectOption = (option) => {
            if (!option) return;
            hidden.value = option.dataset.id || '';
            input.value = option.dataset.label || '';
            input.setCustomValidity('');
            options.forEach((item) => {
                const selected = item === option;
                item.classList.toggle('is-selected', selected);
                item.setAttribute('aria-selected', String(selected));
            });
            clear?.classList.toggle('d-none', !hidden.value);
            closeMenu();
        };

        input.addEventListener('focus', filterOptions);

        input.addEventListener('input', () => {
            hidden.value = '';
            input.setCustomValidity('');
            options.forEach((item) => {
                item.classList.remove('is-selected');
                item.setAttribute('aria-selected', 'false');
            });
            clear?.classList.toggle('d-none', !input.value);
            filterOptions();
        });

        input.addEventListener('keydown', (event) => {
            const visible = visibleOptions();

            if (event.key === 'ArrowDown') {
                event.preventDefault();
                openMenu();
                updateActive(activeIndex + 1);
                return;
            }

            if (event.key === 'ArrowUp') {
                event.preventDefault();
                openMenu();
                updateActive(activeIndex <= 0 ? visible.length - 1 : activeIndex - 1);
                return;
            }

            if (event.key === 'Enter' && menu.classList.contains('is-open')) {
                const active = visible[activeIndex] || (visible.length === 1 ? visible[0] : null);
                if (active) {
                    event.preventDefault();
                    selectOption(active);
                }
                return;
            }

            if (event.key === 'Escape') {
                closeMenu();
            }
        });

        options.forEach((option) => {
            option.addEventListener('mousedown', (event) => {
                event.preventDefault();
                selectOption(option);
                input.focus({ preventScroll: true });
            });
        });

        clear?.addEventListener('click', () => {
            hidden.value = '';
            input.value = '';
            input.setCustomValidity('');
            clear.classList.add('d-none');
            options.forEach((item) => {
                item.classList.remove('is-selected');
                item.setAttribute('aria-selected', 'false');
                item.classList.remove('d-none');
            });
            empty?.classList.add('d-none');
            input.focus();
            openMenu();
        });

        input.addEventListener('blur', () => {
            window.setTimeout(() => {
                closeMenu();
                if (input.value.trim() && !hidden.value) {
                    input.setCustomValidity(
                        picker.dataset.requiredMessage || 'اختر قيمة صحيحة من النتائج.'
                    );
                } else {
                    input.setCustomValidity('');
                }
            }, 120);
        });

        picker.closest('form')?.addEventListener('submit', (event) => {
            if (input.value.trim() && !hidden.value) {
                input.setCustomValidity(
                    picker.dataset.requiredMessage || 'اختر قيمة صحيحة من النتائج.'
                );
                input.reportValidity();
                event.preventDefault();
            }
        });
    });

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


    document.querySelectorAll('[data-password-toggle]').forEach((toggle) => {
        const wrapper = toggle.closest('.hf-password');
        const input = wrapper?.querySelector('input');
        const icon = toggle.querySelector('i');
        if (!input) return;

        toggle.addEventListener('click', () => {
            const showing = input.type === 'text';
            input.type = showing ? 'password' : 'text';
            toggle.setAttribute('aria-pressed', String(!showing));
            toggle.setAttribute('aria-label', showing ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور');

            if (icon) {
                icon.classList.toggle('bi-eye', showing);
                icon.classList.toggle('bi-eye-slash', !showing);
            }

            input.focus({ preventScroll: true });
            const end = input.value.length;
            input.setSelectionRange?.(end, end);
        });
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