document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('[data-confirm]').forEach((element) => {
        element.addEventListener('click', (event) => {
            const message = element.getAttribute('data-confirm') || 'هل أنت متأكد من تنفيذ العملية؟';
            if (!window.confirm(message)) event.preventDefault();
        });
    });

    if (window.DataTable) {
        document.querySelectorAll('[data-datatable]').forEach((table) => {
            new DataTable(table, {
                searchable: true,
                sortable: true,
                perPage: 8,
                labels: {
                    placeholder: 'بحث...',
                    perPage: '{select} عنصر لكل صفحة',
                    noRows: 'لا توجد بيانات',
                    info: 'عرض {start} إلى {end} من {rows} عنصر'
                }
            });
        });
    }
});
