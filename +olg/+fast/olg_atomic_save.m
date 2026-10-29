function olg_atomic_save(file,data)
% Replace checkpoint only after a complete write. Ctrl+C leaves the old file.
folder=fileparts(file); if ~isfolder(folder), mkdir(folder); end
temporary=[file '.writing.mat']; save(temporary,'-struct','data','-v7');
movefile(temporary,file,'f');
end
