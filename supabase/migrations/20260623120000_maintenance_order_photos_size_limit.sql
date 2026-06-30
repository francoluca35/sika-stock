-- Tope de Storage alineado con compresión en app (~300 KB por foto).

update storage.buckets
set file_size_limit = 307200
where id = 'maintenance-order-photos';
